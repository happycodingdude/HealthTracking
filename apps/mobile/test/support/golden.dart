import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/app/theme.dart';

/// Cỡ chữ lớn nhất của iPhone (Accessibility AX5: 53pt so với 17pt ≈ 3,1×).
const maxTextScale = 3.1;

/// Một biến thể golden: sáng/tối × cỡ chữ mặc định/lớn nhất (UX-AC18).
final class GoldenVariant {
  const GoldenVariant(this.name, this.brightness, this.textScale);

  final String name;
  final Brightness brightness;
  final double textScale;

  ThemeData get theme =>
      brightness == Brightness.light ? AppTheme.light() : AppTheme.dark();

  static const all = [
    GoldenVariant('light', Brightness.light, 1),
    GoldenVariant('dark', Brightness.dark, 1),
    GoldenVariant('light_maxtext', Brightness.light, maxTextScale),
    GoldenVariant('dark_maxtext', Brightness.dark, maxTextScale),
  ];
}

/// Kích thước màn hình iPhone 13/14 (390 × 844 pt), có tai thỏ và thanh vuốt.
const iphoneSize = Size(390, 844);
const iphonePadding = EdgeInsets.only(top: 47, bottom: 34);

/// Đặt kích thước màn hình giả lập cho golden.
void setPhoneSurface(WidgetTester tester, {Size size = iphoneSize}) {
  tester.view
    ..physicalSize = size * 3
    ..devicePixelRatio = 3
    ..padding = FakeViewPadding(
      top: iphonePadding.top * 3,
      bottom: iphonePadding.bottom * 3,
    )
    ..viewPadding = FakeViewPadding(
      top: iphonePadding.top * 3,
      bottom: iphonePadding.bottom * 3,
    );
  addTearDown(tester.view.reset);
}

/// Bọc [child] với theme và cỡ chữ của [variant].
Widget goldenHost(GoldenVariant variant, Widget child) {
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: variant.theme,
    home: Builder(
      builder: (context) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(variant.textScale)),
        child: child,
      ),
    ),
  );
}
