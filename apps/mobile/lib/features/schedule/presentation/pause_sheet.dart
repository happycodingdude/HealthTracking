import 'package:domain/domain.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/strings_vi.dart';
import '../../../app/time_ticker.dart';
import '../../../core/formatters.dart';
import '../../../data/sync/sync_providers.dart';
import '../../../ui/components/components.dart';
import '../../../ui/theme.dart';
import '../application/pause_edits.dart';
import '../application/schedule_providers.dart';

/// Mở S-76 — Tạm dừng lịch tập (04 Bản 5 §6.5 S-76, UA5-03).
Future<void> showPauseSheet(BuildContext context) =>
    showIronlySheet<void>(context, builder: (_) => const PauseSheet());

/// Hộp "Kết thúc tạm dừng?" (04 Bản 5 §6.9) → kết thúc sớm (F31-R8) →
/// thông báo nhanh "Đã kết thúc tạm dừng". Trả true khi đã kết thúc.
Future<bool> confirmEndPause(
  BuildContext context,
  WidgetRef ref,
  SchedulePause pause,
) async {
  final ok =
      await showIronlyDialog<bool>(
        context,
        builder: (dialogContext) => IronlyDialog(
          title: S.endPauseTitle,
          body: S.endPauseBody,
          secondaryLabel: S.cancel,
          onSecondary: () => Navigator.of(dialogContext).pop(false),
          primaryLabel: S.endPauseAction,
          primaryKey: const ValueKey('confirm-end-pause'),
          onPrimary: () => Navigator.of(dialogContext).pop(true),
        ),
      ) ??
      false;
  if (!ok) return false;
  await ref.read(pauseEditsProvider).endEarly(pause);
  if (context.mounted) showToast(context, S.pauseEnded);
  return true;
}

/// Nút tạm dừng ở tiêu đề S-20 (04 Bản 5 S-20): vòng 28 thẻ nổi, hai vạch
/// chữ phụ, đứng trước icon lịch; chạm → S-76.
class PauseHeaderButton extends StatelessWidget {
  const PauseHeaderButton({super.key});

  static const _size = 28.0;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: S.pauseSheetTitle,
    child: ExcludeSemantics(
      child: GestureDetector(
        key: const ValueKey('open-pause'),
        behavior: HitTestBehavior.opaque,
        onTap: () => showPauseSheet(context),
        child: SizedBox(
          width: 44,
          height: 44,
          child: Center(
            child: Container(
              width: _size,
              height: _size,
              decoration: BoxDecoration(
                color: context.tokens.surfaceRaised,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: const PauseGlyph(label: null),
            ),
          ),
        ),
      ),
    ),
  );
}

/// Ngày trong ô ngày S-76: "Hôm nay, 03/11" hoặc "T4 04/11" (mock S-76).
String _dateLabel(LocalDate date, LocalDate today) => date == today
    ? S.todayDayMonth(Fmt.dayMonth(date))
    : Fmt.shortWeekdayDate(date);

/// Các buổi theo lịch rơi vào khoảng [from] → [to] (dòng dữ liệu S-76 "Lưng
/// T4 · Vai T6"). Tháng chưa có lịch tháng thì suy ra từ lịch tuần (như
/// "Buổi tới", F03-R6).
final pauseRangeSessionsProvider =
    StreamProvider.family<List<PlanDay>, ({LocalDate from, LocalDate to})>((
      ref,
      range,
    ) {
      final planned = {
        for (final p
            in ref.watch(monthPlansProvider).value ?? const <MonthPlan>[])
          p.month,
      };
      final template = ref.watch(weeklyTemplateProvider).value;
      return ref
          .watch(scheduleRepositoryProvider)
          .watchRange(range.from, range.to)
          .map((days) {
            final byDate = {for (final d in days) d.date: d};
            final out = <PlanDay>[];
            for (
              var date = range.from;
              date <= range.to;
              date = date.addDays(1)
            ) {
              if (date.isSunday) continue;
              final PlanDay? d;
              if (planned.contains(date.yearMonth)) {
                d = byDate[date];
              } else if (template != null) {
                d = PlanDay.fromTemplate(date, template.day(date.weekday));
              } else {
                d = null;
              }
              // Buổi đã "Đã tập" giữ nguyên, không thành Tạm dừng (F31-R7,
              // 03 Bản 5 §6.1 "Buổi tạm dừng") → không vào dòng (mock s76a).
              if (d != null && d.isWorkout && d.mark != DayMark.done) {
                out.add(d);
              }
            }
            return out;
          });
    });

