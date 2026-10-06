// Tiện ích dùng chung cho integration test trên simulator (ED-10).
import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/app/shell/app_tab_bar.dart';
import 'package:mobile/core/widgets/labeled_field.dart';

Finder tabLabel(String label) =>
    find.descendant(of: find.byType(AppTabBar), matching: find.text(label));

Finder input(String label) => find.descendant(
  of: find.byWidgetPredicate((w) => w is LabeledField && w.label == label),
  matching: find.byType(TextField),
);

/// Cuộn tới [finder] như người dùng (danh sách chỉ dựng phần đang thấy, bàn
/// phím che bớt màn hình).
Future<void> reveal(WidgetTester tester, Finder finder) => tester
    .scrollUntilVisible(finder, 80, scrollable: find.byType(Scrollable).first);

Future<void> enter(WidgetTester tester, String label, String text) async {
  await reveal(tester, input(label));
  await tester.enterText(input(label), text);
}

/// Chờ [finder] xuất hiện (khởi động app, gọi mạng thật) và hiệu ứng chuyển
/// màn hình chạy xong.
Future<void> pumpUntil(WidgetTester tester, Finder finder) async {
  for (var i = 0; i < 200; i++) {
    await tester.pump(const Duration(milliseconds: 100));
    if (finder.evaluate().isNotEmpty) {
      await tester.pumpAndSettle();
      return;
    }
  }
  fail('Không thấy $finder sau 20 giây');
}

/// Chạm [finder] sau khi cuộn tới nó.
Future<void> tapVisible(WidgetTester tester, Finder finder) async {
  await reveal(tester, finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

/// Chờ [finder] biến mất (ví dụ chỉ báo "Chưa đồng bộ" sau khi đồng bộ xong).
Future<void> pumpUntilGone(WidgetTester tester, Finder finder) async {
  for (var i = 0; i < 200; i++) {
    await tester.pump(const Duration(milliseconds: 100));
    if (finder.evaluate().isEmpty) return;
  }
  fail('$finder vẫn còn sau 20 giây');
}

/// Giờ của app = giờ thật lùi lại [offset]. App luôn ở quá khứ nên server
/// không từ chối `clientUpdatedAt` (lệch quá 10 phút về tương lai, 05 §6.6.2)
/// mà test vẫn chọn được giờ trong ngày, ví dụ trước và sau giờ tập.
final class ShiftedClock implements Clock {
  ShiftedClock(this.offset);

  Duration offset;

  @override
  DateTime now() => DateTime.now().subtract(offset);

  /// Đặt giờ của app thành [at] (phải ở quá khứ so với giờ thật).
  void setNow(DateTime at) => offset = DateTime.now().difference(at);
}
