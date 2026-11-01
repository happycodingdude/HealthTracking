import 'package:flutter/material.dart';

/// Icon xoay vòng liên tục, ngược chiều kim đồng hồ (theo chiều mũi tên của
/// `Icons.sync`), 1 vòng/giây: báo việc đang chạy (chưa đồng bộ ở S-50).
/// Bật Giảm chuyển động (Reduce Motion) thì đứng yên. Test đặt [animate] =
/// false để `pumpAndSettle` không chờ vô hạn.
class SpinningIcon extends StatefulWidget {
  const SpinningIcon(
    this.icon, {
    super.key,
    required this.size,
    required this.color,
    this.semanticLabel,
  });

  final IconData icon;
  final double size;
  final Color color;
  final String? semanticLabel;

  /// Tắt xoay trong test.
  static bool animate = true;

  static const period = Duration(seconds: 1);

  @override
  State<SpinningIcon> createState() => _SpinningIconState();
}

class _SpinningIconState extends State<SpinningIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: SpinningIcon.period,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final spin =
        SpinningIcon.animate && !MediaQuery.disableAnimationsOf(context);
    if (spin && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!spin && _controller.isAnimating) {
      _controller
        ..stop()
        ..value = 0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RotationTransition(
    turns: Tween(begin: 0.0, end: -1.0).animate(_controller),
    child: Icon(
      widget.icon,
      size: widget.size,
      color: widget.color,
      semanticLabel: widget.semanticLabel,
    ),
  );
}
