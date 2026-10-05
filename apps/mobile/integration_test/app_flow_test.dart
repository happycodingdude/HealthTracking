// Integration test trên iOS simulator (ED-10): chạy bằng tool/integration_test.sh
// với server và PostgreSQL thật, app cài mới và Keychain trống.
//
// `flutter test` gỡ app sau mỗi file, nên "mở lại app" (UX-AC3) được làm trong
// cùng file: test sau gọi lại `app.main()`, đọc database và Keychain đã lưu.
import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mobile/app/shell/app_tab_bar.dart';
import 'package:mobile/app/strings_vi.dart';
import 'package:mobile/core/formatters.dart';
import 'package:mobile/main.dart' as app;

import 'flow_helpers.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'TAC-15, VS01-T10: đăng nhập sai 6 lần → câu chung; đăng ký → S-02. '
    'VS-03: S-02 → S-03 → S-04, thoát app ở bước 3',
    (tester) async {
      await app.main();
      await pumpUntil(tester, find.widgetWithText(OutlinedButton, S.login));

      // TAC-15: lần sai thứ 6 bị server chặn nhưng vẫn là câu chung.
      await tester.tap(find.widgetWithText(OutlinedButton, S.login));
      await tester.pumpAndSettle();
      await enter(tester, S.fieldPhone, '0912345678');
      await enter(tester, S.fieldPassword, 'saimatkhau');
      for (var attempt = 1; attempt <= 6; attempt++) {
        await reveal(tester, find.widgetWithText(FilledButton, S.login));
        await tester.tap(find.widgetWithText(FilledButton, S.login));
        await pumpUntil(tester, find.text(S.errorInvalidCredentials));
        expect(
          find.text(S.errorInvalidCredentials),
          findsOneWidget,
          reason: 'lần $attempt',
        );
      }

      // VS01-T10: đăng ký thành công → S-02 (Bước 1/5), không có thanh tab.
      await tester.tap(find.text(S.back));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, S.register));
      await tester.pumpAndSettle();
      await enter(tester, S.fieldDisplayName, 'Minh');
      await enter(tester, S.fieldPhone, '0912345678');
      await enter(tester, S.fieldPassword, 'matkhau123');
      await enter(tester, S.fieldPasswordConfirm, 'matkhau123');
      await reveal(tester, find.widgetWithText(FilledButton, S.register));
      await tester.tap(find.widgetWithText(FilledButton, S.register));
      await pumpUntil(tester, find.text(S.disclaimerTitle));
      expect(find.text(S.stepOf(1)), findsOneWidget);
      expect(find.byType(AppTabBar), findsNothing);

      // VS-03: S-02 → S-03 (hồ sơ F02-AC1) → S-04.
      await tester.tap(find.text(S.iUnderstand));
      await pumpUntil(tester, find.text(S.profileTitle));
      await enter(tester, S.fieldHeight, '175');
      await tapVisible(tester, find.byKey(const ValueKey('birth-year-field')));
      await tester.tap(find.text(S.done)); // mặc định 30 tuổi
      await tester.pumpAndSettle();
      await tapVisible(tester, find.byKey(const ValueKey('sex-male')));
      await tapVisible(tester, find.byKey(const ValueKey('activity-moderate')));
      await enter(tester, S.fieldInitialWeight, '80');
      await tester.tap(find.widgetWithText(FilledButton, S.continueLabel));
      await pumpUntil(tester, find.text(S.calorieTitle));
      expect(find.text(S.stepOf(3)), findsOneWidget);
      expect(find.text(S.calorieAuto), findsOneWidget);
      // Thoát app ở bước 3; test sau mở lại.
    },
  );

  testWidgets(
    'UX-AC3: mở lại app → đúng bước 3, thông tin còn nguyên. Giữ mức → VS-04: '
    'xếp lịch tuần → VS-05: bước 5 "Để sau" → khung 5 tab (UX-AC1), lịch tháng; tab '
    'Tôi gọi được /healthz; VS-02: đổi tên → đồng bộ với server, Hôm nay chào '
    'tên mới',
    (tester) async {
      // Mở lại app: dựng từ đầu, đọc trạng thái đã lưu trên máy.
      await tester.pumpWidget(const SizedBox());
      await app.main();
      await pumpUntil(tester, find.text(S.calorieTitle));
      expect(find.text(S.stepOf(3)), findsOneWidget);
      final kcal = CalorieRules.estimate(
        heightCm: 175,
        weightKgX10: 800,
        age: ProfileRules.age(1996, DateTime.now().year),
        sex: Sex.male,
        activity: ActivityLevel.moderate,
      ).kcal;
      expect(find.text(Fmt.kcal(kcal), findRichText: true), findsOneWidget);

      await tester.tap(find.widgetWithText(FilledButton, S.keepThisLevel));
      await pumpUntil(tester, find.text(S.stepOf(4)));

      // VS-04: S-05 xếp lịch thứ 2 → thứ 7 đều tập Ngực (giờ mặc định 18:00),
      // lưu → app chia lịch tháng → bước 5.
      expect(find.byKey(const ValueKey('day-switch-7')), findsNothing);
      for (var w = DateTime.monday; w <= DateTime.saturday; w++) {
        await tapVisible(tester, find.byKey(ValueKey('day-switch-$w')));
        await tapVisible(tester, find.byKey(ValueKey('day-time-$w')));
        await tester.tap(find.text(S.done));
        await tester.pumpAndSettle();
        await tapVisible(tester, find.byKey(const ValueKey('muscle-chest')));
      }
      await tester.tap(find.widgetWithText(FilledButton, S.saveSchedule));
      await pumpUntil(tester, find.text(S.stepOf(5)));

      // VS-05: S-06 có ví dụ thật từ lịch; "Để sau" (simulator không bấm được
      // hộp xin quyền của iOS) → hoàn tất thiết lập → Hôm nay (OB-4, NAV-1).
      expect(find.byKey(const ValueKey('reminder-preview')), findsOneWidget);
      await tester.tap(find.widgetWithText(OutlinedButton, S.later));
      await pumpUntil(tester, tabLabel(S.tabToday));
      for (final label in [
        S.tabSchedule,
        S.tabMenu,
        S.tabToday,
        S.tabWeight,
        S.tabMe,
      ]) {
        expect(tabLabel(label), findsOneWidget, reason: label);
      }
      expect(find.byKey(const ValueKey('tab-today-button')), findsOneWidget);

      // S-20: tháng hiện tại, bắt đầu từ hôm nay (F03-R5).
      final now = DateTime.now();
      await tester.tap(tabLabel(S.tabSchedule));
      await tester.pumpAndSettle();
      expect(find.text(S.monthTitle(now.month, now.year)), findsOneWidget);
      expect(
        find.text(Fmt.shortWeekdayDate(LocalDate.fromDateTime(now))),
        findsOneWidget,
      );

      await tester.tap(tabLabel(S.tabMe));
      await tester.pumpAndSettle();
      await pumpUntil(tester, find.textContaining('Dev server: OK'));

      // VS-02: đổi tên ở S-56 → hiện ngay, đồng bộ với server thật; Hôm nay
      // chào bằng tên mới (UA-21, UX-AC22).
      await tester.tap(find.byKey(const ValueKey('row-account-data')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('row-display-name')));
      await tester.pumpAndSettle();
      await tester.enterText(input(S.fieldDisplayName), 'Minh Anh');
      await tester.tap(find.widgetWithText(FilledButton, S.save));
      await tester.pumpAndSettle();
      expect(find.text('Minh Anh'), findsOneWidget);
      await pumpUntil(tester, find.textContaining(S.syncedAt('')));
      expect(find.text(S.syncLossWarning), findsNothing);

      await tester.tap(find.byIcon(Icons.chevron_left));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('tab-today-button')));
      await tester.pumpAndSettle();
      expect(find.textContaining(S.greeting('Minh Anh')), findsOneWidget);
      expect(find.byKey(const ValueKey('sync-indicator')), findsNothing);
    },
  );
}
