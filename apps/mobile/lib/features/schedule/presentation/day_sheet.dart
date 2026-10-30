import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../app/strings_vi.dart';
import '../../../app/time_ticker.dart';
import '../../../core/formatters.dart';
import '../../../core/widgets/unsaved_changes.dart';
import '../../../ui/components/components.dart';
import '../../../ui/theme.dart';
import '../../workout/presentation/session_screen.dart';
import '../application/schedule_edits.dart';
import '../application/schedule_providers.dart';
import 'day_line.dart';
import 'extra_session_sheet.dart';
import 'muscle_picker.dart';
import 'session_marking.dart';
import 'weekly_template_editor.dart';

/// Mở S-21 cho ngày [date] (từ S-20, S-25).
Future<void> showDaySheet(BuildContext context, LocalDate date) =>
    showIronlySheet<void>(
      context,
      // Đang đổi giờ, nhóm cơ: tự bắt cử chỉ vuốt để hỏi trước (Q-2).
      enableDrag: false,
      builder: (_) => DaySheet(date: date, host: context),
    );

enum _Mode { actions, time, muscles, schedule }

/// S-21 — Chi tiết ngày (04 Bản 4 S-21): tiêu đề "Thứ 4, 28/10" + dấu trạng
/// thái phải; dòng "Lưng · 18:00" chữ phụ (+ ổ khóa khi quá 7 ngày); các nút
/// xám xếp dọc, chỉ hiện nút hợp lệ: Đổi giờ · Đổi nhóm cơ · Cho nghỉ ngày
/// này · Xem buổi · Đã tập / Không tập · Đổi sang Đã tập; "Trả về theo lịch
/// tuần" chữ cam. Không câu "Chỉ sửa được trong 7 ngày", "Đã chốt khi lưu".
/// Quy tắc F-03, F-05 như Bản 1 → 3 ([DaySituation]).
class DaySheet extends ConsumerStatefulWidget {
  const DaySheet({super.key, required this.date, required this.host});

  final LocalDate date;

  /// Màn hình mở bảng này; dùng để mở S-24 và hiện thông báo nhanh.
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
    final glyph = DayLine.glyphOf(day, now);
    // Ổ khóa khi ngày đã quá 7 ngày (04 Bản 4 S-21) hoặc buổi đã khóa.
    final locked =
        situation == DaySituation.locked ||
        _date.daysUntil(LocalDate.fromDateTime(now)) > 7 ||
        (day != null && (SessionStatus.derive(day, now)?.locked ?? false));

