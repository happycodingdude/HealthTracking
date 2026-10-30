import 'package:flutter/material.dart';

import '../keys.dart';
import '../theme.dart';

/// Banner cảnh báo / lỗi (04 Bản 4 §6.1): thẻ viền 1,5 cam bo 12, câu giữ
/// nguyên (FR4-03), nút nhỏ cam bên phải nếu có hành động (Thử lại, Mở Cài
/// đặt, Chia lại). [icon] tùy chọn bên trái.
class IronlyBanner extends StatelessWidget {
  const IronlyBanner({
    super.key,
    required this.text,
    this.actionLabel,
    this.onAction,
    this.icon,
    this.actionKey = K.bannerAction,
    this.filledAction = false,
  });

  final String text;
  final String? actionLabel;
  final VoidCallback? onAction;
  final IconData? icon;
  final Key actionKey;

  /// Nút nhỏ nền cam ("Chia lại") thay vì chữ cam ("Mở Cài đặt").
  final bool filledAction;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final stacked = MediaQuery.textScalerOf(context).scale(1) >= 1.6;
    final action = actionLabel == null
        ? null
        : Semantics(
            button: true,
            label: actionLabel,
            child: ExcludeSemantics(
              child: Material(
                color: filledAction ? t.accent : TokenColor.transparent,
                borderRadius: BorderRadius.circular(TokenRadius.buttonSmall),
                child: InkWell(
                  key: actionKey,
                  borderRadius: BorderRadius.circular(TokenRadius.buttonSmall),
                  onTap: onAction,
                  child: Container(
                    constraints: const BoxConstraints(
                      minHeight: TokenSize.buttonSmall,
                    ),
                    padding: EdgeInsets.symmetric(
                      horizontal: filledAction ? 12 : 4,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      actionLabel!,
                      style: IronlyText.button.copyWith(
                        fontSize: TokenType.buttonSmall,
                        color: filledAction ? t.onAccent : t.accent,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
    final message = Text(
      text,
      style: IronlyText.caption2.copyWith(color: t.textPrimary),
    );
    return Semantics(
      liveRegion: true,
      child: Container(
        key: K.banner,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: t.surface,
          borderRadius: BorderRadius.circular(TokenRadius.banner),
          border: Border.all(color: t.accent, width: TokenSize.fieldStroke),
        ),
        child: stacked && action != null
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      if (icon != null) ...[
                        Icon(icon, size: 18, color: t.accent),
                        const SizedBox(width: TokenSpace.s2),
                      ],
                      Expanded(child: message),
                    ],
                  ),
                  const SizedBox(height: TokenSpace.s2),
                  Align(alignment: Alignment.centerRight, child: action),
                ],
              )
            : Row(
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 18, color: t.accent),
                    const SizedBox(width: TokenSpace.s2),
                  ],
                  Expanded(child: message),
                  if (action != null) ...[
                    const SizedBox(width: TokenSpace.s3),
                    action,
                  ],
                ],
              ),
      ),
    );
  }
}
