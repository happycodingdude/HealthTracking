import 'package:domain/domain.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../app/strings_vi.dart';
import '../../../app/theme.dart';
import '../../../core/formatters.dart';
import '../../../core/widgets/app_sheet.dart';
import '../../../core/widgets/primary_button.dart';
import 'muscle_picker.dart';

/// Trình sửa lịch tuần (S-22), dùng cho S-05 khi thiết lập lần đầu. Thứ 2 →
/// thứ 7 có công tắc; bật thì dòng mở ra để chọn giờ và nhóm cơ. Chủ nhật luôn
/// nghỉ, không có công tắc (F03-AC1). Lỗi F03-V2, V3 hiện ngay dưới dòng.
class WeeklyTemplateEditor extends StatelessWidget {
  const WeeklyTemplateEditor({
    super.key,
    required this.days,
    required this.expanded,
    required this.errors,
    required this.onChanged,
    required this.onExpand,
    this.rowKeys = const {},
  });

  /// Thứ 2 → thứ 7 (khóa 1 → 6).
  final Map<int, TemplateDay> days;

  /// Thứ đang mở để sửa.
  final int? expanded;
  final List<TemplateError> errors;
  final void Function(int weekday, TemplateDay day) onChanged;
  final ValueChanged<int?> onExpand;

  /// Khóa của từng dòng, để cuộn tới dòng có lỗi.
  final Map<int, GlobalKey> rowKeys;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      decoration: BoxDecoration(
        color: palette.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var w = DateTime.monday; w <= DateTime.saturday; w++) ...[
            _DayRow(
              key: rowKeys[w],
              weekday: w,
              day: days[w] ?? TemplateDay.off,
              expanded: expanded == w,
              errors: [
                for (final e in errors)
                  if (e.weekday == w) e.issue,
              ],
              onChanged: (d) => onChanged(w, d),
              onExpand: onExpand,
            ),
            Divider(
              height: 1,
              indent: 16,
              endIndent: 16,
              color: palette.border,
            ),
          ],
          // Chủ nhật luôn nghỉ (F03-R1).
          Semantics(
            label: '${S.weekdays[6]}, ${S.alwaysRest}',
            child: ExcludeSemantics(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                child: Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  spacing: 12,
                  children: [
                    Text(
                      S.weekdays[6],
                      style: context.text.bodyLarge?.copyWith(
                        color: palette.textSecondary,
                      ),
                    ),
                    Text(
                      S.alwaysRest,
                      style: context.text.bodyMedium?.copyWith(
                        color: palette.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DayRow extends StatelessWidget {
  const _DayRow({
    super.key,
    required this.weekday,
    required this.day,
    required this.expanded,
    required this.errors,
    required this.onChanged,
    required this.onExpand,
  });

  final int weekday;
  final TemplateDay day;
  final bool expanded;
  final List<TemplateIssue> errors;
  final ValueChanged<TemplateDay> onChanged;
  final ValueChanged<int?> onExpand;

  String get _name => S.weekdays[weekday - 1];

  String? get _summary {
    if (!day.enabled) return null;
    final parts = [
      if (day.time != null) Fmt.time(day.time!),
      if (day.muscles.isNotEmpty) Fmt.muscles(day.muscles),
    ];
    return parts.isEmpty ? null : parts.join(' · ');
  }

  Future<void> _pickTime(BuildContext context) async {
    final picked = await pickTime(context, day.time ?? LocalTime(18, 0));
    if (picked != null) {
      onChanged(TemplateDay(enabled: true, time: picked, muscles: day.muscles));
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final summary = _summary;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: InkWell(
                  key: ValueKey('day-row-$weekday'),
                  onTap: day.enabled
                      ? () => onExpand(expanded ? null : weekday)
                      : null,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 44),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          _name,
                          style: context.text.bodyLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (summary != null && !expanded)
                          Text(
                            summary,
                            style: context.text.bodyMedium?.copyWith(
                              color: palette.textSecondary,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              Switch(
                key: ValueKey('day-switch-$weekday'),
                value: day.enabled,
                onChanged: (on) {
                  onChanged(
                    TemplateDay(
                      enabled: on,
                      time: day.time,
                      muscles: day.muscles,
                    ),
                  );
                  onExpand(on ? weekday : null);
                },
              ),
            ],
          ),
          if (day.enabled && expanded) ...[
            const SizedBox(height: 8),
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 12,
              runSpacing: 8,
              children: [
                Text(
                  S.workoutTime,
                  style: context.text.bodyLarge?.copyWith(
                    color: palette.textSecondary,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Semantics(
                    button: true,
                    label: '${S.workoutTime} $_name',
                    value: day.time == null ? null : Fmt.time(day.time!),
                    child: ExcludeSemantics(
                      child: InkWell(
                        key: ValueKey('day-time-$weekday'),
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => _pickTime(context),
                        child: Container(
                          constraints: const BoxConstraints(minHeight: 44),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: palette.neutralContainer,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            day.time == null
                                ? S.timeNotSet
                                : Fmt.time(day.time!),
                            style: context.text.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: MusclePicker(
                selected: day.muscles,
                onChanged: (m) => onChanged(
                  TemplateDay(enabled: true, time: day.time, muscles: m),
                ),
              ),
            ),
          ],
          for (final issue in errors)
            Padding(
              padding: const EdgeInsets.only(top: 8, right: 8),
              child: Semantics(
                liveRegion: true,
                child: Text(
                  switch (issue) {
                    TemplateIssue.missingTime => S.missingTimeFor(_name),
                    TemplateIssue.missingMuscles => S.missingMusclesFor(_name),
                    TemplateIssue.noWorkoutDay => S.noWorkoutDay,
                  },
                  style: context.text.bodyMedium?.copyWith(
                    color: context.colors.error,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Mở bánh xe chọn giờ (UA-18); null khi Bạn đóng bảng.
Future<LocalTime?> pickTime(BuildContext context, LocalTime initial) =>
    showAppSheet<LocalTime>(
      context,
      builder: (_) => _TimePicker(initial: initial),
    );

/// Bánh xe chọn giờ 24 giờ, bước 5 phút (UA-18, 04 §6.13.5).
class _TimePicker extends StatefulWidget {
  const _TimePicker({required this.initial});

  final LocalTime initial;

  @override
  State<_TimePicker> createState() => _TimePickerState();
}

class _TimePickerState extends State<_TimePicker> {
  late LocalTime _time = LocalTime(
    widget.initial.hour,
    widget.initial.minute - widget.initial.minute % 5,
  );

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TimeWheel(initial: _time, onChanged: (t) => _time = t),
          const SizedBox(height: 16),
          PrimaryButton(
            label: S.done,
            onPressed: () => Navigator.of(context).pop(_time),
          ),
        ],
      ),
    );
  }
}

/// Bánh xe giờ 24 giờ, bước 5 phút (UA-18). [initial] làm tròn xuống 5 phút.
class TimeWheel extends StatelessWidget {
  const TimeWheel({super.key, required this.initial, required this.onChanged});

  final LocalTime initial;
  final ValueChanged<LocalTime> onChanged;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 216,
    child: CupertinoDatePicker(
      key: const ValueKey('time-picker'),
      mode: CupertinoDatePickerMode.time,
      use24hFormat: true,
      minuteInterval: 5,
      initialDateTime: DateTime(
        2000,
        1,
        1,
        initial.hour,
        initial.minute - initial.minute % 5,
      ),
      onDateTimeChanged: (d) => onChanged(LocalTime.fromDateTime(d)),
    ),
  );
}
