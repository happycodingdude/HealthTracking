import 'package:flutter/material.dart';

import '../theme.dart';

/// Ô ngày `DateField` (04 Bản 5 §6.1): nền màn trong bảng trượt, bo 10, đệm
/// 11 / 12; nhãn 11 chữ phụ bên trái, giá trị 15 / 600 trắng + "›" bên phải.
/// Chạm → bộ chọn ngày ([onTap]); [onTap] null = chỉ xem (mờ 60 %, không "›").
/// [error] = câu đỏ dưới ô. Cỡ chữ lớn (≥ 1,6×): nhãn trên, giá trị dưới để
/// ngày không bị cắt.
class DateField extends StatelessWidget {
  const DateField({
    super.key,
    required this.label,
    required this.value,
    this.onTap,
    this.error,
    this.fieldKey,
  });

  final String label;
  final String value;
  final VoidCallback? onTap;
  final String? error;
  final Key? fieldKey;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final enabled = onTap != null;
    final stacked = MediaQuery.textScalerOf(context).scale(1) >= 1.6;
    final labelText = Text(
      label,
      style: IronlyText.caption.copyWith(color: t.textSecondary),
    );
    final valueText = Text(
      value,
      textAlign: stacked ? TextAlign.left : TextAlign.right,
      maxLines: stacked ? 2 : 1,
      overflow: TextOverflow.ellipsis,
      style: IronlyText.subtitle.copyWith(
        fontWeight: FontWeight.w600,
        color: t.textPrimary,
      ),
    );
    final chevron = enabled
        ? Padding(
            padding: const EdgeInsets.only(left: TokenSpace.s1),
            child: Icon(Icons.chevron_right, size: 18, color: t.textPrimary),
          )
        : null;
    final field = Semantics(
      button: enabled,
      label: '$label: $value',
      child: ExcludeSemantics(
        child: Material(
          color: t.bg,
          borderRadius: BorderRadius.circular(TokenRadius.field),
          child: InkWell(
            key: fieldKey,
            borderRadius: BorderRadius.circular(TokenRadius.field),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
              child: Opacity(
                opacity: enabled ? 1 : 0.6,
                child: stacked
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          labelText,
                          const SizedBox(height: TokenSpace.s1),
                          Row(
                            children: [
                              Expanded(child: valueText),
                              ?chevron,
                            ],
                          ),
                        ],
                      )
                    : Row(
                        children: [
                          labelText,
                          const SizedBox(width: TokenSpace.s3),
                          Expanded(child: valueText),
                          ?chevron,
                        ],
                      ),
              ),
            ),
          ),
        ),
      ),
    );
    if (error == null) return field;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        field,
        const SizedBox(height: TokenSpace.s1),
        Semantics(
          liveRegion: true,
          child: Text(error!, style: IronlyText.error),
        ),
      ],
    );
  }
}
