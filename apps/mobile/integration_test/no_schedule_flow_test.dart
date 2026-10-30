// Integration test VS-25 trên iOS simulator (06 Bản 2 VS25-T10): "Để sau" ở
// bước lịch tuần, thoát app ở bước 5 → mở lại đúng bước 5 (F03-E21); hoàn tất
// → Chưa có lịch; xếp lịch tuần lần đầu từ mục Lịch → đồng bộ với server thật
// (server chỉ nhận lịch tháng sau khi đã có lịch tuần, VS25-T04).
import 'package:domain/testing.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mobile/app/providers.dart';
import 'package:mobile/app/strings_vi.dart';
import 'package:mobile/main.dart' as app;

import 'flow_helpers.dart';

final clock = ShiftedClock(Duration.zero);

Future<void> launch() =>
    app.runIronlyApp(overrides: [clockProvider.overrideWithValue(clock)]);

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('UX-AC24: đăng ký → bước 1 → 3 → bước 4 "Để sau" → bước 5 câu '
      'ví dụ chung; thoát app ở bước 5', (tester) async {
    // Gỡ app không xóa Keychain: phiên của file test trước còn đó.
    await const FlutterSecureStorage().deleteAll();
    await launch();
    await pumpUntil(tester, find.widgetWithText(OutlinedButton, S.login));
    await tester.tap(find.widgetWithText(FilledButton, S.register));
    await tester.pumpAndSettle();
    await enter(tester, S.fieldDisplayName, 'Lan');
    await enter(tester, S.fieldPhone, '0955555555');
    final password = randomTestPassword();
    await enter(tester, S.fieldPassword, password);
    await enter(tester, S.fieldPasswordConfirm, password);
    await reveal(tester, find.widgetWithText(FilledButton, S.register));
    await tester.tap(find.widgetWithText(FilledButton, S.register));
    await pumpUntil(tester, find.text(S.disclaimerTitle));
    await tester.tap(find.text(S.iUnderstand));
    await pumpUntil(tester, find.text(S.profileTitle));
    await enter(tester, S.fieldHeight, '160');
    await tapVisible(tester, find.byKey(const ValueKey('birth-year-field')));
    await tester.tap(find.text(S.done));
    await tester.pumpAndSettle();
    await tapVisible(tester, find.byKey(const ValueKey('sex-female')));
    await tapVisible(tester, find.byKey(const ValueKey('activity-moderate')));
    await enter(tester, S.fieldInitialWeight, '55');
    await tester.tap(find.widgetWithText(FilledButton, S.continueLabel));
    await pumpUntil(tester, find.text(S.calorieTitle));
    await tester.tap(find.widgetWithText(FilledButton, S.keepThisLevel));
    await pumpUntil(tester, find.text(S.stepOf(4)));

    await tapVisible(tester, find.byKey(const ValueKey('day-switch-1')));
    await tapVisible(tester, find.byKey(const ValueKey('schedule-later')));
    await pumpUntil(tester, find.text(S.stepOf(5)));
    expect(find.text(S.remindersStartWhenScheduled), findsOneWidget);
    // Thoát app ở bước 5; test sau mở lại.
  });

  testWidgets('F03-E21: mở lại → đúng bước 5; "Để sau" → Hôm nay "Chưa có '
      'lịch tập"; mục Lịch "Xếp lịch tuần" → lưu lần đầu → lịch tháng, đồng bộ '
      'với server', (tester) async {
    await tester.pumpWidget(const SizedBox());
    await launch();
    await pumpUntil(tester, find.text(S.stepOf(5)));
    expect(find.text(S.remindersStartWhenScheduled), findsOneWidget);
    await tester.tap(find.widgetWithText(OutlinedButton, S.later));
    await pumpUntil(tester, tabLabel(S.tabToday));
    expect(find.byKey(const ValueKey('no-schedule-card')), findsOneWidget);
    expect(find.byKey(const ValueKey('week-card')), findsNothing);

    await tester.tap(tabLabel(S.tabTraining));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('no-schedule')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('arrange-weekly')));
    await tester.pumpAndSettle();
    for (var w = DateTime.monday; w <= DateTime.saturday; w++) {
      await tapVisible(tester, find.byKey(ValueKey('day-switch-$w')));
      await tapVisible(tester, find.byKey(ValueKey('day-time-$w')));
      await tester.tap(find.text(S.done));
      await tester.pumpAndSettle();
      await tapVisible(tester, find.byKey(const ValueKey('muscle-back')));
    }
    await tapVisible(tester, find.widgetWithText(FilledButton, S.save));
    await pumpUntil(tester, find.text(S.templateSaved));
    expect(find.byKey(const ValueKey('no-schedule')), findsNothing);
    expect(find.byKey(const ValueKey('redistribute-banner')), findsNothing);

    // Đồng bộ: server nhận lịch tuần rồi lịch tháng, không bị từ chối.
    await tester.tap(tabLabel(S.tabToday));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('no-schedule-card')), findsNothing);
    // Bản 4: buổi hôm nay = hàng số liệu + danh sách bài ngay ở Hôm nay.
    await pumpUntil(tester, find.byKey(const ValueKey('session-stats')));
    await tester.tap(tabLabel(S.tabMe));
    await tester.pumpAndSettle();
    await pumpUntilGone(tester, find.text(S.syncPending));
  });
}
