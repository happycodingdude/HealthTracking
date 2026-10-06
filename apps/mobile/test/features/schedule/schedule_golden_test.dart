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
import 'package:mobile/features/onboarding/data/onboarding_draft_repository.dart';
import 'package:mobile/features/schedule/data/schedule_repository.dart';

import '../../support/app_harness.dart';
import '../../support/golden.dart';

void main() {
  final atStep4 = Profile(
    onboardingStep: 4,
    disclaimerAcceptedAt: DateTime(2026, 10, 7, 11, 50),
    heightCm: 175,
    birthYear: 1996,
    sex: Sex.male,
    activityLevel: ActivityLevel.moderate,
    calorieMode: CalorieMode.auto,
    calorieKcal: 2210,
  );
  final template = WeeklyTemplate({
    1: TemplateDay(
      enabled: true,
      time: LocalTime(18, 0),
      muscles: const [MuscleGroup.chest, MuscleGroup.triceps],
    ),
    3: TemplateDay(
      enabled: true,
      time: LocalTime(18, 0),
      muscles: const [MuscleGroup.back],
    ),
    5: TemplateDay(
      enabled: true,
      time: LocalTime(18, 0),
      muscles: const [MuscleGroup.shoulders],
    ),
  });

  Future<void> pump(
    WidgetTester tester,
    GoldenVariant variant,
    AppDatabase db, {
    required DateTime now,
    bool onboarded = false,
  }) async {
    setPhoneSurface(tester);
    tester.platformDispatcher
      ..platformBrightnessTestValue = variant.brightness
      ..textScaleFactorTestValue = variant.textScale;
    addTearDown(tester.platformDispatcher.clearAllTestValues);
    final container = ProviderContainer(
      retry: (_, _) => null,
      overrides: appOverrides(
        db: db,
        clock: FixedClock(now),
        onboarded: onboarded,
        initialSetup: SetupState.of(await ProfileRepository(db).get()),
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
    testWidgets('S-05 Lịch tuần (đang mở thứ 2) ${v.name}', (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      await ProfileRepository(db).put(atStep4);
      await OnboardingDraftRepository(db).saveTemplate(template);
      await pump(tester, v, db, now: DateTime(2026, 10, 7, 12));
      await tester.tap(find.byKey(const ValueKey('day-row-1')));
      await tester.pumpAndSettle();
      await snap('s05_${v.name}');
    });

    testWidgets(
      'S-20 Lịch tháng 10 (hôm nay 13/10): nhãn Không tập · tự động (đã '
      'khóa), Đã tập, Không tập, Chờ đánh dấu, Sắp tới ${v.name}',
      (tester) async {
        final db = AppDatabase(NativeDatabase.memory());
        addTearDown(db.close);
        final schedule = ScheduleRepository(db);
        await schedule.putTemplate(template);
        final g = MonthGenerator.first(template, DateTime(2026, 10, 1, 12));
        await schedule.putPlan(g.plan);
        for (final d in g.days) {
          await schedule.putDay(switch (d.date.day) {
            7 => d.withMark(
              DayMark.done,
              actual: const [MuscleGroup.back],
              markedAt: DateTime(2026, 10, 7, 19),
            ),
            9 => d.withMark(
              DayMark.skipped,
              markedAt: DateTime(2026, 10, 9, 19),
            ),
            _ => d,
          });
        }
        await pump(
          tester,
          v,
          db,
          now: DateTime(2026, 10, 13, 8),
          onboarded: true,
        );
        await tester.tap(
          find.descendant(
            of: find.byType(AppTabBar),
            matching: find.text(S.tabSchedule),
          ),
        );
        await tester.pumpAndSettle();
        await snap('s20_${v.name}');
      },
    );
  }
}
