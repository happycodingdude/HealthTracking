import 'package:flutter/material.dart';

import '../../app/strings_vi.dart';
import '../theme.dart';

/// Dấu tạm dừng `PauseGlyph` (04 Bản 5 §6.1, §6.2, UD5-03): hai vạch dọc
/// rộng [barWidth], cao [barHeight], cách 2. Màu chữ phụ (trong vòng tròn,
/// ô lịch, dòng buổi tới) hoặc cam ([accent]: banner, tiêu đề S-76).
/// VoiceOver "Tạm dừng" (bỏ nhãn bằng [label] = null khi đã nằm trong một
/// nhãn lớn hơn).
class PauseGlyph extends StatelessWidget {
  const PauseGlyph({
    super.key,
    this.barWidth = 2.5,
    this.barHeight = 11,
    this.accent = false,
    this.color,
    this.label = S.statusPaused,
  });

  /// Cỡ đứng rời trong ô lịch (2 × 6, 04 Bản 5 §6.2).
  const PauseGlyph.small({super.key, this.color, this.label = S.statusPaused})
    : barWidth = 2,
      barHeight = 6,
      accent = false;

  final double barWidth;
  final double barHeight;
  final bool accent;

  /// Màu riêng (đè [accent]).
  final Color? color;
  final String? label;

  static const _gap = 2.0;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final c = color ?? (accent ? t.accent : t.textSecondary);
    Widget bar(int i) => Container(
      key: ValueKey('pause-bar-$i'),
      width: barWidth,
      height: barHeight,
      decoration: BoxDecoration(
        color: c,
        borderRadius: BorderRadius.circular(barWidth / 2),
      ),
    );
    final glyph = SizedBox(
      key: const ValueKey('pause-glyph'),
      width: barWidth * 2 + _gap,
      height: barHeight,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          bar(0),
          const SizedBox(width: _gap),
          bar(1),
        ],
      ),
    );
    if (label == null) return ExcludeSemantics(child: glyph);
    return Semantics(
      container: true,
      label: label,
      child: ExcludeSemantics(child: glyph),
    );
  }
}
