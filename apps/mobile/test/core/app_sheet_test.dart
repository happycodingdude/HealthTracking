import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/app/theme.dart';
import 'package:mobile/core/widgets/app_sheet.dart';

void main() {
  Future<void> pumpHost(
    WidgetTester tester,
    void Function(BuildContext) open,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: IronlyTheme.dark(),
        home: Builder(
          builder: (context) => Scaffold(
            body: Column(
              children: [
                const Text('Nội dung phía sau'),
                ElevatedButton(
                  onPressed: () => open(context),
                  child: const Text('mở'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('mở'));
    await tester.pumpAndSettle();
  }

  Color? scrimColor(WidgetTester tester) {
    final barriers = tester
        .widgetList<ModalBarrier>(find.byType(ModalBarrier))
        .toList();
    return barriers.last.color;
  }

  testWidgets('UR-16/UX-AC23: bảng trượt giữ trang phía sau, chỉ phủ lớp mờ', (
    tester,
  ) async {
    await pumpHost(
      tester,
      (c) => showAppSheet<void>(c, builder: (_) => const Text('Trong bảng')),
    );
    expect(find.text('Trong bảng'), findsOneWidget);
    expect(find.text('Nội dung phía sau'), findsOneWidget);
    expect(scrimColor(tester), TokenColor.scrim);
    expect(TokenColor.scrim.a, inExclusiveRange(0, 1));
    // Chạm vùng mờ để đóng.
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    expect(find.text('Trong bảng'), findsNothing);
  });

  testWidgets('UR-16/UX-AC23: hộp thoại giữ trang phía sau, chỉ phủ lớp mờ', (
    tester,
  ) async {
    await pumpHost(
      tester,
      (c) => showAppDialog<void>(
        c,
        builder: (_) => const AlertDialog(content: Text('Hộp')),
      ),
    );
    expect(find.text('Hộp'), findsOneWidget);
    expect(find.text('Nội dung phía sau'), findsOneWidget);
    expect(scrimColor(tester), TokenColor.scrim);
  });
}
