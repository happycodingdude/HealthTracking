@Tags(['golden'])
library;

import 'package:domain/domain.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/app/app.dart';
import 'package:mobile/app/shell/app_tab_bar.dart';
import 'package:mobile/app/strings_vi.dart';
import 'package:mobile/data/db/app_database.dart';
import 'package:mobile/features/me/data/account_repository.dart';
import 'package:mobile/features/me/data/profile_repository.dart';
import 'package:mobile/features/onboarding/application/setup_state.dart';

import '../../support/app_harness.dart';
import '../../support/fake_notifications.dart';
import '../../support/golden.dart';

/// Golden VS-25: trạng thái Chưa có lịch (mock S-05-1, S-06-1, S-10-1, S-20-1,
/// S-50-1 Bản 2).
void main() {
  final now = DateTime(2026, 10, 7, 9);
  final base = Profile(
    onboardingStep: 4,
    disclaimerAcceptedAt: DateTime(2026, 10, 7, 8, 50),
    heightCm: 175,
    birthYear: 1996,
    sex: Sex.male,
    activityLevel: ActivityLevel.moderate,
    calorieMode: CalorieMode.auto,
    calorieKcal: 2210,
  );
  final completed = base.copyWith(
    onboardingStep: 5,
    remindersEnabled: true,
    setupDate: LocalDate(2026, 10, 7),
    onboardingCompletedAt: now,
  );

  Future<void> pump(
    WidgetTester tester,
    GoldenVariant variant,
    Profile p, {
    bool onboarded = false,
  }) async {
    setPhoneSurface(tester);
    tester.platformDispatcher
      ..platformBrightnessTestValue = variant.brightness
      ..textScaleFactorTestValue = variant.textScale;
    addTearDown(tester.platformDispatcher.clearAllTestValues);
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await AccountRepository(db).put('Minh');
    await ProfileRepository(db).put(p);
    final container = ProviderContainer(
      retry: (_, _) => null,
      overrides: appOverrides(
        db: db,
        clock: FixedClock(now),
        onboarded: onboarded,
        notifications: FakeNotificationGateway(),
        initialSetup: SetupState.of(p),
      ),
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const IronlyApp()),
    );
    await tester.pumpAndSettle();
  }

  Future<void> snap(String name) => expectLater(
    find.byType(MaterialApp),
    matchesGoldenFile('goldens/$name.png'),
  );

  Future<void> tab(WidgetTester tester, String label) async {
    await tester.tap(
      find.descendant(of: find.byType(AppTabBar), matching: find.text(label)),
    );
    await tester.pumpAndSettle();
  }

  for (final v in GoldenVariant.all) {
    testWidgets(
      'S-06 câu ví dụ chung khi đã "Để sau" (mock S-06-1) ${v.name}',
      (tester) async {
        await pump(tester, v, base.copyWith(onboardingStep: 5));
        await snap('s06_no_schedule_${v.name}');
      },
    );

    testWidgets('S-10 chưa có lịch (mock S-10-1) ${v.name}', (tester) async {
      await pump(tester, v, completed, onboarded: true);
      await snap('s10_no_schedule_${v.name}');
    });

    testWidgets('S-20 chưa có lịch (mock S-20-1) ${v.name}', (tester) async {
      await pump(tester, v, completed, onboarded: true);
      await tab(tester, S.tabTraining);
      await snap('s20_no_schedule_${v.name}');
    });

    testWidgets('S-50 công tắc nhắc khi chưa có lịch (mock S-50-1) ${v.name}', (
      tester,
    ) async {
      await pump(tester, v, completed, onboarded: true);
      await tab(tester, S.tabMe);
      await snap('s50_no_schedule_${v.name}');
    });
  }
}
