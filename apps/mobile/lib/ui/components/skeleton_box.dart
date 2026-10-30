import 'package:flutter/material.dart';

import '../keys.dart';
import '../theme.dart';

/// Khung chờ (04 Bản 4 §6.1): thanh thẻ nổi bo 6 nhấp nháy. Test đặt
/// [animate] = false để `pumpAndSettle` không chờ vô hạn.
class SkeletonBox extends StatefulWidget {
  const SkeletonBox({super.key, this.width, this.height = 12, this.radius});

  final double? width;
  final double height;
  final double? radius;

  /// Tắt nhấp nháy trong test.
  static bool animate = true;

  @override
  State<SkeletonBox> createState() => _SkeletonBoxState();
}

class _SkeletonBoxState extends State<SkeletonBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  @override
  void initState() {
    super.initState();
    if (SkeletonBox.animate) _controller.repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final box = Container(
      key: K.skeleton,
      width: widget.width,
      height: widget.height,
      decoration: BoxDecoration(
        color: t.surfaceRaised,
        borderRadius: BorderRadius.circular(
          widget.radius ?? TokenRadius.skeleton,
        ),
      ),
    );
    if (!SkeletonBox.animate || MediaQuery.disableAnimationsOf(context)) {
      return box;
    }
    return FadeTransition(
      opacity: Tween(begin: 1.0, end: 0.45).animate(_controller),
      child: box,
    );
  }
}

/// Khối chờ nhiều dòng (thực đơn đang tạo, khôi phục).
class SkeletonLines extends StatelessWidget {
  const SkeletonLines({super.key, this.lines = 2});

  final int lines;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      for (var i = 0; i < lines; i++) ...[
        if (i > 0) const SizedBox(height: TokenSpace.s3),
        FractionallySizedBox(
          alignment: Alignment.centerLeft,
          widthFactor: i.isEven ? 0.85 : 0.55,
          child: const SkeletonBox(),
        ),
      ],
    ],
  );
}
