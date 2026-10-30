import 'package:domain/domain.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../app/strings_vi.dart';
import '../../../core/formatters.dart';
import '../../../ui/components/components.dart';
import '../../../ui/theme.dart';
import 'muscle_picker.dart';

/// Trình sửa lịch tuần (04 Bản 4 S-22), dùng cho S-05 khi thiết lập lần đầu.
/// Thẻ 7 dòng: "Thứ 2" 14 + "Ngực · 18:00" chữ phụ, công tắc phải (cam = có
/// buổi); chủ nhật chữ mờ + ổ khóa (F03-AC1, thay câu "Luôn nghỉ"). Chạm
/// dòng đang bật → khối "Đang sửa Thứ 4": ô "Giờ 18:00 ›", "Nhóm cơ" + 7 viên.
/// Lỗi F03-V2, V3 đỏ ngay dưới dòng, câu giữ nguyên.
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
    final t = context.tokens;
    return IronlyListCard(
      children: [
        for (var w = DateTime.monday; w <= DateTime.saturday; w++)
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
        // Chủ nhật luôn nghỉ (F03-R1): chữ mờ + ổ khóa.
        Semantics(
          label: '${S.weekdays[6]}, ${S.alwaysRest}',
          child: ExcludeSemantics(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: TokenSize.cardPadding,
                vertical: TokenSpace.s3,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      S.weekdays[6],
                      style: IronlyText.body.copyWith(color: t.textPrefill),
                    ),
                  ),
                  const StatusGlyph(
                    GlyphStatus.locked,
                    key: ValueKey('sunday-locked'),
                    label: S.alwaysRest,
                    size: TokenSize.lockSmall,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
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

  /// "Ngực · 18:00" (chữ phụ dưới tên thứ).
  String? get _summary {
    if (!day.enabled) return null;
    final parts = [
      if (day.muscles.isNotEmpty) Fmt.musclesTitle(day.muscles),
      if (day.time != null) Fmt.time(day.time!),
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
    final t = context.tokens;
    final summary = _summary;
    return Column(
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
                  constraints: const BoxConstraints(minHeight: 52),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      TokenSize.cardPadding,
                      TokenSpace.s2,
                      TokenSpace.s2,
                      TokenSpace.s2,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(_name, style: IronlyText.body),
                        if (summary != null && !expanded)
                          Text(summary, style: IronlyText.caption),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(right: TokenSize.cardPadding),
              child: IronlySwitch(
                key: ValueKey('day-switch-$weekday'),
                value: day.enabled,
                label: _name,
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
            ),
          ],
        ),
        if (day.enabled && expanded)
          Padding(
            key: ValueKey('day-editing-$weekday'),
            padding: const EdgeInsets.fromLTRB(
              TokenSize.cardPadding,
              0,
              TokenSize.cardPadding,
              TokenSpace.s3,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(S.editingDay(_name), style: IronlyText.caption),
                const SizedBox(height: TokenSpace.s2),
                IronlyValueRow(
                  key: ValueKey('day-time-$weekday'),
                  label: S.workoutTime,
                  value: day.time == null ? S.timeNotSet : Fmt.time(day.time!),
                  color: t.surfaceRaised,
                  onTap: () => _pickTime(context),
                ),
                const SizedBox(height: TokenSpace.s3),
                Text(S.muscleGroups, style: IronlyText.caption),
                const SizedBox(height: TokenSpace.s2),
                MusclePicker(
                  selected: day.muscles,
                  onChanged: (m) => onChanged(
                    TemplateDay(enabled: true, time: day.time, muscles: m),
                  ),
                ),
              ],
            ),
          ),
        for (final issue in errors)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              TokenSize.cardPadding,
              0,
              TokenSize.cardPadding,
              TokenSpace.s3,
            ),
            child: Semantics(
              liveRegion: true,
              child: Text(switch (issue) {
                TemplateIssue.missingTime => S.missingTimeFor(_name),
                TemplateIssue.missingMuscles => S.missingMusclesFor(_name),
                TemplateIssue.noWorkoutDay => S.noWorkoutDay,
              }, style: IronlyText.error),
            ),
          ),
      ],
    );
  }
}

/// Mở bánh xe chọn giờ (UA-18) trong bảng trượt; null khi Bạn đóng bảng.
Future<LocalTime?> pickTime(BuildContext context, LocalTime initial) =>
    showIronlySheet<LocalTime>(
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
    return IronlySheet(
      title: S.workoutTime,
      footer: IronlyButton.primary(
        key: const ValueKey('time-done'),
        label: S.done,
        onPressed: () => Navigator.of(context).pop(_time),
      ),
      children: [TimeWheel(initial: _time, onChanged: (t) => _time = t)],
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
    child: CupertinoTheme(
      data: CupertinoThemeData(
        brightness: Brightness.dark,
        textTheme: CupertinoTextThemeData(
          dateTimePickerTextStyle: IronlyText.number.copyWith(
            color: context.tokens.textPrimary,
          ),
        ),
      ),
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
    ),
  );
}
