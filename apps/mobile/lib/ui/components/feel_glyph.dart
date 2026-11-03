import 'package:domain/domain.dart';
import 'package:flutter/material.dart';

import '../../app/strings_vi.dart';
import '../theme.dart';

/// Dấu mức thoải mái `FeelGlyph` (04 Bản 5 §6.1, §6.2, UD5-01): ba vạch rộng
/// 3, cao 5 / 8 / 12, cách 2 (tổng 13 × 12), căn đáy. 1 / 2 / 3 vạch "sáng" =
/// Thoải mái / Vừa / Mệt; vạch sáng màu cam (hôm nay) hoặc chữ phụ (buổi
/// trước, [previous]); vạch còn lại rất mờ `#3A3A3C`. Không chữ, không màu
/// phụ (UD4-03). VoiceOver: "Thoải mái" / "Vừa" / "Mệt" (+ "buổi trước").
class FeelGlyph extends StatelessWidget {
  const FeelGlyph(this.feel, {super.key, this.previous = false});

  final Feel feel;

  /// Mức thoải mái buổi trước: vạch sáng màu chữ phụ thay vì cam.
  final bool previous;

  static const width = 13.0;
  static const height = 12.0;
  static const _bar = 3.0;
  static const _gap = 2.0;
  static const _heights = [5.0, 8.0, 12.0];

  /// Số vạch sáng (F33-R1).
  static int lit(Feel f) => switch (f) {
    Feel.easy => 1,
    Feel.medium => 2,
    Feel.hard => 3,
  };

  /// Nhãn VoiceOver (04 Bản 5 §6.9).
  static String labelOf(Feel f, {bool previous = false}) {
    final name = nameOf(f);
    return previous ? S.feelPrevious(name) : name;
  }

  /// Tên mức (thanh chọn S-64, VoiceOver).
  static String nameOf(Feel f) => switch (f) {
    Feel.easy => S.feelEasy,
    Feel.medium => S.feelMedium,
    Feel.hard => S.feelHard,
  };

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final on = previous ? t.textSecondary : t.accent;
    final n = lit(feel);
    return Semantics(
      label: labelOf(feel, previous: previous),
      container: true,
      child: ExcludeSemantics(
        child: SizedBox(
          width: width,
          height: height,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (var i = 0; i < 3; i++) ...[
                if (i > 0) const SizedBox(width: _gap),
                Container(
                  key: ValueKey('feel-bar-$i-${i < n ? 'on' : 'off'}'),
                  width: _bar,
                  height: _heights[i],
                  decoration: BoxDecoration(
                    color: i < n ? on : t.textFaint,
                    borderRadius: BorderRadius.circular(1),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
