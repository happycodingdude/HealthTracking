import 'package:flutter/material.dart';

import '../keys.dart';
import '../theme.dart';

enum DotState { done, today, idle }

/// Chấm tiến độ 8 pt (widget, thẻ ngân sách…): cam đã tập, viền cam hôm nay,
/// thẻ nổi còn lại (04 Bản 4 S-70).
class ProgressDots extends StatelessWidget {
  const ProgressDots({
    super.key,
    required this.dots,
    required this.label,
    this.size = TokenSize.dot,
  });

  final List<DotState> dots;

  /// Nhãn VoiceOver, ví dụ "Đã tập 2/4 buổi theo lịch".
  final String label;
  final double size;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Semantics(
      label: label,
      child: ExcludeSemantics(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final (i, d) in dots.indexed) ...[
              if (i > 0) SizedBox(width: size * 0.5),
              Container(
                key: K.progressDot(i),
                width: size,
                height: size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: switch (d) {
                    DotState.done => t.accent,
                    DotState.today => null,
                    DotState.idle => t.surfaceRaised,
                  },
                  border: d == DotState.today
                      ? Border.all(color: t.accent, width: 1.5)
                      : null,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
