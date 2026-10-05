// Integration test trên iOS simulator (ED-10): chạy bằng tool/integration_test.sh
// với server và PostgreSQL thật.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mobile/app/shell/app_tab_bar.dart';
import 'package:mobile/app/strings_vi.dart';
import 'package:mobile/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Finder tabLabel(String label) =>
      find.descendant(of: find.byType(AppTabBar), matching: find.text(label));

  /// Chờ [finder] xuất hiện (khởi động app, gọi mạng thật).
  Future<void> pumpUntil(WidgetTester tester, Finder finder) async {
    for (var i = 0; i < 200; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      if (finder.evaluate().isNotEmpty) return;
    }
    fail('Không thấy $finder sau 20 giây');
  }

  testWidgets(
    'UX-AC1: app thật mở vào khung 5 tab; tab Tôi (dev) gọi được /healthz',
    (tester) async {
      await app.main();
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

      for (final label in [S.tabSchedule, S.tabMenu, S.tabWeight]) {
        await tester.tap(tabLabel(label));
        await tester.pumpAndSettle();
        expect(find.text(label), findsNWidgets(2), reason: label);
      }
      await tester.tap(find.byKey(const ValueKey('tab-today-button')));
      await tester.pumpAndSettle();
      expect(find.text(S.tabToday), findsNWidgets(2));

      await tester.tap(tabLabel(S.tabMe));
      await tester.pumpAndSettle();
      await pumpUntil(tester, find.textContaining('Dev server: OK'));
    },
  );
}