    return UnsavedChangesGuard(
      dirty: _mode != _Mode.actions && _changed,
      child: IronlySheet(
        key: const ValueKey('day-sheet'),
        title: _label,
        titleTrailing: glyph == null
            ? null
            : StatusGlyph(
                glyph.$1,
                key: const ValueKey('day-status'),
                label: glyph.$2,
              ),
        children: [
          if (day != null)
            Padding(
              padding: const EdgeInsets.only(bottom: TokenSpace.s4),
              child: Row(
                key: const ValueKey('day-summary'),
                children: [
                  Expanded(
                    child: Text(_summary(day), style: IronlyText.caption),
                  ),
                  if (locked) ...[
                    const SizedBox(width: TokenSpace.s2),
                    const StatusGlyph(
                      GlyphStatus.locked,
                      label: S.lockedNote,
                      size: TokenSize.lockSmall,
                    ),
                  ],
                ],
              ),
            ),
          ...switch (_mode) {
            _Mode.actions => _actions(context, situation, day, now),
            _Mode.time => _timeEditor(context, day!, now),
            _Mode.muscles => _musclesEditor(context, day!),
            _Mode.schedule => _scheduleEditor(context, day!, now),
          },
        ],
      ),
    );
  }

  /// "Lưng · 18:00" / "Nghỉ · Bụng" / "Nghỉ" (chữ phụ, không câu trạng thái).
  String _summary(PlanDay d) => d.isWorkout
      ? '${Fmt.musclesTitle(SessionRules.musclesOf(d))} · ${Fmt.time(d.time!)}'
      : d.extraMuscles != null
      ? S.restWithExtra(Fmt.musclesTitle(d.extraMuscles!))
      : S.rest;

  Widget _gray(String label, String key, VoidCallback onTap) => Padding(
    padding: const EdgeInsets.only(bottom: TokenSpace.s2),
    child: IronlyButton.gray(
      key: ValueKey(key),
      label: label,
      onPressed: onTap,
    ),
  );

  List<Widget> _actions(
    BuildContext context,
    DaySituation situation,
    PlanDay? day,
    DateTime now,
  ) {
    final canAdd = day != null && ExtraSessionRules.canAdd(day, now);
    void close() => Navigator.of(context).pop();
    final viewSession = LiftLogRules.isSession(day)
        ? _gray(
            S.viewSession,
            'day-view-exercises',
            () => _open((h) => openSession(h, _date)),
          )
        : null;
    final revert = day?.source == DaySource.override
        ? IronlyButton.link(
            key: const ValueKey('day-revert'),
            label: S.revertToTemplate,
            onPressed: _revert,
          )
        : null;
    final logExtra = _gray(
      S.logExtraSession,
      'day-log-extra',
      () => _open((h) => showExtraSessionSheet(h, _date)),
    );
    return switch (situation) {
      DaySituation.editableWorkout => [
        _gray(S.changeTime, 'day-change-time', () => _edit(_Mode.time, day!)),
        _gray(
          S.changeMuscles,
          'day-change-muscles',
          () => _edit(_Mode.muscles, day!),
        ),
        _gray(S.restThisDay, 'day-rest', _rest),
        ?viewSession,
        ?revert,
      ],
      DaySituation.futureRest || DaySituation.todayRest => [
        _gray(
          situation == DaySituation.todayRest
              ? S.scheduleToday
              : S.scheduleThisDay,
          'day-schedule',
          () => _edit(_Mode.schedule, day!),
        ),
        if (situation == DaySituation.todayRest && canAdd) logExtra,
        ?revert,
      ],
      DaySituation.markable => [
        _gray(
          S.sessionDone,
          'mark-done-${day!.date.toKey()}',
          () => SessionMarking.done(context, day, onConfirmed: close),
        ),
        _gray(
          S.sessionSkipped,
          'mark-skipped-${day.date.toKey()}',
          () => SessionMarking.skipped(context, day, onConfirmed: close),
        ),
        ?viewSession,
      ],
      DaySituation.done => [?viewSession],
      DaySituation.changeToDone => [
        _gray(
          S.changeToDone,
          'change-to-done-${day!.date.toKey()}',
          () => SessionMarking.done(context, day, onConfirmed: close),
        ),
        ?viewSession,
      ],
      DaySituation.pastRest => [if (canAdd) logExtra],
      DaySituation.extraSaved => [?viewSession],
      DaySituation.upcoming => [?viewSession],
      // Quá 7 ngày: nút mờ, không câu giải thích (F4-R6).
      DaySituation.locked => [
        if (day != null && day.isWorkout)
          Padding(
            padding: const EdgeInsets.only(bottom: TokenSpace.s2),
            child: IronlyButton.gray(
              key: ValueKey('change-to-done-${day.date.toKey()}-locked'),
              label: S.changeToDone,
              enabled: false,
              onPressed: () {},
            ),
          ),
        ?viewSession,
      ],
      DaySituation.sunday => const [],
    };
  }

  /// F03-E2: hôm nay, giờ mới cách hiện tại chưa đầy 1 giờ → không có nhắc
  /// (câu cảnh báo giữ nguyên, dạng banner).
  Widget? _underHourNote(BuildContext context, DateTime now) {
    final today = LocalDate.fromDateTime(now);
    if (_date != today) return null;
    final start = _date.atTime(_time);
    if (!start.isAfter(now) ||
        !start.isBefore(now.add(const Duration(hours: 1)))) {
      return null;
    }
    return const Padding(
      padding: EdgeInsets.only(top: TokenSpace.s2),
      child: IronlyBanner(
        key: ValueKey('under-hour-note'),
        text: S.noReminderUnderHour,
      ),
    );
  }

  Widget _sectionTitle(String text) => Padding(
    padding: const EdgeInsets.only(bottom: TokenSpace.s2),
    child: Text(text, style: IronlyText.caption),
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

  Widget? _error() => !_showError
      ? null
      : Padding(
          padding: const EdgeInsets.only(top: TokenSpace.s2),
          child: Semantics(
            liveRegion: true,
            child: Text(S.missingTimeOrMuscles, style: IronlyText.error),
          ),
        );

  Widget _save(PlanDay day) => Padding(
    padding: const EdgeInsets.only(top: TokenSpace.s5),
    child: IronlyButton.primary(
      key: const ValueKey('day-save'),
      label: S.save,
      onPressed: () => _saveWorkout(day),
    ),
  );

  List<Widget> _timeEditor(BuildContext context, PlanDay day, DateTime now) => [
    _sectionTitle(S.changeTime),
    _wheel(),
    ?_underHourNote(context, now),
    _save(day),
  ];

  List<Widget> _musclesEditor(BuildContext context, PlanDay day) => [
    _sectionTitle(S.changeMuscles),
    _picker(),
    ?_error(),
    _save(day),
  ];

  List<Widget> _scheduleEditor(
    BuildContext context,
    PlanDay day,
    DateTime now,
  ) => [
    _sectionTitle(S.workoutTime),
    _wheel(),
    ?_underHourNote(context, now),
    const SizedBox(height: TokenSpace.s4),
    _sectionTitle(S.muscleGroups),
    _picker(),
    ?_error(),
    _save(day),
  ];
}

/// Hộp xác nhận 2 nút "Hủy" · [action] (NAV-6), câu giữ nguyên.
Future<bool> _confirm(
  BuildContext context, {
  required String title,
  required String action,
  required String key,
}) async =>
    await showIronlyDialog<bool>(
      context,
      builder: (dialogContext) => IronlyDialog(
        title: title,
        secondaryLabel: S.cancel,
        onSecondary: () => Navigator.of(dialogContext).pop(false),
        primaryLabel: action,
        primaryKey: ValueKey(key),
        onPrimary: () => Navigator.of(dialogContext).pop(true),
      ),
    ) ??
    false;
