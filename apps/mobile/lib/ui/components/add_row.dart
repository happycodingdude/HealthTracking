import 'package:flutter/material.dart';

import '../theme.dart';

/// Dòng viền đứt (04 Bản 5 §6.1 `AddRow`, UD5-05): cao 38, bo 10, viền 1,5
/// đứt rất mờ, chữ cam 14 / 600 ở giữa. Không bấm được ([onTap] null) → mờ
/// 40 %. Dùng cho "+ Thêm bài" cuối danh sách bài của buổi hôm nay.
class AddRow extends StatelessWidget {
  const AddRow({super.key, required this.label, required this.onTap});

  final String label;
  final VoidCallback? onTap;

  static const _height = 38.0;
  static const _radius = 10.0;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Semantics(
      button: true,
      enabled: onTap != null,
      label: label,
      child: ExcludeSemantics(
        child: Opacity(
          opacity: onTap == null ? 0.4 : 1,
          child: CustomPaint(
            foregroundPainter: DashedBorderPainter(
              color: t.textFaint,
              radius: _radius,
              width: TokenSize.fieldStroke,
            ),
            child: Material(
              type: MaterialType.transparency,
              child: InkWell(
                borderRadius: BorderRadius.circular(_radius),
                onTap: onTap,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: _height),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: TokenSpace.s3,
                      vertical: TokenSpace.s2,
                    ),
                    child: Center(
                      child: Text(
                        label,
                        textAlign: TextAlign.center,
                        style: IronlyText.body.copyWith(
                          fontWeight: FontWeight.w600,
                          color: t.accent,
                        ),
                      ),
                    ),
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

/// Viền đứt bo góc: nét 5, khoảng 4. Dùng cả cho ô lịch ngày tạm dừng
/// (04 Bản 5 §6.2).
class DashedBorderPainter extends CustomPainter {
  const DashedBorderPainter({
    required this.color,
    required this.radius,
    required this.width,
  });

  final Color color;
  final double radius;
  final double width;

  static const _dash = 5.0;
  static const _gap = 4.0;

  @override
  void paint(Canvas canvas, Size size) {
    final inset = width / 2;
    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(inset, inset, size.width - width, size.height - width),
      Radius.circular(radius),
    );
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = width;
    for (final metric in (Path()..addRRect(rrect)).computeMetrics()) {
      var d = 0.0;
      while (d < metric.length) {
        final end = (d + _dash).clamp(0.0, metric.length);
        canvas.drawPath(metric.extractPath(d, end), paint);
        d += _dash + _gap;
      }
    }
  }

  @override
  bool shouldRepaint(DashedBorderPainter old) =>
      old.color != color || old.radius != radius || old.width != width;
}
