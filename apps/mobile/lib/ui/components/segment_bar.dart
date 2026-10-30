import 'package:flutter/material.dart';

import '../keys.dart';
import '../theme.dart';

enum SegmentStyle {
  /// Mục chọn nền thẻ nổi, chữ trắng 600 (thanh Lịch · Bài tập · Tiến bộ).
  raised,

  /// Mục chọn nền cam, chữ trắng 600 (kg | nấc máy, Tự động | Tự đặt, Nam |
  /// Nữ, Đã tập / Không tập).
  accent,
}

/// Thanh chọn mục (04 Bản 4 §6.1): nền thẻ bo 10, mục chọn bo 8. Cỡ chữ lớn
/// không đủ chỗ thì xuống hai hàng, không cắt chữ. [selected] = null: chưa
/// chọn mục nào (lần ghi đầu).
class SegmentBar<T> extends StatelessWidget {
  const SegmentBar({
    super.key,
    required this.items,
    required this.selected,
    required this.label,
    required this.onSelected,
    this.keyOf,
    this.style = SegmentStyle.raised,
    this.enabled = true,
    this.background,
  });

  final List<T> items;
  final T? selected;
  final String Function(T) label;
  final ValueChanged<T> onSelected;
  final Key Function(T)? keyOf;
  final SegmentStyle style;
  final bool enabled;

  /// Nền thanh; mặc định màu thẻ (trên nền) — trong thẻ truyền `surfaceRaised`.
  final Color? background;

  static const _padding = 3.0;
  static const _itemPadding = 10.0;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final textStyle = IronlyText.body;
    return LayoutBuilder(
      builder: (context, constraints) {
        final scaler = MediaQuery.textScalerOf(context);
        final widest = items
            .map((i) {
              final p = TextPainter(
                text: TextSpan(
                  text: label(i),
                  style: textStyle.copyWith(fontWeight: FontWeight.w600),
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
        return Opacity(
          opacity: enabled ? 1 : 0.4,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: background ?? t.surface,
              borderRadius: BorderRadius.circular(TokenRadius.segmentOuter),
            ),
            child: Padding(
              padding: const EdgeInsets.all(_padding),
              child: Column(
                children: [
                  for (final row in rows)
                    IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          for (final item in row)
                            Expanded(child: _segment(context, item, textStyle)),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _segment(BuildContext context, T item, TextStyle textStyle) {
    final t = context.tokens;
    final isSelected = item == selected;
    final selectedBg = style == SegmentStyle.accent
        ? t.accent
        : t.surfaceRaised;
    return Semantics(
      button: true,
      selected: isSelected,
      enabled: enabled,
      label: label(item),
      child: ExcludeSemantics(
        child: InkWell(
          key: keyOf?.call(item) ?? K.segment(label(item)),
          borderRadius: BorderRadius.circular(TokenRadius.segmentInner),
          onTap: enabled ? () => onSelected(item) : null,
          child: Container(
            constraints: const BoxConstraints(minHeight: 34),
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(
              horizontal: _itemPadding,
              vertical: 6,
            ),
            decoration: isSelected
                ? BoxDecoration(
                    color: selectedBg,
                    borderRadius: BorderRadius.circular(
                      TokenRadius.segmentInner,
                    ),
                  )
                : null,
            child: Text(
              label(item),
              textAlign: TextAlign.center,
              style: textStyle.copyWith(
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                color: isSelected ? t.textPrimary : t.textSecondary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Viên chọn (nhóm cơ, 04 Bản 4 §6.1): tròn, viền 1,5 thẻ nổi; chọn = nền cam.
class IronlyChip extends StatelessWidget {
  const IronlyChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.enabled = true,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Semantics(
      button: true,
      selected: selected,
      enabled: enabled,
      label: label,
      child: ExcludeSemantics(
        child: Opacity(
          opacity: enabled ? 1 : 0.4,
          child: Material(
            color: selected ? t.accent : TokenColor.transparent,
            shape: StadiumBorder(
              side: selected
                  ? BorderSide.none
                  : BorderSide(
                      color: t.surfaceRaised,
                      width: TokenSize.fieldStroke,
                    ),
            ),
            child: InkWell(
              customBorder: const StadiumBorder(),
              onTap: enabled ? onTap : null,
              child: Container(
                constraints: const BoxConstraints(minHeight: 34),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 6,
                ),
                alignment: Alignment.center,
                child: Text(
                  label,
                  style: IronlyText.body.copyWith(
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                    color: t.textPrimary,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
