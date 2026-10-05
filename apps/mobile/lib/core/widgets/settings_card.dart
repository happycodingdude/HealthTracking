import 'package:flutter/material.dart';

import '../../app/theme.dart';

/// Nhóm các dòng cài đặt trong một thẻ, có đường kẻ mảnh giữa các dòng (S-50, S-56).
class SettingsCard extends StatelessWidget {
  const SettingsCard({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const Divider(indent: 16, endIndent: 16),
            children[i],
          ],
        ],
      ),
    );
  }
}

/// Một dòng: nhãn bên trái, giá trị tóm tắt căn phải, mũi tên nếu chạm được.
/// Cỡ chữ lớn: nhãn và giá trị xếp dọc để không bị cắt (UX-AC18).
class SettingsRow extends StatelessWidget {
  const SettingsRow({super.key, required this.label, this.value, this.onTap});

  final String label;
  final String? value;
  final VoidCallback? onTap;

  /// Từ mức phóng chữ này trở lên thì xếp dọc.
  static const stackedScale = 1.6;

  @override
  Widget build(BuildContext context) {
    final valueStyle = context.text.bodyLarge?.copyWith(
      color: context.palette.textSecondary,
    );
    final stacked = MediaQuery.textScalerOf(context).scale(1) >= stackedScale;
    final labelText = Text(label, style: context.text.bodyLarge);
    final valueText = value == null
        ? null
        : Text(
            value!,
            textAlign: stacked ? TextAlign.start : TextAlign.right,
            style: valueStyle,
          );
    final chevron = onTap == null
        ? null
        : Icon(Icons.chevron_right, color: context.palette.textSecondary);

    final Widget content = stacked
        ? Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    labelText,
                    if (valueText != null) ...[
                      const SizedBox(height: 4),
                      valueText,
                    ],
                  ],
                ),
              ),
              if (chevron != null) chevron,
            ],
          )
        : Row(
            children: [
              // Nhãn theo độ rộng tự nhiên (tối đa 55%), giá trị lấy phần còn lại.
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.sizeOf(context).width * 0.55,
                ),
                child: labelText,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Align(
                  alignment: Alignment.centerRight,
                  child: valueText,
                ),
              ),
              if (chevron != null) chevron,
            ],
          );

    return Semantics(
      button: onTap != null,
      label: value == null ? label : '$label, $value',
      child: ExcludeSemantics(
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 56),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: content,
            ),
          ),
        ),
      ),
    );
  }
}
