import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../app/strings_vi.dart';
import '../../../app/theme.dart';
import '../../../app/time_ticker.dart';
import '../../../core/formatters.dart';
import '../../../core/widgets/app_sheet.dart';
import '../../../core/widgets/heading.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/session_tag.dart';
import '../../../core/widgets/settings_card.dart';
import '../../../core/widgets/toast.dart';
import '../../../core/widgets/unsaved_changes.dart';
import '../application/schedule_edits.dart';
import '../application/schedule_providers.dart';
import 'extra_session_sheet.dart';
import 'muscle_picker.dart';
import 'session_marking.dart';
import 'weekly_template_editor.dart';

/// Mở S-21 cho ngày [date] (từ S-20, S-25, "Sửa buổi hôm nay" ở Hôm nay).
/// S-24 mở từ đây và thông báo nhanh dùng [context] của màn hình gọi.
Future<void> showDaySheet(BuildContext context, LocalDate date) =>
    showAppSheet<void>(
      context,
      // Đang đổi giờ, nhóm cơ: tự bắt cử chỉ vuốt để hỏi trước (Q-2).
      enableDrag: false,
      builder: (_) => DaySheet(date: date, host: context),
    );

enum _Mode { actions, time, muscles, schedule }

/// S-21 — Chi tiết ngày (04 Bản 2 S-21): đầu bảng "Thứ 4, 21/10" và thông
/// tin hiện tại; phần dưới chỉ có thao tác hợp lệ theo tình huống
/// ([DaySituation]). "Đã tập" · "Không tập" ngay trong bảng (không còn S-23);
/// buổi đã chốt chỉ xem (UR2-06).
class DaySheet extends ConsumerStatefulWidget {
  const DaySheet({super.key, required this.date, required this.host});

  final LocalDate date;

  /// Màn hình mở bảng này; dùng để mở S-24 và hiện thông báo nhanh sau khi
  /// bảng đóng.
  final BuildContext host;

  @override
  ConsumerState<DaySheet> createState() => _DaySheetState();
}

class _DaySheetState extends ConsumerState<DaySheet> {
  _Mode _mode = _Mode.actions;
  LocalTime _time = LocalTime(18, 0);
  List<MuscleGroup> _muscles = const [];
  bool _changed = false;
  bool _showError = false;

  LocalDate get _date => widget.date;
  String get _label => Fmt.weekdayDate(_date);

  void _edit(_Mode mode, PlanDay day) {
    final template = ref.read(weeklyTemplateProvider).value;
    final t = template?.day(_date.weekday);
    setState(() {
      _mode = mode;
      _changed = false;
      _showError = false;
      _time = day.time ?? t?.time ?? LocalTime(18, 0);
      _muscles = mode == _Mode.schedule ? const [] : day.muscles;
    });
  }

  /// Chạy một thao tác sửa riêng; xong thì đóng bảng. false khi lỗi (đã báo
  /// lỗi kỹ thuật; bảng chỉ hiện thao tác hợp lệ nên hiếm gặp).
  Future<bool> _run(Future<void> Function(ScheduleEdits edits) action) async {
    try {
      await action(ref.read(scheduleEditsProvider));
    } on OverrideException catch (e, st) {
      await ref.read(errorReporterProvider).report(e, st, reason: 'override');
      return false;
    }
    if (mounted) Navigator.of(context).pop();
    return true;
  }

  void _toastOverridden() {
    if (!widget.host.mounted) return;
    showToast(
      widget.host,
      S.overriddenToast(Fmt.weekday(_date), Fmt.dayMonth(_date)),
    );
  }

  Future<void> _saveWorkout(PlanDay day) async {
    if (_muscles.isEmpty) {
      setState(() => _showError = true);
      return;
    }
    final ok = await _run(
      (e) => e.overrideDay(_date, time: _time, muscles: _muscles),
    );
    if (ok) _toastOverridden();
  }

  Future<void> _rest() async {
    final ok = await _confirm(
      context,
      title: S.restConfirm(_label),
      action: S.giveRest,
      key: 'confirm-rest',
    );
    if (!ok || !mounted) return;
    if (await _run((e) => e.overrideDay(_date))) _toastOverridden();
  }

  Future<void> _revert() async {
    final ok = await _confirm(
      context,
      title: S.revertConfirmTitle,
      action: S.revert,
      key: 'confirm-revert',
    );
    if (!ok || !mounted) return;
    await _run((e) => e.revertDay(_date));
  }

