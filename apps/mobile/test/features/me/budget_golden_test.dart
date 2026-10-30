@Tags(['golden'])
library;

import 'dart:convert';

import 'package:api_contract/api_contract.dart';
import 'package:domain/domain.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/app/app.dart';
import 'package:mobile/app/router.dart';
import 'package:mobile/data/db/app_database.dart';
import 'package:mobile/features/me/presentation/budget_screen.dart';

import '../../support/app_harness.dart';
import '../../support/fake_server.dart';
import '../../support/golden.dart';
import '../../support/schedule_fixture.dart';

void main() {
  /// Mock S-54-1: đã dùng 12.500đ tháng 10.
  Future<AppDatabase> seed(num used, {bool blocked = false}) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await seedSetUp(db);
    await (db.update(db.syncState)..where((s) => s.id.equals(1))).write(
      SyncStateCompanion(
        aiBudget: Value(
          jsonEncode(
            AiBudgetMeta(
              month: YearMonth(2026, 10),
              usedVnd: used,
              capVnd: 50000,
              blocked: blocked,
            ).toJson(),
          ),
        ),
      ),
    );
    return db;
  }

  Future<void> pump(
    WidgetTester tester,
    GoldenVariant variant,
    AppDatabase db,
  ) async {
    setPhoneSurface(tester);
    tester.platformDispatcher
      ..platformBrightnessTestValue = variant.brightness
      ..textScaleFactorTestValue = variant.textScale;
    addTearDown(tester.platformDispatcher.clearAllTestValues);
    final container = ProviderContainer(
      retry: (_, _) => null,
      overrides: appOverrides(
        db: db,
        clock: FixedClock(DateTime(2026, 10, 7, 9)),
        server: FakeServer(),
      ),
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const IronlyApp()),
    );
    await tester.pumpAndSettle();
    // Mở S-54 thẳng bằng router (cỡ chữ lớn: dòng ở S-50 nằm ngoài khung).
    container.read(routerProvider).go(budgetPath);
    await tester.pumpAndSettle();
  }

  Future<void> snap(String name) => expectLater(
    find.byType(MaterialApp),
    matchesGoldenFile('goldens/$name.png'),
  );

  for (final v in GoldenVariant.all) {
    testWidgets('S-54 ngân sách AI (mock S-54-1) ${v.name}', (tester) async {
      await pump(tester, v, await seed(12500));
      await snap('s54_${v.name}');
    });

    testWidgets('S-54 đã chạm trần (màu cảnh báo, F08-E2) ${v.name}', (
      tester,
    ) async {
      await pump(tester, v, await seed(49700, blocked: true));
      await snap('s54_blocked_${v.name}');
    });
  }
}
