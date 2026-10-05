// Integration test trên iOS simulator (ED-10): chạy bằng tool/integration_test.sh
// với server và PostgreSQL thật, app cài mới và Keychain trống.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mobile/app/shell/app_tab_bar.dart';
import 'package:mobile/app/strings_vi.dart';
import 'package:mobile/core/widgets/labeled_field.dart';
import 'package:mobile/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Finder tabLabel(String label) =>
      find.descendant(of: find.byType(AppTabBar), matching: find.text(label));
  Finder input(String label) => find.descendant(
    of: find.byWidgetPredicate((w) => w is LabeledField && w.label == label),
    matching: find.byType(TextField),
  );

  /// Cuộn tới [finder] như người dùng (danh sách chỉ dựng phần đang thấy, bàn
  /// phím che bớt màn hình).
  Future<void> reveal(WidgetTester tester, Finder finder) =>
      tester.scrollUntilVisible(
        finder,
        80,
        scrollable: find.byType(Scrollable).first,
      );

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

  testWidgets(
    'TAC-15, VS01-T10, UX-AC1: đăng nhập sai 6 lần → câu chung; đăng ký → '
    'S-02 → khung 5 tab; tab Tôi (dev) gọi được /healthz; VS-02: đổi tên → '
    'đồng bộ với server, Hôm nay chào tên mới',
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

      // VS01-T10: đăng ký thành công → S-02.
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

      // Bản dev: bỏ qua S-02 để vào khung tab (gỡ ở VS-03).
      await tester.tap(find.byKey(const ValueKey('dev-skip-onboarding')));
      await pumpUntil(tester, find.byType(AppTabBar));
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