  void _open(void Function(BuildContext host) next) {
    Navigator.of(context).pop();
    if (widget.host.mounted) next(widget.host);
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(dayProvider(_date));
    final now = ref.watch(nowProvider);
    if (!async.hasValue) return const SizedBox(height: 120);
    final day = async.value;
    final situation = OverrideRules.situation(_date, day, now);
    final today = LocalDate.fromDateTime(now);

    return UnsavedChangesGuard(
      dirty: _mode != _Mode.actions && _changed,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Heading(
              S.dayTitle(_label, today: _date == today),
              style: context.text.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            if (day != null) ...[
              const SizedBox(height: 4),
              _summaryLine(context, day, now),
            ],
            const SizedBox(height: 20),
            ...switch (_mode) {
              _Mode.actions => _actions(context, situation, day, now),
              _Mode.time => _timeEditor(context, day!, now, today),
              _Mode.muscles => _musclesEditor(context, day!),
              _Mode.schedule => _scheduleEditor(context, day!, now, today),
            },
          ],
        ),
      ),
    );
  }

  /// "Lưng · 18:00 · [Chờ đánh dấu]" khi buổi đã đến giờ (mock S-21-1, S-21-3
  /// Bản 2); ngược lại "Lưng · 18:00 · Theo lịch tuần".
  Widget _summaryLine(BuildContext context, PlanDay d, DateTime now) {
    final style = context.text.bodyLarge?.copyWith(
      color: context.palette.textSecondary,
    );
    final status = SessionStatus.derive(d, now);
    if (status == null || status.state == SessionState.upcoming) {
      return Text(
        _summary(d),
        key: const ValueKey('day-summary'),
        style: style,
      );
    }
    final muscles = Fmt.muscles(SessionRules.musclesOf(d));
    return Wrap(
      key: const ValueKey('day-summary'),
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 6,
      runSpacing: 6,
      children: [
        Text('$muscles · ${Fmt.time(d.time!)} ·', style: style),
        SessionTag(status),
      ],
    );
  }

  /// "Lưng · 18:00 · Theo lịch tuần" (mock S-21-1).
  String _summary(PlanDay d) {
    final info = d.isWorkout
        ? '${Fmt.muscles(d.muscles)} · ${Fmt.time(d.time!)}'
        : d.extraMuscles != null
        ? S.restWithExtra(Fmt.muscles(d.extraMuscles!))
        : S.rest;
    final source = d.source == DaySource.override
        ? S.overridden
        : S.fromTemplate;
    return '$info · $source';
  }

  List<Widget> _actions(
    BuildContext context,
    DaySituation situation,
    PlanDay? day,
    DateTime now,
  ) {
    final palette = context.palette;
    final note = Text(
      S.onlyThisDay,
      style: context.text.bodyMedium?.copyWith(color: palette.textSecondary),
    );
    final revert = day?.source == DaySource.override
        ? SettingsRow(
            key: const ValueKey('day-revert'),
            label: S.revertToTemplate,
            onTap: _revert,
          )
        : null;
    final secondary = context.text.bodyLarge?.copyWith(
      color: palette.textSecondary,
    );
    final canAdd = day != null && ExtraSessionRules.canAdd(day, now);
    final logExtra = SettingsCard(
      children: [
        SettingsRow(
          key: const ValueKey('day-log-extra'),
          label: S.logExtraSession,
          onTap: () => _open((h) => showExtraSessionSheet(h, _date)),
        ),
      ],
    );
    void close() => Navigator.of(context).pop();
    return switch (situation) {
      DaySituation.editableWorkout => [
        SettingsCard(
          children: [
            SettingsRow(
              key: const ValueKey('day-change-time'),
              label: S.changeTime,
              value: Fmt.time(day!.time!),
              onTap: () => _edit(_Mode.time, day),
            ),
            SettingsRow(
              key: const ValueKey('day-change-muscles'),
              label: S.changeMuscles,
              value: Fmt.muscles(day.muscles),
              onTap: () => _edit(_Mode.muscles, day),
            ),
            SettingsRow(
              key: const ValueKey('day-rest'),
              label: S.restThisDay,
              onTap: _rest,
            ),
            ?revert,
          ],
        ),
        const SizedBox(height: 16),
        note,
      ],
      DaySituation.futureRest || DaySituation.todayRest => [
        _Option(
          id: 'day-schedule',
          title: situation == DaySituation.todayRest
              ? S.scheduleToday
              : S.scheduleThisDay,
          subtitle: S.countsInPlan,
          onTap: () => _edit(_Mode.schedule, day!),
        ),
        if (situation == DaySituation.todayRest && canAdd) ...[
          const SizedBox(height: 12),
          _Option(
            id: 'day-log-extra',
            title: S.logExtraSession,
            subtitle: S.extraNotCounted,
            onTap: () => _open((h) => showExtraSessionSheet(h, _date)),
          ),
        ],
        if (revert != null) ...[
          const SizedBox(height: 12),
          SettingsCard(children: [revert]),
        ],
        const SizedBox(height: 16),
        note,
      ],
      DaySituation.markable => [
        MarkButtons(
          day: day!,
          onDone: () => SessionMarking.done(context, day, onConfirmed: close),
          onSkipped: () {
            close();
            SessionMarking.skipped(widget.host, day);
          },
        ),
      ],
      DaySituation.done => [
        Text(
          S.doneLine(Fmt.muscles(SessionRules.musclesOf(day!))),
          style: context.text.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        const LockedOnSaveLine(),
      ],
      DaySituation.changeToDone => [
        Text(
          S.changeableUntil(
            Fmt.dayMonth(SessionRules.lastChangeDate(day!.date)),
          ),
          style: secondary,
        ),
        const SizedBox(height: 16),
        ChangeToDoneButton(
          day: day,
          onTap: () => SessionMarking.done(context, day, onConfirmed: close),
        ),
      ],
      DaySituation.pastRest => [if (canAdd) logExtra],
      DaySituation.extraSaved => [
        Text(
          S.extraSessionLine(Fmt.muscles(day!.extraMuscles!)),
          style: context.text.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        const LockedOnSaveLine(),
        // F03-E4: hôm nay đã có buổi tập thêm nên không lên lịch tập được.
        if (_date == LocalDate.fromDateTime(now)) ...[
          const SizedBox(height: 12),
          Text(S.extraBlocksSchedule, style: secondary),
        ],
      ],
      DaySituation.upcoming => const [],
      DaySituation.locked => [
        Row(
          children: [
            ExcludeSemantics(
              child: Icon(Icons.lock, size: 18, color: palette.neutral),
            ),
            const SizedBox(width: 8),
            Expanded(child: Text(S.lockedNote, style: secondary)),
          ],
        ),
      ],
      DaySituation.sunday => [
        Text(S.sundayRest, style: context.text.bodyLarge),
      ],
    };
  }

  /// F03-E2: hôm nay, giờ mới cách hiện tại chưa đầy 1 giờ → không có nhắc.
  Widget? _underHourNote(BuildContext context, DateTime now, LocalDate today) {
    if (_date != today) return null;
    final start = _date.atTime(_time);
    if (!start.isAfter(now) ||
        !start.isBefore(now.add(const Duration(hours: 1)))) {
      return null;
    }
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Text(
        S.noReminderUnderHour,
        key: const ValueKey('under-hour-note'),
        style: context.text.bodyMedium?.copyWith(
          color: context.palette.textSecondary,
        ),
      ),
    );
  }

  Widget _sectionTitle(BuildContext context, String text) => Text(
    text,
    style: context.text.bodyLarge?.copyWith(
      color: context.palette.textSecondary,
    ),
  );

  Widget _wheel() => TimeWheel(
    initial: _time,
    onChanged: (t) => setState(() {
      _time = t;
      _changed = true;
    }),
  );

  Widget _picker() => MusclePicker(
    selected: _muscles,
    onChanged: (m) => setState(() {
      _muscles = m;
      _changed = true;
      if (m.isNotEmpty) _showError = false;
    }),
  );

  Widget? _error(BuildContext context) => !_showError
      ? null
      : Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Semantics(
            liveRegion: true,
            child: Text(
              S.missingTimeOrMuscles,
              style: context.text.bodyMedium?.copyWith(
                color: context.colors.error,
              ),
            ),
          ),
        );

  List<Widget> _timeEditor(
    BuildContext context,
    PlanDay day,
    DateTime now,
    LocalDate today,
  ) => [
    _sectionTitle(context, S.changeTime),
    _wheel(),
    ?_underHourNote(context, now, today),
    const SizedBox(height: 16),
    PrimaryButton(label: S.save, onPressed: () => _saveWorkout(day)),
  ];

  List<Widget> _musclesEditor(BuildContext context, PlanDay day) => [
    _sectionTitle(context, S.changeMuscles),
    const SizedBox(height: 12),
    _picker(),
    ?_error(context),
    const SizedBox(height: 24),
    PrimaryButton(label: S.save, onPressed: () => _saveWorkout(day)),
  ];

  List<Widget> _scheduleEditor(
    BuildContext context,
    PlanDay day,
    DateTime now,
    LocalDate today,
  ) => [
    _sectionTitle(context, S.workoutTime),
    _wheel(),
    ?_underHourNote(context, now, today),
    const SizedBox(height: 16),
    _sectionTitle(context, S.muscleGroups),
    const SizedBox(height: 12),
    _picker(),
    ?_error(context),
    const SizedBox(height: 24),
    PrimaryButton(label: S.save, onPressed: () => _saveWorkout(day)),
  ];
}

/// Lựa chọn lớn có dòng phụ (mock S-21-2).
class _Option extends StatelessWidget {
  const _Option({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final String id;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Card(
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      key: ValueKey(id),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: context.text.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: context.text.bodyLarge?.copyWith(
                color: context.palette.textSecondary,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

/// Hộp xác nhận 2 nút "Hủy" · [action] (NAV-6).
Future<bool> _confirm(
  BuildContext context, {
  required String title,
  required String action,
  required String key,
}) async =>
    await showAppDialog<bool>(
      context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text(S.cancel),
          ),
          FilledButton(
            key: ValueKey(key),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(action),
          ),
        ],
      ),
    ) ??
    false;
