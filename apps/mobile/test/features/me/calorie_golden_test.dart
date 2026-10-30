@Tags(['golden'])
library;

import 'dart:async';

import 'package:domain/domain.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/app/app.dart';
import 'package:mobile/app/strings_vi.dart';
import 'package:mobile/data/db/app_database.dart';
import 'package:mobile/features/me/data/account_repository.dart';
import 'package:mobile/features/me/data/profile_repository.dart';
import 'package:mobile/features/me/presentation/calorie_proposal_sheet.dart';
import 'package:mobile/features/weight/data/weight_repository.dart';
import 'package:mobile/ui/components/ironly_tab_bar.dart';

import '../../support/app_harness.dart';
import '../../support/fake_server.dart';
import '../../support/golden.dart';
import '../../support/schedule_fixture.dart';

void main() {
  /// Mock S-51-1, S-52-1, S-53-1: nam 1996, 175 cm, vận động vừa, cân mới
  /// nhất 72,5 kg; Bạn tự đặt 1.900 kcal, đề xuất 2.090 kcal do cân nặng.
  Future<AppDatabase> seed({bool pending = true}) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await AccountRepository(db).put('Minh');
    final p = completedProfile(mode: CalorieMode.manual, kcal: 1900);
    await ProfileRepository(
      db,
    ).put(pending ? p.withPending(2090, CaloriePendingReason.weight) : p);
    final weights = WeightRepository(db);
    await weights.put(LocalDate(2026, 9, 28), 729);
    await weights.put(LocalDate(2026, 10, 5), 725);
    return db;
  }

  Future<void> pump(
    WidgetTester tester,
    GoldenVariant variant,
    AppDatabase db,
    String tab,
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
        clock: FixedClock(DateTime(2026, 10, 8, 9)),
        server: FakeServer(),
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

  Future<void> tapKey(WidgetTester tester, String key) async {
    final f = find.byKey(ValueKey(key));
    await tester.ensureVisible(f);
    await tester.pumpAndSettle();
    await tester.tap(f);
    await tester.pumpAndSettle();
  }

  Future<void> snap(String name) => expectLater(
    find.byType(MaterialApp),
    matchesGoldenFile('goldens/$name.png'),
  );

  for (final v in GoldenVariant.all) {
    testWidgets('S-50 Tôi: dòng hồ sơ, mức calo có chấm ${v.name}', (
      tester,
    ) async {
      await pump(tester, v, await seed(), S.tabMe);
      await snap('s50_calorie_${v.name}');
    });

    testWidgets('S-51 hồ sơ cơ thể (mock S-51-1) ${v.name}', (tester) async {
      await pump(tester, v, await seed(pending: false), S.tabMe);
      await tapKey(tester, 'row-profile');
      await snap('s51_${v.name}');
    });

    testWidgets('S-52 Bạn tự đặt, có đề xuất mới (mock S-52-1) ${v.name}', (
      tester,
    ) async {
      await pump(tester, v, await seed(), S.tabMe);
      await tapKey(tester, 'row-calorie');
      await snap('s52_${v.name}');
    });

    testWidgets('S-53 đề xuất sau khi ghi cân (mock S-53-1) ${v.name}', (
      tester,
    ) async {
      await pump(tester, v, await seed(), S.tabWeight);
      unawaited(
        showCalorieProposalSheet(tester.element(find.byType(IronlyTabBar))),
      );
      await tester.pumpAndSettle();
      await snap('s53_${v.name}');
    });
  }
}
