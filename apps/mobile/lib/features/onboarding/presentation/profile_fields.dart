import 'package:domain/domain.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../app/strings_vi.dart';
import '../../../app/theme.dart';
import '../../../core/widgets/primary_button.dart';

// Các ô của hồ sơ cơ thể, dùng chung cho S-03 (thiết lập) và S-51 (sửa hồ
// sơ, 04 S-51: "Các ô giống S-03, trừ cân nặng ban đầu").

/// Đơn vị đứng sau ô nhập (04 §6.13.5).
class FieldUnit extends StatelessWidget {
  const FieldUnit(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(right: 16),
    child: Align(
      alignment: Alignment.centerRight,
      widthFactor: 1,
      child: Text(
        text,
        style: context.text.bodyLarge?.copyWith(
          color: context.palette.textSecondary,
        ),
      ),
    ),
  );
}

/// Nhãn phía trên, câu lỗi đỏ phía dưới (giống [LabeledField]).
class FieldBlock extends StatelessWidget {
  const FieldBlock({
    super.key,
    required this.label,
    required this.child,
    this.error,
  });

  final String label;
  final Widget child;
  final String? error;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          label,
          style: context.text.bodyLarge?.copyWith(
            color: context.palette.textSecondary,
          ),
        ),
        const SizedBox(height: 8),
        child,
        if (error != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Semantics(
              liveRegion: true,
              child: Text(
                error!,
                style: context.text.bodyMedium?.copyWith(
                  color: context.colors.error,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Khung ô chọn (năm sinh, mức vận động) giống ô nhập.
BoxDecoration fieldBoxDecoration(BuildContext context, {bool error = false}) =>
    BoxDecoration(
      color: context.palette.card,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(
        color: error ? context.colors.error : context.palette.border,
        width: error ? 2 : 1,
      ),
    );

class BirthYearField extends StatelessWidget {
  const BirthYearField({
    super.key,
    required this.year,
    required this.age,
    required this.hasError,
    required this.onTap,
  });

  final int? year;
  final int? age;
  final bool hasError;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: S.fieldBirthYear,
      value: year == null ? null : '$year, ${S.ageYears(age!)}',
      child: ExcludeSemantics(
        child: InkWell(
          key: const ValueKey('birth-year-field'),
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Container(
            constraints: const BoxConstraints(minHeight: 56),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: fieldBoxDecoration(context, error: hasError),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    year?.toString() ?? '',
                    style: context.text.bodyLarge?.copyWith(fontSize: 17),
                  ),
                ),
                if (age != null)
                  Text(
                    S.ageYears(age!),
                    style: context.text.bodyMedium?.copyWith(
                      color: context.palette.textSecondary,
                    ),
                  ),
                Icon(Icons.chevron_right, color: context.palette.textSecondary),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Bánh xe chọn năm sinh, chỉ trong khoảng 18–80 tuổi (S-03, 04 §6.13.5).
class BirthYearPicker extends StatefulWidget {
  const BirthYearPicker({
    super.key,
    required this.first,
    required this.last,
    required this.initial,
  });

  final int first;
  final int last;
  final int initial;

  @override
  State<BirthYearPicker> createState() => _BirthYearPickerState();
}

class _BirthYearPickerState extends State<BirthYearPicker> {
  late int _year = widget.initial.clamp(widget.first, widget.last);
  late final _controller = FixedExtentScrollController(
    initialItem: _year - widget.first,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final count = widget.last - widget.first + 1;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 216,
            child: CupertinoPicker(
              key: const ValueKey('birth-year-picker'),
              itemExtent: 40,
              scrollController: _controller,
              onSelectedItemChanged: (i) => _year = widget.first + i,
              children: [
                for (var i = 0; i < count; i++)
                  Center(
                    child: Text(
                      '${widget.first + i}',
                      style: context.text.titleLarge,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          PrimaryButton(
            label: S.done,
            onPressed: () => Navigator.of(context).pop(_year),
          ),
        ],
      ),
    );
  }
}

class SexSelector extends StatelessWidget {
  const SexSelector({super.key, required this.value, required this.onChanged});

  final Sex? value;
  final ValueChanged<Sex> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: context.palette.neutralContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          for (final (sex, label) in [
            (Sex.male, S.sexMale),
            (Sex.female, S.sexFemale),
          ])
            Expanded(
              child: Semantics(
                button: true,
                selected: value == sex,
                inMutuallyExclusiveGroup: true,
                label: label,
                child: ExcludeSemantics(
                  child: InkWell(
                    key: ValueKey('sex-${sex.name}'),
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => onChanged(sex),
                    child: Container(
                      constraints: const BoxConstraints(minHeight: 48),
                      alignment: Alignment.center,
                      decoration: value == sex
                          ? BoxDecoration(
                              color: context.palette.card,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: context.palette.border),
                            )
                          : null,
                      child: Text(
                        label,
                        style: context.text.bodyLarge?.copyWith(
                          fontWeight: value == sex
                              ? FontWeight.w700
                              : FontWeight.w400,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// 5 thẻ mức vận động có mô tả; không hiện hệ số (S-03).
class ActivityCards extends StatelessWidget {
  const ActivityCards({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final ActivityLevel? value;
  final ValueChanged<ActivityLevel> onChanged;

  static String label(ActivityLevel a) => switch (a) {
    ActivityLevel.sedentary => S.activitySedentary,
    ActivityLevel.light => S.activityLight,
    ActivityLevel.moderate => S.activityModerate,
    ActivityLevel.active => S.activityActive,
    ActivityLevel.veryActive => S.activityVeryActive,
  };

  static String hint(ActivityLevel a) => switch (a) {
    ActivityLevel.sedentary => S.activitySedentaryHint,
    ActivityLevel.light => S.activityLightHint,
    ActivityLevel.moderate => S.activityModerateHint,
    ActivityLevel.active => S.activityActiveHint,
    ActivityLevel.veryActive => S.activityVeryActiveHint,
  };

  @override
  Widget build(BuildContext context) {
    const levels = ActivityLevel.values;
    return Container(
      decoration: fieldBoxDecoration(context),
      child: Column(
        children: [
          for (var i = 0; i < levels.length; i++) ...[
            if (i > 0)
              Divider(
                height: 1,
                indent: 16,
                endIndent: 16,
                color: context.palette.border,
              ),
            Semantics(
              button: true,
              selected: value == levels[i],
              inMutuallyExclusiveGroup: true,
              label: '${label(levels[i])}, ${hint(levels[i])}',
              child: ExcludeSemantics(
                child: InkWell(
                  key: ValueKey('activity-${levels[i].name}'),
                  onTap: () => onChanged(levels[i]),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                label(levels[i]),
                                style: context.text.bodyLarge?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Text(
                                hint(levels[i]),
                                style: context.text.bodyMedium?.copyWith(
                                  color: context.palette.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Icon(
                          value == levels[i]
                              ? Icons.radio_button_checked
                              : Icons.radio_button_unchecked,
                          color: value == levels[i]
                              ? context.colors.primary
                              : context.palette.border,
                          size: 26,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
