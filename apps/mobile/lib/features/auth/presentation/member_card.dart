import 'package:flutter/material.dart';

import '../../../app/strings_vi.dart';
import '../../../ui/theme.dart';

/// Tấm thẻ hội viên của bộ màn đăng nhập (04 Bản 4 v1.7 §6.1, §6.7, UA4-04):
/// 342 × 206 bo 22, nền thẻ, đệm 22, không viền, không bóng. Ba hàng căn đều
/// trên – giữa – dưới: thanh tạ cam + chip; chữ; mã vạch trang trí + "IRONLY".
///
/// Thẻ chỉ hiển thị lại chữ đang gõ ở ô nhập (03 Bản 4 F4-R15): không kiểm
/// tra, không lưu. Ô trống → dòng đó để trống, thẻ giữ nguyên cỡ và vị trí
/// mọi phần. Thẻ co giãn theo bề ngang nội dung, giữ tỉ lệ 342 : 206 (đúng
/// 342 × 206 ở màn rộng 390); chữ trên thẻ không phóng theo cỡ chữ của iPhone
/// vì thẻ là hình — chữ thật vẫn ở ô nhập bên dưới.
class MemberCard extends StatelessWidget {
  /// S-01a: [name] và [phone] đang gõ. S-01b: [name] = null (chưa biết tên),
  /// dòng số điện thoại cỡ lớn ở hàng giữa.
  const MemberCard({super.key, this.name, this.phone = ''}) : brand = false;

  /// Thẻ trước ở S-01: hàng giữa "IRONLY" 30 / 800, hàng dưới chỉ mã vạch 18
  /// vạch cao 26.
  const MemberCard.brand({super.key}) : name = null, phone = '', brand = true;

  final String? name;
  final String phone;
  final bool brand;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return ExcludeSemantics(
      child: MemberCardFrame(
        color: t.surface,
        child: MediaQuery.withNoTextScaling(
          child: Padding(
            padding: const EdgeInsets.all(TokenSize.memberCardPadding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    CustomPaint(
                      key: const ValueKey('member-card-barbell'),
                      size: const Size(44, 22),
                      painter: _BarbellPainter(t.accent),
                    ),
                    CustomPaint(
                      key: const ValueKey('member-card-chip'),
                      size: const Size(36, 27),
                      painter: _ChipPainter(
                        fill: t.surfaceRaised,
                        stroke: t.accent,
                      ),
                    ),
                  ],
                ),
                _middle(),
                if (brand)
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: _Barcode(bars: 18, height: 26),
                  )
                else
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const _Barcode(bars: 12, height: 22),
                      Text(S.cardBrand, style: IronlyText.memberFooter),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _middle() {
    if (brand) {
      return Text(
        S.cardBrand,
        key: const ValueKey('member-card-brand'),
        style: IronlyText.memberBrand,
        maxLines: 1,
      );
    }
    final name = this.name;
    if (name == null) {
      return _line('member-card-phone', phone, IronlyText.memberName);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _line('member-card-name', name.toUpperCase(), IronlyText.memberName),
        const SizedBox(height: TokenSpace.s1),
        _line('member-card-phone', phone, IronlyText.memberPhone),
      ],
    );
  }

  /// Một dòng chữ trên thẻ: luôn một dòng, dài thì cắt "…"; trống vẫn giữ
  /// chiều cao dòng để thẻ không xê dịch (UA4-04).
  static Widget _line(String key, String text, TextStyle style) => Text(
    text.isEmpty ? ' ' : text,
    key: ValueKey(key),
    style: style,
    maxLines: 1,
    softWrap: false,
    overflow: TextOverflow.ellipsis,
  );
}

/// Khung thẻ 342 × 206 bo 22, co giãn theo bề ngang được cấp, giữ tỉ lệ. Dùng
/// cho tấm thẻ và thẻ sau (không nội dung) ở S-01.
class MemberCardFrame extends StatelessWidget {
  const MemberCardFrame({super.key, required this.color, this.child});

  final Color color;
  final Widget? child;

  @override
  Widget build(BuildContext context) => AspectRatio(
    aspectRatio: TokenSize.memberCardWidth / TokenSize.memberCardHeight,
    child: FittedBox(
      child: SizedBox(
        width: TokenSize.memberCardWidth,
        height: TokenSize.memberCardHeight,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(TokenRadius.memberCard),
          ),
          child: child,
        ),
      ),
    ),
  );
}