/// S-76 — Tạm dừng lịch tập (bảng trượt, 04 Bản 5 §6.5): chưa có khoảng →
/// "Từ ngày" (mặc định hôm nay) · "Đến ngày" (mặc định = Từ ngày) · dòng các
/// buổi rơi vào khoảng · nút cam "Tạm dừng". Đang có khoảng (kể cả đặt
/// trước) → "Đang tạm dừng", Từ ngày chỉ xem, Đến ngày sửa được, nút "Lưu",
/// chữ đỏ "Kết thúc tạm dừng". Không có cách tạo khoảng thứ hai (F31-R1).
class PauseSheet extends ConsumerStatefulWidget {
  const PauseSheet({super.key, this.initialFrom, this.initialTo});

  /// Ngày chọn sẵn khi chưa có khoảng (test, bộ ảnh); null = hôm nay.
  @visibleForTesting
  final LocalDate? initialFrom;
  @visibleForTesting
  final LocalDate? initialTo;

  @override
  ConsumerState<PauseSheet> createState() => _PauseSheetState();
}

class _PauseSheetState extends ConsumerState<PauseSheet> {
  late LocalDate? _from = widget.initialFrom;
  late LocalDate? _to = widget.initialTo;
  bool _saving = false;

  Future<void> _pick({
    required String title,
    required LocalDate initial,
    required LocalDate minimum,
    required ValueChanged<LocalDate> onPicked,
    required Key key,
  }) async {
    final picked = await showIronlySheet<LocalDate>(
      context,
      builder: (_) => _DatePickerSheet(
        key: key,
        title: title,
        initial: initial.isBefore(minimum) ? minimum : initial,
        minimum: minimum,
      ),
    );
    if (picked != null && mounted) setState(() => onPicked(picked));
  }

