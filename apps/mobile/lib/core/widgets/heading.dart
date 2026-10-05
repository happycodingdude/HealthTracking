import 'package:flutter/material.dart';

/// Tiêu đề lớn của màn hình. Giống tiêu đề lớn của iOS, cỡ chữ tiêu đề chỉ
/// phóng tối đa [maxScale] lần khi Bạn chọn cỡ chữ lớn (chữ thường vẫn phóng
/// hết), để tiêu đề không bị ngắt giữa từ (UR-09, UX-AC18).
class Heading extends StatelessWidget {
  const Heading(this.text, {super.key, required this.style, this.textAlign});

  static const maxScale = 1.8;

  final String text;
  final TextStyle? style;
  final TextAlign? textAlign;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      header: true,
      child: MediaQuery.withClampedTextScaling(
        maxScaleFactor: maxScale,
        child: Text(text, style: style, textAlign: textAlign),
      ),
    );
  }
}