/// Thanh tạ nằm ngang cùng hình icon app (design/app_icon.svg): thanh đòn,
/// đĩa trong cao, đĩa ngoài thấp, đầu thanh. Vẽ lại theo tọa độ 1024 của SVG,
/// thu theo bề ngang khung.
class _BarbellPainter extends CustomPainter {
  const _BarbellPainter(this.color);

  final Color color;

  // Khung chứa hình trong hệ 1024 của SVG (tính cả đầu tròn nét 40).
  static const _left = 130.0;
  static const _right = 894.0;
  static const _top = 356.0;
  static const _bottom = 668.0;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / (_right - _left);
    final dy = (size.height - (_bottom - _top) * s) / 2;
    canvas
      ..save()
      ..translate(0, dy)
      ..scale(s)
      ..translate(-_left, -_top);
    final line = Paint()
      ..color = color
      ..strokeWidth = 40
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final fill = Paint()..color = color;
    canvas
      ..drawLine(const Offset(342, 512), const Offset(682, 512), line)
      ..drawLine(const Offset(150, 512), const Offset(206, 512), line)
      ..drawLine(const Offset(818, 512), const Offset(874, 512), line);
    for (final (x, y, w, h, r) in const [
      (286.0, 356.0, 76.0, 312.0, 30.0),
      (662.0, 356.0, 76.0, 312.0, 30.0),
      (206.0, 412.0, 60.0, 200.0, 26.0),
      (758.0, 412.0, 60.0, 200.0, 26.0),
    ]) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(x, y, w, h), Radius.circular(r)),
        fill,
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_BarbellPainter old) => old.color != color;
}

/// Chip 36 × 27 bo 6: nền thẻ nổi, viền 1,5 cam, hai vạch cam ngang 1,5
/// (hình trang trí cố định, UA4-04).
class _ChipPainter extends CustomPainter {
  const _ChipPainter({required this.fill, required this.stroke});

  final Color fill;
  final Color stroke;

  @override
  void paint(Canvas canvas, Size size) {
    const w = TokenSize.fieldStroke;
    final rect = RRect.fromRectAndRadius(
      (Offset.zero & size).deflate(w / 2),
      const Radius.circular(TokenRadius.memberChip),
    );
    final line = Paint()
      ..color = stroke
      ..strokeWidth = w
      ..style = PaintingStyle.stroke;
    canvas
      ..drawRRect(rect, Paint()..color = fill)
      ..drawRRect(rect, line);
    const inset = 6.0;
    for (final y in [size.height * 0.4, size.height * 0.62]) {
      canvas.drawLine(Offset(inset, y), Offset(size.width - inset, y), line);
    }
  }

  @override
  bool shouldRepaint(_ChipPainter old) =>
      old.fill != fill || old.stroke != stroke;
}

/// Mã vạch trang trí cố định (UA4-04): vạch trắng rộng 2–5, cách 3; giống
/// nhau cho mọi người, không mã hóa dữ liệu nào.
class _Barcode extends StatelessWidget {
  const _Barcode({required this.bars, required this.height});

  final int bars;
  final double height;

  static const _widths = [
    3.0, 2.0, 4.0, 2.0, 2.0, 5.0, 3.0, 2.0, 4.0, //
    2.0, 3.0, 5.0, 2.0, 2.0, 4.0, 3.0, 2.0, 4.0,
  ];
  static const _gap = 3.0;

  @override
  Widget build(BuildContext context) {
    final widths = _widths.take(bars).toList();
    final total = widths.fold(0.0, (a, w) => a + w) + _gap * (bars - 1);
    return CustomPaint(
      key: const ValueKey('member-card-barcode'),
      size: Size(total, height),
      painter: _BarcodePainter(widths, context.tokens.textPrimary),
    );
  }
}

class _BarcodePainter extends CustomPainter {
  const _BarcodePainter(this.widths, this.color);

  final List<double> widths;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    var x = 0.0;
    for (final w in widths) {
      canvas.drawRect(Rect.fromLTWH(x, 0, w, size.height), paint);
      x += w + _Barcode._gap;
    }
  }

  @override
  bool shouldRepaint(_BarcodePainter old) =>
      old.color != color || old.widths.length != widths.length;
}
