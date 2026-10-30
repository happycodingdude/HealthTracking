import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/ui/components/components.dart';
import 'package:mobile/ui/theme.dart';

/// UR-16 / UX-AC23: bảng trượt và hộp thoại Bản 4 (`ironly_sheet.dart`) giữ
/// trang phía sau, chỉ phủ lớp mờ `TokenColor.scrim`.
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
      (c) => showIronlySheet<void>(
        c,
        builder: (_) => const IronlySheet(children: [Text('Trong bảng')]),
      ),
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
      (c) => showIronlyDialog<void>(
        c,
        builder: (_) => const IronlyDialog(title: 'Hộp', primaryLabel: 'OK'),
      ),
    );
    expect(find.text('Hộp'), findsOneWidget);
    expect(find.text('Nội dung phía sau'), findsOneWidget);
    expect(scrimColor(tester), TokenColor.scrim);
  });
}
