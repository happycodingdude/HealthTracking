import 'package:domain/domain.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../app/strings_vi.dart';
import '../../../ui/components/components.dart';
import '../../../ui/keys.dart';
import '../../../ui/theme.dart';

// Các ô của hồ sơ cơ thể, dùng chung cho S-03 (thiết lập) và S-51 (sửa hồ
// sơ, 04 Bản 4 S-51: "Ô dạng thẻ": Chiều cao "175 cm" · Năm sinh "1996 ›" ·
// Giới tính thanh chọn Nam | Nữ · Mức vận động thẻ 3 dòng chọn · Cân nặng).

/// Đơn vị đứng sau ô nhập (S-03 còn dùng `LabeledField` tới VS-49).
class FieldUnit extends StatelessWidget {
  const FieldUnit(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(right: 16),
    child: Align(
      alignment: Alignment.centerRight,
      widthFactor: 1,
      child: Text(text, style: IronlyText.caption),
    ),
  );
}

/// Khung ô chọn giống ô nhập (S-03 "Mục tiêu").
BoxDecoration fieldBoxDecoration(BuildContext context, {bool error = false}) =>
    BoxDecoration(
      color: context.tokens.surface,
      borderRadius: BorderRadius.circular(TokenRadius.field),
      border: error
          ? Border.all(
              color: context.tokens.danger,
              width: TokenSize.fieldStroke,
            )
          : null,
    );

/// Ô nhập dạng thẻ: nhãn trái chữ phụ, số bên phải trắng, đơn vị chữ phụ;
/// lỗi đỏ dưới ô (câu giữ). `Key` của ô nhập là `field-<name>` (IA4-08).
class ProfileInputRow extends StatelessWidget {
  const ProfileInputRow({
    super.key,
    required this.name,
    required this.label,
    required this.controller,
    this.unit,
    this.error,
    this.keyboardType,
    this.inputFormatters,
    this.onChanged,
    this.textInputAction,
    this.onSubmitted,
    this.decimal = false,
  });

  final String name;
  final String label;
  final TextEditingController controller;
  final String? unit;
  final String? error;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final ValueChanged<String>? onChanged;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;
  final bool decimal;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final radius = BorderRadius.circular(TokenRadius.field);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          constraints: const BoxConstraints(minHeight: 48),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: t.surface,
            borderRadius: radius,
            border: error == null
                ? null
                : Border.all(color: t.danger, width: TokenSize.fieldStroke),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: IronlyText.body.copyWith(color: t.textSecondary),
                ),
              ),
              IntrinsicWidth(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minWidth: 56),
                  child: Semantics(
                    textField: true,
                    label: label,
                    child: TextField(
                      key: K.field(name),
                      controller: controller,
                      keyboardType:
                          keyboardType ??
                          TextInputType.numberWithOptions(decimal: decimal),
                      inputFormatters: inputFormatters,
                      textAlign: TextAlign.end,
                      textInputAction: textInputAction,
                      onChanged: onChanged,
                      onSubmitted: onSubmitted,
                      style: IronlyText.body,
                      decoration: const InputDecoration(
                        isDense: true,
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ),
              ),
              if (unit != null) ...[
                const SizedBox(width: TokenSpace.s1),
                Text(unit!, style: IronlyText.caption),
              ],
            ],
          ),
        ),
        if (error != null)
          Padding(
            padding: const EdgeInsets.only(top: 6, left: 2),
            child: Semantics(
              liveRegion: true,
              child: Text(
                error!,
                key: K.fieldError(name),
                style: IronlyText.error,
              ),
            ),
          ),
      ],
    );
  }
}

/// Nhãn phía trên (chữ phụ) + ô + câu lỗi đỏ phía dưới.
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
        if (label.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(left: 2, bottom: TokenSpace.s2),
            child: Text(label, style: IronlyText.caption),
          ),
        child,
        if (error != null)
          Padding(
            padding: const EdgeInsets.only(top: 6, left: 2),
            child: Semantics(
              liveRegion: true,
              child: Text(error!, style: IronlyText.error),
            ),
          ),
      ],
    );
  }
}

/// Ô "Năm sinh 1996 ›" (giá trị + tuổi chữ phụ).
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
    return IronlyValueRow(
      key: const ValueKey('birth-year-field'),
      label: S.fieldBirthYear,
      value: year?.toString() ?? '',
      unit: age == null ? null : S.ageYears(age!),
      error: hasError ? '' : null,
      onTap: onTap,
    );
  }
}

/// Bánh xe chọn năm sinh trong bảng trượt, chỉ trong khoảng 18–80 tuổi
/// (S-03, 04 §6.13.5); nút "Xong".
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
    return IronlySheet(
      title: S.fieldBirthYear,
      footer: IronlyButton.primary(
        key: const ValueKey('birth-year-done'),
        label: S.done,
        onPressed: () => Navigator.of(context).pop(_year),
      ),
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
                    style: IronlyText.number.copyWith(
                      color: context.tokens.textPrimary,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Thanh chọn Nam | Nữ (chọn = cam).
class SexSelector extends StatelessWidget {
  const SexSelector({super.key, required this.value, required this.onChanged});

  final Sex? value;
  final ValueChanged<Sex> onChanged;

  @override
  Widget build(BuildContext context) => SegmentBar<Sex>(
    items: const [Sex.male, Sex.female],
    selected: value,
    label: (s) => s == Sex.male ? S.sexMale : S.sexFemale,
    keyOf: (s) => ValueKey('sex-${s.name}'),
    style: SegmentStyle.accent,
    onSelected: onChanged,
  );
}

/// Thẻ các mức vận động: tên 14 + mô tả 11; dòng chọn chữ cam + dấu tích cam
/// (04 Bản 4 S-51). Không hiện hệ số (S-03).
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
    final t = context.tokens;
    return IronlyListCard(
      children: [
        for (final level in ActivityLevel.values)
          Semantics(
            button: true,
            selected: value == level,
            inMutuallyExclusiveGroup: true,
            label: '${label(level)}, ${hint(level)}',
            child: ExcludeSemantics(
              child: InkWell(
                key: ValueKey('activity-${level.name}'),
                onTap: () => onChanged(level),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: TokenSize.cardPadding,
                    vertical: TokenSpace.s3,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              label(level),
                              style: IronlyText.body.copyWith(
                                color: value == level ? t.accent : null,
                              ),
                            ),
                            Text(hint(level), style: IronlyText.caption),
                          ],
                        ),
                      ),
                      if (value == level) ...[
                        const SizedBox(width: TokenSpace.s3),
                        Icon(Icons.check, size: 20, color: t.accent),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
