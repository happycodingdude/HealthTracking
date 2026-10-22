import 'package:flutter/material.dart';

import '../../app/theme.dart';

/// Thanh chọn mục (04 Bản 2 §6.10): 2–3 mục, nền xám nhạt, mục đang chọn nền
/// trắng chữ đậm; mỗi mục cao tối thiểu 44 điểm. Không đủ chỗ cho mọi mục
/// trên một hàng (cỡ chữ lớn) thì xuống hai hàng, không cắt chữ (§6.3.2).
class SectionBar<T> extends StatelessWidget {
  const SectionBar({
    super.key,
    required this.items,
    required this.selected,
    required this.label,
    required this.onSelected,
    this.keyOf,
  });

  final List<T> items;

  /// null: chưa mục nào được chọn (S-64 lần ghi đầu, UA3-09).
  final T? selected;
  final String Function(T) label;
  final ValueChanged<T> onSelected;

  /// Key của từng mục (test, integration test).
  final Key Function(T)? keyOf;

  static const _padding = 4.0;
  static const _itemPadding = 12.0;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final style = context.text.titleMedium;
    return LayoutBuilder(
      builder: (context, constraints) {
        final scaler = MediaQuery.textScalerOf(context);
        final widest = items
            .map((i) {
              final p = TextPainter(
                text: TextSpan(
                  text: label(i),
                  style: style?.copyWith(fontWeight: FontWeight.w700),
                ),
                textDirection: TextDirection.ltr,
                textScaler: scaler,
              )..layout();
              final w = p.width;
              p.dispose();
              return w;
            })
            .reduce((a, b) => a > b ? a : b);
        final perItem =
            (constraints.maxWidth - 2 * _padding) / items.length -
            2 * _itemPadding;
        final rows = widest <= perItem || items.length < 3
            ? [items]
            : [items.sublist(0, 2), items.sublist(2)];
        return DecoratedBox(
          decoration: BoxDecoration(
            color: palette.neutralContainer,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Padding(
            padding: const EdgeInsets.all(_padding),
            child: Column(
              children: [
                // Các ô cùng hàng cao bằng nhau khi một ô xuống dòng.
                for (final row in rows)
                  IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (final item in row)
                          Expanded(child: _segment(context, item, style)),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _segment(BuildContext context, T item, TextStyle? style) {
    final isSelected = item == selected;
    return Semantics(
      button: true,
      selected: isSelected,
      label: label(item),
      child: ExcludeSemantics(
        child: InkWell(
          key: keyOf?.call(item),
          borderRadius: BorderRadius.circular(10),
          onTap: () => onSelected(item),
          child: Container(
            constraints: const BoxConstraints(minHeight: 44),
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(
              horizontal: _itemPadding,
              vertical: 8,
            ),
            decoration: isSelected
                ? BoxDecoration(
                    color: context.palette.card,
                    borderRadius: BorderRadius.circular(10),
                  )
                : null,
            child: Text(
              label(item),
              textAlign: TextAlign.center,
              style: style?.copyWith(
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
                color: isSelected ? null : context.palette.textSecondary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
