import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/ui/theme.dart';

/// Cỡ chữ lớn nhất của iPhone (Accessibility AX5: 53pt so với 17pt ≈ 3,1×).
const maxTextScale = 3.1;

/// Một biến thể golden Bản 4: theme tối × cỡ chữ mặc định / lớn nhất
/// (05 Bản 4 TA4-04). Không còn biến thể sáng.
final class GoldenVariant {
  const GoldenVariant(this.name, this.textScale);

  final String name;
  final double textScale;

  /// App luôn tối (TD4-03).
  Brightness get brightness => Brightness.dark;

  ThemeData get theme => IronlyTheme.dark();

  static const all = [
    GoldenVariant('dark', 1),
    GoldenVariant('dark_maxtext', maxTextScale),
  ];

  /// Chỉ cỡ chữ mặc định (thành phần nhỏ không cần biến thể cỡ lớn).
  static const normal = GoldenVariant('dark', 1);
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

/// Đặt cỡ chữ của [variant] cho cả app (theme luôn tối).
void applyVariant(WidgetTester tester, GoldenVariant variant) {
  tester.platformDispatcher
    ..platformBrightnessTestValue = Brightness.dark
    ..textScaleFactorTestValue = variant.textScale;
  addTearDown(tester.platformDispatcher.clearAllTestValues);
}

/// Bọc [child] với theme tối và cỡ chữ của [variant].
Widget goldenHost(GoldenVariant variant, Widget child) {
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: variant.theme,
    darkTheme: variant.theme,
    themeMode: ThemeMode.dark,
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
