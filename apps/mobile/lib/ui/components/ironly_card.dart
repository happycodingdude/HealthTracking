import 'package:flutter/material.dart';

import '../theme.dart';

/// Thẻ than sáng không viền, bo 14, đệm 14 (04 Bản 4 §6.1). [onTap] = chạm cả
/// thẻ. [padding] đổi khi thẻ chứa danh sách dòng (đệm 0, dòng tự đệm).
class IronlyCard extends StatelessWidget {
  const IronlyCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(TokenSize.cardPadding),
    this.color,
    this.border,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;

  /// Mặc định màu thẻ; thẻ nổi (nút xám, khối chọn) truyền `surfaceRaised`.
  final Color? color;

  /// Viền 1,5 (banner cam, ô đang nhập); mặc định không viền.
  final Color? border;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final radius = BorderRadius.circular(TokenRadius.card);
    final box = Ink(
      decoration: BoxDecoration(
        color: color ?? t.surface,
        borderRadius: radius,
        border: border == null
            ? null
            : Border.all(color: border!, width: TokenSize.fieldStroke),
      ),
      child: Padding(padding: padding, child: child),
    );
    if (onTap == null) {
      return Material(type: MaterialType.transparency, child: box);
    }
    return Material(
      type: MaterialType.transparency,
      child: InkWell(borderRadius: radius, onTap: onTap, child: box),
    );
  }
}

/// Thẻ chứa các dòng, vạch 0,5 giữa các dòng (S-50, S-56, danh sách buổi).
class IronlyListCard extends StatelessWidget {
  const IronlyListCard({super.key, required this.children, this.color});

  final List<Widget> children;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return IronlyCard(
      padding: EdgeInsets.zero,
      color: color,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(TokenRadius.card),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < children.length; i++) ...[
              if (i > 0)
                const Divider(
                  indent: TokenSize.cardPadding,
                  endIndent: TokenSize.cardPadding,
                ),
              children[i],
            ],
          ],
        ),
      ),
    );
  }
}

/// Một dòng trong [IronlyListCard]: icon tròn tùy chọn · tên 14 + giá trị
/// tóm tắt 11 chữ phụ · phần phải (giá trị, công tắc, mũi tên). Cỡ chữ lớn:
/// phần phải xuống dưới tên để không bị cắt.
class IronlyRow extends StatelessWidget {
  const IronlyRow({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.value,
    this.chevron = false,
    this.onTap,
    this.titleStyle,
    this.semanticsLabel,
    this.minHeight = 52,
    this.dot = false,
    this.titleWidget,
    this.below,
  });

  /// Dưới tiêu đề / chữ phụ (thanh ngân sách nhỏ ở S-50).
  final Widget? below;

  final String title;

  /// Thay chữ tiêu đề bằng widget (tên món + khẩu phần cùng dòng, S-30).
  final Widget? titleWidget;
  final String? subtitle;
  final Widget? leading;
  final Widget? trailing;

  /// Giá trị bên phải (chữ phụ hoặc số trắng tùy [trailing]).
  final String? value;
  final bool chevron;
  final VoidCallback? onTap;
  final TextStyle? titleStyle;
  final String? semanticsLabel;
  final double minHeight;

  /// Chấm 6 pt cam trước mũi tên (đề xuất chờ, 04 Bản 4 §6.2).
  final bool dot;

  static const stackedScale = 1.6;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final stacked = MediaQuery.textScalerOf(context).scale(1) >= stackedScale;
    final titleText =
        titleWidget ?? Text(title, style: titleStyle ?? IronlyText.body);
    final sub = subtitle == null
        ? null
        : Text(subtitle!, style: IronlyText.caption);
    final right = <Widget>[
      if (value != null)
        Text(
          value!,
          style: IronlyText.body.copyWith(color: t.textSecondary),
          textAlign: TextAlign.right,
        ),
      if (trailing != null) trailing!,
      if (dot)
        Container(
          key: const ValueKey('row-dot'),
          width: TokenSize.dotPending,
          height: TokenSize.dotPending,
          decoration: BoxDecoration(color: t.accent, shape: BoxShape.circle),
        ),
      if (chevron) Icon(Icons.chevron_right, size: 18, color: t.textSecondary),
    ];
    final rightRow = right.isEmpty
        ? null
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final (i, w) in right.indexed) ...[
                if (i > 0) const SizedBox(width: TokenSpace.s2),
                w,
              ],
            ],
          );
    final info = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        titleText,
        if (sub != null) ...[const SizedBox(height: 2), sub],
        if (below != null) below!,
        if (stacked && rightRow != null) ...[
          const SizedBox(height: TokenSpace.s2),
          rightRow,
        ],
      ],
    );
    return Semantics(
      button: onTap != null,
      label: semanticsLabel,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: minHeight),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: TokenSize.cardPadding,
              vertical: TokenSpace.s3,
            ),
            child: Row(
              children: [
                if (leading != null) ...[
                  leading!,
                  const SizedBox(width: TokenSpace.s3),
                ],
                Expanded(child: info),
                if (!stacked && rightRow != null) ...[
                  const SizedBox(width: TokenSpace.s3),
                  rightRow,
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
