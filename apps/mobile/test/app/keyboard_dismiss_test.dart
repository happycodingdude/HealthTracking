import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/app/app.dart';

/// Bàn phím số của iPhone không có phím Xong: chạm ra ngoài ô nhập phải đóng
/// bàn phím, nếu không Bạn kẹt ở màn đang nhập.
void main() {
  Widget host({Map<Type, Action<Intent>>? actions}) => MaterialApp(
    actions: actions,
    home: const Scaffold(
      body: Column(
        children: [
          TextField(
            key: ValueKey('field'),
            keyboardType: TextInputType.numberWithOptions(decimal: true),
          ),
          SizedBox(height: 400),
        ],
      ),
    ),
  );

  Future<void> tapFieldThenOutside(WidgetTester tester) async {
    await tester.tap(find.byKey(const ValueKey('field')));
    await tester.pump();
    expect(tester.testTextInput.isVisible, isTrue);
    await tester.tapAt(const Offset(200, 300));
    await tester.pump();
  }

  testWidgets('chạm ra ngoài ô nhập thì bàn phím đóng', (tester) async {
    await tester.pumpWidget(host(actions: IronlyApp.actions));
    await tapFieldThenOutside(tester);
    expect(tester.testTextInput.isVisible, isFalse);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets('mặc định của Flutter trên iPhone: bàn phím vẫn mở', (
    tester,
  ) async {
    await tester.pumpWidget(host());
    await tapFieldThenOutside(tester);
    expect(tester.testTextInput.isVisible, isTrue);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));
}
