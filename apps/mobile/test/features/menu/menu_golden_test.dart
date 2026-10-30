@Tags(['golden'])
library;

import 'package:api_contract/api_contract.dart';
import 'package:domain/domain.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/app/app.dart';
import 'package:mobile/app/strings_vi.dart';
import 'package:mobile/data/db/app_database.dart';
import 'package:mobile/features/menu/data/menu_repository.dart';
import 'package:mobile/ui/components/ironly_tab_bar.dart';

import '../../support/app_harness.dart';
import '../../support/fake_server.dart';
import '../../support/fake_sync.dart';
import '../../support/golden.dart';
import '../../support/menu_fixture.dart';
import '../../support/schedule_fixture.dart';

void main() {
  final today = LocalDate(2026, 10, 7);

  /// Mock S-30: thứ 4 07/10, Tự động 2.090 kcal (72,5 kg).
  Future<AppDatabase> seed({
    MenuData? menu,
    int used = 0,
    WeeklyTemplate? template,
  }) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await seedSetUp(
      db,
      profile: completedProfile(kcal: 2090),
      template: template,
    );
    await db.customStatement(
      "UPDATE weights SET weight_kg_x10 = 725 WHERE week_start = '2026-10-05'",
    );
    final repo = MenuRepository(db);
    if (menu != null) await repo.put(today, menu);
    if (used > 0) await repo.putUsage(AiDailyUsageCodec.key(today), used);
    return db;
  }

  Future<void> pump(
    WidgetTester tester,
    GoldenVariant variant,
    AppDatabase db, {
    String tab = S.tabMenu,
    FakeConnectivity? connectivity,
  }) async {
    setPhoneSurface(tester);
    applyVariant(tester, variant);
    final container = ProviderContainer(
      retry: (_, _) => null,
      overrides: appOverrides(
        db: db,
        clock: FixedClock(DateTime(2026, 10, 7, 9)),
        server: FakeServer(),
        scheduler: FakeScheduler(),
        connectivity: connectivity,
      ),
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const IronlyApp()),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(of: find.byType(IronlyTabBar), matching: find.text(tab)),
    );
    await tester.pumpAndSettle();
  }

  Future<void> snap(String name) => expectLater(
    find.byType(MaterialApp),
    matchesGoldenFile('goldens/$name.png'),
  );

  final menu = readyMenu(targetKcal: 2090);

  for (final v in GoldenVariant.all) {
    testWidgets('S-30 trống (mock S-30-1) ${v.name}', (tester) async {
      await pump(tester, v, await seed());
      await snap('s30_empty_${v.name}');
    });

    testWidgets('S-30 đang tạo (mock S-30-2) ${v.name}', (tester) async {
      await pump(
        tester,
        v,
        await seed(
          menu: const MenuData(
            payload: null,
            targetKcal: 2090,
            usedSafetyFloor: false,
            totalKcal: null,
            lastAttemptStatus: MenuAttemptStatus.generating,
          ),
        ),
      );
      await snap('s30_generating_${v.name}');
    });

    testWidgets('S-30 có thực đơn (mock S-30-3) ${v.name}', (tester) async {
      await pump(tester, v, await seed(menu: menu, used: 1));
      await snap('s30_menu_${v.name}');
    });

    testWidgets('S-30 hộp xác nhận gợi ý lại (mock S-30-4) ${v.name}', (
      tester,
    ) async {
      await pump(tester, v, await seed(menu: menu, used: 1));
      final button = find.byKey(const ValueKey('regenerate'));
      await tester.scrollUntilVisible(
        button,
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(button);
      await tester.pumpAndSettle();
      await snap('s30_regenerate_${v.name}');
    });

    testWidgets('S-30 không có mạng (mock S-30-5) ${v.name}', (tester) async {
      await pump(
        tester,
        v,
        await seed(),
        connectivity: FakeConnectivity()..online = false,
      );
      final button = find.byKey(const ValueKey('generate-menu'));
      await tester.ensureVisible(button);
      await tester.pumpAndSettle();
      await tester.tap(button);
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('menu-banner-offline')),
        -300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await snap('s30_offline_${v.name}');
    });

    testWidgets('S-10 thẻ thực đơn có thực đơn (04 §6.7.4, UR-15) ${v.name}', (
      tester,
    ) async {
      // Bản 4 (04 S-10 H2): thẻ đầy đủ chỉ ở ngày không có buổi.
      await pump(
        tester,
        v,
        await seed(menu: menu, used: 1, template: templateRestWed),
        tab: S.tabToday,
      );
      final card = find.byKey(const ValueKey('menu-card'));
      await tester.scrollUntilVisible(
        card,
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await snap('s10_menu_${v.name}');
    });
  }
}
