import 'package:flutter/material.dart';

import '../../app/strings_vi.dart';
import '../theme.dart';
import 'pause_glyph.dart';

/// Banner tạm dừng (04 Bản 5 §6.2, §6.4 S-10 H7 / H8, §6.5 S-20; UD5-03):
/// thẻ viền 1,5 cam bo 12, hai vạch cam bên trái, "Đến **{thứ dd/mm}**" 13
/// (ngày in đậm), nút nhỏ viền cam "Kết thúc" bên phải. VoiceOver "Đang tạm
/// dừng đến {ngày}".
class PauseBanner extends StatelessWidget {
  const PauseBanner({super.key, required this.until, required this.onEnd});

  /// Ngày kết thúc khoảng, dạng "CN 09/11".
  final String until;
  final VoidCallback onEnd;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final stacked = MediaQuery.textScalerOf(context).scale(1) >= 1.6;
    final text = Semantics(
      container: true,
      label: S.pausingUntil(until),
      child: ExcludeSemantics(
        child: Text.rich(
          TextSpan(
            children: [
              const TextSpan(text: S.pauseUntilPrefix),
              TextSpan(
                text: until,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ],
          ),
          key: const ValueKey('pause-banner-until'),
          style: IronlyText.cardTitle.copyWith(
            color: t.textPrimary,
            fontWeight: FontWeight.w400,
          ),
        ),
      ),
    );
    final action = Semantics(
      button: true,
      label: S.endPauseAction,
      child: ExcludeSemantics(
        child: Material(
          color: TokenColor.transparent,
          borderRadius: BorderRadius.circular(TokenRadius.buttonSmall),
          child: InkWell(
            key: const ValueKey('pause-banner-end'),
            borderRadius: BorderRadius.circular(TokenRadius.buttonSmall),
            onTap: onEnd,
            child: Container(
              constraints: const BoxConstraints(
                minHeight: TokenSize.buttonSmall,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(TokenRadius.buttonSmall),
                border: Border.all(
                  color: t.accent,
                  width: TokenSize.fieldStroke,
                ),
              ),
              child: Text(
                S.endPauseAction,
                style: IronlyText.button.copyWith(
                  fontSize: TokenType.buttonSmall,
                  color: t.accent,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    const glyph = PauseGlyph(accent: true, label: null);
    return Container(
      key: const ValueKey('pause-banner'),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(TokenRadius.banner),
        border: Border.all(color: t.accent, width: TokenSize.fieldStroke),
      ),
      child: stacked
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    glyph,
                    const SizedBox(width: TokenSpace.s3),
                    Expanded(child: text),
                  ],
                ),
                const SizedBox(height: TokenSpace.s2),
                Align(alignment: Alignment.centerRight, child: action),
              ],
            )
          : Row(
              children: [
                glyph,
                const SizedBox(width: TokenSpace.s3),
                Expanded(child: text),
                const SizedBox(width: TokenSpace.s3),
                action,
              ],
            ),
    );
  }
}
