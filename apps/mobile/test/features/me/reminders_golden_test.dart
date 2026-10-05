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
import 'package:mobile/features/me/data/profile_repository.dart';
import 'package:mobile/features/onboarding/application/setup_state.dart';
import 'package:mobile/features/schedule/data/schedule_repository.dart';

import '../../support/app_harness.dart';
import '../../support/fake_notifications.dart';
import '../../support/golden.dart';

void main() {
  final monday = DateTime(2026, 10, 5, 8);
  final template = WeeklyTemplate({
    1: TemplateDay(
      enabled: true,
      time: LocalTime(18, 0),
      muscles: const [MuscleGroup.chest, MuscleGroup.triceps],
    ),
  });
  final profile = Profile(
    onboardingStep: 5,
    disclaimerAcceptedAt: DateTime(2026, 10, 4, 21),
    heightCm: 175,
    birthYear: 1996,
    sex: Sex.male,
    activityLevel: ActivityLevel.moderate,
    calorieMode: CalorieMode.auto,
    calorieKcal: 2210,
  );

  Future<void> pump(
    WidgetTester tester,
    GoldenVariant variant,
    Profile p, {
    required bool permitted,
    bool onboarded = false,
  }) async {
    setPhoneSurface(tester);
    tester.platformDispatcher
      ..platformBrightnessTestValue = variant.brightness
      ..textScaleFactorTestValue = variant.textScale;
    addTearDown(tester.platformDispatcher.clearAllTestValues);
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await ProfileRepository(db).put(p);
    final schedule = ScheduleRepository(db);
    await schedule.putTemplate(template);
    final g = MonthGenerator.first(template, monday);
    await schedule.putPlan(g.plan);
    for (final d in g.days) {
      await schedule.putDay(d);
    }
    final container = ProviderContainer(
      retry: (_, _) => null,
      overrides: appOverrides(
        db: db,
        clock: FixedClock(monday),
        onboarded: onboarded,
        notifications: FakeNotificationGateway(permitted: permitted),
        initialSetup: SetupState.of(p),
      ),
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const HealthApp()),
    );
    await tester.pumpAndSettle();
  }

  Future<void> snap(String name) => expectLater(
    find.byType(MaterialApp),
    matchesGoldenFile('goldens/$name.png'),
  );

  for (final v in GoldenVariant.all) {
    testWidgets('S-06 Nhắc đi tập ${v.name}', (tester) async {
      await pump(tester, v, profile, permitted: true);
      await snap('s06_${v.name}');
    });

    testWidgets('S-50 nhắc bật, iPhone chặn thông báo (F04-E2) ${v.name}', (
      tester,
    ) async {
      await pump(
        tester,
        v,
        profile.copyWith(
          remindersEnabled: true,
          setupDate: LocalDate(2026, 10, 5),
          onboardingCompletedAt: monday,
        ),
        permitted: false,
        onboarded: true,
      );
      await tester.tap(
        find.descendant(
          of: find.byType(AppTabBar),
          matching: find.text(S.tabMe),
        ),
      );
      await tester.pumpAndSettle();
      await snap('s50_blocked_${v.name}');
    });
  }
}
