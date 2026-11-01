import 'package:flutter/material.dart';

import '../keys.dart';
import '../theme.dart';

enum IronlyButtonKind {
  /// Nền cam, chữ trắng 14 / 600; nhấn → cam tối.
  primary,

  /// Nền trong, viền 1,5 thẻ nổi, chữ trắng 14 / 500.
  secondary,

  /// Nền trong, viền 1,5 cam, chữ cam 14 / 500 ("↻ Gợi ý lại · 2").
  secondaryAccent,

  /// Nền thẻ nổi, chữ trắng 14 / 600.
  gray,

  /// Chữ đỏ 13 / 500, không nền (Xóa…).
  danger,

  /// Chữ cam 14 / 500, không nền ("Trả về theo lịch tuần", "Để sau").
  link,
}

/// Nút của Bản 4 (04 Bản 4 §6.1): cao 44, bo 10; nút nhỏ cao 32, bo 8. Nút
/// không làm được thì mờ, không ẩn, chạm không phản ứng (03 Bản 4 F4-R6).
/// [loading]: vòng xoay nhỏ, không bấm lặp, vẫn giữ màu.
class IronlyButton extends StatelessWidget {
  const IronlyButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.kind = IronlyButtonKind.primary,
    this.small = false,
    this.enabled = true,
    this.loading = false,
    this.icon,
    this.expand = true,
    this.large = false,
    this.height,
  });

  const IronlyButton.primary({
    super.key,
    required this.label,
    required this.onPressed,
    this.small = false,
    this.enabled = true,
    this.loading = false,
    this.icon,
    this.expand = true,
    this.large = false,
    this.height,
  }) : kind = IronlyButtonKind.primary;

  const IronlyButton.gray({
    super.key,
    required this.label,
    required this.onPressed,
    this.small = false,
    this.enabled = true,
    this.loading = false,
    this.icon,
    this.expand = true,
    this.large = false,
    this.height,
  }) : kind = IronlyButtonKind.gray;

  const IronlyButton.secondary({
    super.key,
    required this.label,
    required this.onPressed,
    this.small = false,
    this.enabled = true,
    this.loading = false,
    this.icon,
    this.expand = true,
    this.large = false,
    this.height,
  }) : kind = IronlyButtonKind.secondary;

  const IronlyButton.danger({
    super.key,
    required this.label,
    required this.onPressed,
    this.small = false,
    this.enabled = true,
    this.loading = false,
    this.icon,
    this.expand = true,
    this.large = false,
    this.height,
  }) : kind = IronlyButtonKind.danger;

  const IronlyButton.link({
    super.key,
    required this.label,
    required this.onPressed,
    this.small = false,
    this.enabled = true,
    this.loading = false,
    this.icon,
    this.expand = true,
    this.large = false,
    this.height,
  }) : kind = IronlyButtonKind.link;

  final String label;
  final VoidCallback? onPressed;
  final IronlyButtonKind kind;
  final bool small;
  final bool enabled;
  final bool loading;
  final IconData? icon;

  /// Trọn bề ngang (mặc định); false = vừa chữ (nút nhỏ trong banner, thẻ).
  final bool expand;

  /// Nút của bộ màn đăng nhập S-01 → S-01c (04 Bản 4 v1.7 §6.1 ngoại lệ cỡ):
  /// cao 56, bo 16, nhãn 17; nút cam chữ màu nền `#121212` 700, nút xám nền
  /// thẻ chữ trắng 600.
  final bool large;

  /// Chiều cao riêng (nút "Đã hiểu" S-01c cao 52); mặc định theo cỡ nút.
  final double? height;

  /// Độ mờ của nút không làm được (F4-R6).
  static const disabledOpacity = 0.4;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final active = enabled && onPressed != null;
    final height =
        this.height ??
        (large
            ? TokenSize.authButton
            : small
            ? TokenSize.buttonSmall
            : TokenSize.button);
    final radius = BorderRadius.circular(
      large
          ? TokenRadius.authButton
          : small
          ? TokenRadius.buttonSmall
          : TokenRadius.button,
    );
    final (Color bg, Color fg, Color? border, TextStyle style) = switch (kind) {
      IronlyButtonKind.primary when large => (
        t.accent,
        t.bg,
        null,
        IronlyText.authButton,
      ),
      IronlyButtonKind.gray when large => (
        t.surface,
        t.textPrimary,
        null,
        IronlyText.authButtonGray,
      ),
      IronlyButtonKind.primary => (
        t.accent,
        t.onAccent,
        null,
        IronlyText.button,
      ),
      IronlyButtonKind.gray => (
        t.surfaceRaised,
        t.textPrimary,
        null,
        IronlyText.button,
      ),
      IronlyButtonKind.secondary => (
        TokenColor.transparent,
        t.textPrimary,
        t.surfaceRaised,
        IronlyText.buttonSecondary,
      ),
      IronlyButtonKind.secondaryAccent => (
        TokenColor.transparent,
        t.accent,
        t.accent,
        IronlyText.buttonSecondary,
      ),
      IronlyButtonKind.danger => (
        TokenColor.transparent,
        t.danger,
        null,
        IronlyText.buttonDanger,
      ),
      IronlyButtonKind.link => (
        TokenColor.transparent,
        t.accent,
        null,
        IronlyText.buttonSecondary,
      ),
    };
    final textStyle = style.copyWith(
      color: fg,
      fontSize: small ? TokenType.buttonSmall : style.fontSize,
    );
    final child = loading
        ? SizedBox.square(
            key: K.buttonSpinner,
            dimension: 20,
            child: CircularProgressIndicator(strokeWidth: 2.5, color: fg),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 16, color: fg),
                const SizedBox(width: TokenSpace.s1 + 2),
              ],
              Flexible(
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: textStyle,
                ),
              ),
            ],
          );
    final body = Material(
      color: bg,
      borderRadius: radius,
      child: InkWell(
        borderRadius: radius,
        onTap: active && !loading ? onPressed : null,
        // Nút chính đổi sang cam tối khi nhấn (04 Bản 4 §6.10).
        highlightColor: kind == IronlyButtonKind.primary
            ? t.accentPressed
            : t.surfaceRaised,
        splashFactory: NoSplash.splashFactory,
        child: Container(
          constraints: BoxConstraints(minHeight: height),
          decoration: border == null
              ? null
              : BoxDecoration(
                  borderRadius: radius,
                  border: Border.all(
                    color: border,
                    width: TokenSize.fieldStroke,
                  ),
                ),
          padding: EdgeInsets.symmetric(
            horizontal: small ? TokenSpace.s4 : TokenSpace.s5,
            vertical: small ? 4 : TokenSpace.s2,
          ),
          // [expand]: trọn bề ngang của cha; không thì vừa chữ (trong Wrap,
          // banner, thẻ).
          child: Align(
            widthFactor: expand ? null : 1,
            heightFactor: 1,
            child: child,
          ),
        ),
      ),
    );
    return Semantics(
      button: true,
      enabled: active,
      label: label,
      child: ExcludeSemantics(
        child: Opacity(opacity: active ? 1 : disabledOpacity, child: body),
      ),
    );
  }
}