  /// Chạy thao tác lưu; xong thì báo thông báo nhanh của nó rồi đóng bảng.
  Future<void> _run(Future<String> Function() action) async {
    if (_saving) return;
    setState(() => _saving = true);
    final String toast;
    try {
      toast = await action();
    } on PauseException {
      if (mounted) setState(() => _saving = false);
      return;
    }
    if (!mounted) return;
    showToast(context, toast);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final today = LocalDate.fromDateTime(ref.watch(nowProvider));
    final active = ref.watch(activePauseProvider);
    final from = active?.startDate ?? _from ?? today;
    final to = _to ?? active?.endDate ?? from;
    final invalid = to.isBefore(from);
    final error = invalid ? S.pauseEndBeforeStart : null;
    final edits = ref.read(pauseEditsProvider);

    final toField = DateField(
      key: const ValueKey('pause-to'),
      fieldKey: const ValueKey('pause-to-field'),
      label: S.pauseTo,
      value: _dateLabel(to, today),
      error: error,
      onTap: () => _pick(
        key: const ValueKey('pause-to-picker'),
        title: S.pauseTo,
        initial: to,
        minimum: today,
        onPicked: (d) => _to = d,
      ),
    );

    if (active != null) {
      return IronlySheet(
        key: const ValueKey('pause-sheet-active'),
        footer: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            IronlyButton.primary(
              key: const ValueKey('pause-save'),
              label: S.save,
              enabled: !invalid,
              loading: _saving,
              onPressed: () => _run(() async {
                final p = await edits.updateEnd(active, to);
                return S.pausedUntil(Fmt.dayMonth(p.endDate));
              }),
            ),
            const SizedBox(height: TokenSpace.s2),
            IronlyButton.danger(
              key: const ValueKey('pause-end'),
              label: S.endPause,
              onPressed: () async {
                if (await confirmEndPause(context, ref, active) &&
                    context.mounted) {
                  Navigator.of(context).pop();
                }
              },
            ),
          ],
        ),
        children: [
          Row(
            children: [
              const PauseGlyph(accent: true, label: null),
              const SizedBox(width: TokenSpace.s3),
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(S.pausingTitle, style: IronlyText.subtitle),
                ),
              ),
            ],
          ),
          const SizedBox(height: TokenSpace.s4),
          DateField(
            key: const ValueKey('pause-from'),
            label: S.pauseFrom,
            value: Fmt.shortWeekdayDate(from),
          ),
          const SizedBox(height: TokenSpace.s2),
          toField,
        ],
      );
    }

    final sessions = invalid
        ? const <PlanDay>[]
        : ref.watch(pauseRangeSessionsProvider((from: from, to: to))).value ??
              const <PlanDay>[];
    return IronlySheet(
      key: const ValueKey('pause-sheet'),
      title: S.pauseSheetTitle,
      footer: IronlyButton.primary(
        key: const ValueKey('pause-submit'),
        label: S.pauseButton,
        enabled: !invalid,
        loading: _saving,
        onPressed: () => _run(() async {
          final p = await edits.start(from, to);
          return S.pausedUntil(Fmt.dayMonth(p.endDate));
        }),
      ),
      children: [
        DateField(
          key: const ValueKey('pause-from'),
          fieldKey: const ValueKey('pause-from-field'),
          label: S.pauseFrom,
          value: _dateLabel(from, today),
          onTap: () => _pick(
            key: const ValueKey('pause-from-picker'),
            title: S.pauseFrom,
            initial: from,
            minimum: today,
            onPicked: (d) => _from = d,
          ),
        ),
        const SizedBox(height: TokenSpace.s2),
        toField,
        if (sessions.isNotEmpty) ...[
          const SizedBox(height: TokenSpace.s4),
          Row(
            key: const ValueKey('pause-sessions'),
            children: [
              const PauseGlyph(label: null),
              const SizedBox(width: TokenSpace.s2),
              Expanded(
                child: Text(
                  [
                    for (final d in sessions)
                      '${Fmt.musclesTitle(d.muscles)} '
                          '${S.weekdaysShort[d.date.weekday - 1]}',
                  ].join(' · '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: IronlyText.caption2.copyWith(color: t.textSecondary),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

/// Bộ chọn ngày của iPhone (tối) trong bảng trượt: không cho chọn trước
/// [minimum] (F31-V1, V3); "Xong" trả ngày đã chọn.
class _DatePickerSheet extends StatefulWidget {
  const _DatePickerSheet({
    super.key,
    required this.title,
    required this.initial,
    required this.minimum,
  });

  final String title;
  final LocalDate initial;
  final LocalDate minimum;

  @override
  State<_DatePickerSheet> createState() => _DatePickerSheetState();
}

class _DatePickerSheetState extends State<_DatePickerSheet> {
  late LocalDate _date = widget.initial;

  @override
  Widget build(BuildContext context) => IronlySheet(
    title: widget.title,
    footer: IronlyButton.primary(
      key: const ValueKey('date-done'),
      label: S.done,
      onPressed: () => Navigator.of(context).pop(_date),
    ),
    children: [
      SizedBox(
        height: 216,
        child: CupertinoTheme(
          data: CupertinoThemeData(
            brightness: Brightness.dark,
            textTheme: CupertinoTextThemeData(
              dateTimePickerTextStyle: IronlyText.subtitle.copyWith(
                color: context.tokens.textPrimary,
              ),
            ),
          ),
          child: CupertinoDatePicker(
            key: const ValueKey('date-picker'),
            mode: CupertinoDatePickerMode.date,
            dateOrder: DatePickerDateOrder.dmy,
            initialDateTime: widget.initial.startOfDay,
            minimumDate: widget.minimum.startOfDay,
            onDateTimeChanged: (d) => _date = LocalDate.fromDateTime(d),
          ),
        ),
      ),
    ],
  );
}
