@Tags(['golden'])
library;

import 'package:domain/domain.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/app/app.dart';
import 'package:mobile/app/strings_vi.dart';
import 'package:mobile/data/db/app_database.dart';
import 'package:mobile/features/me/data/profile_repository.dart';
import 'package:mobile/features/onboarding/application/setup_state.dart';
import 'package:mobile/features/onboarding/data/onboarding_draft_repository.dart';
import 'package:mobile/features/schedule/data/schedule_repository.dart';
import 'package:mobile/ui/components/ironly_tab_bar.dart';

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
      UncontrolledProviderScope(container: container, child: const IronlyApp()),
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
            of: find.byType(IronlyTabBar),
            matching: find.text(S.tabTraining),
          ),
        );
        await tester.pumpAndSettle();
        await snap('s20_${v.name}');
      },
    );

    /// Lịch tháng 10 chia từ [template] lúc 08:00 thứ 5 01/10; thứ 2 05/10
    /// đã tập; hôm nay thứ 5 08/10. [changed] = lịch tuần đã đổi thứ 4 sang
    /// Vai nhưng chưa chia lại (mock S-20-1). [skipWed] = thứ 4 07/10 đã
    /// "Không tập" (mock S-21-3).
    Future<void> seedOctober(
      WidgetTester tester,
      GoldenVariant v, {
      bool changed = false,
      bool skipWed = false,
    }) async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final schedule = ScheduleRepository(db);
      final g = MonthGenerator.first(template, DateTime(2026, 10, 1, 8));
      await schedule.putPlan(g.plan);
      for (final d in g.days) {
        await schedule.putDay(switch (d.date.day) {
          5 => d.withMark(
            DayMark.done,
            actual: d.muscles,
            markedAt: DateTime(2026, 10, 5, 19),
          ),
          7 when skipWed => d.withMark(
            DayMark.skipped,
            markedAt: DateTime(2026, 10, 7, 19),
          ),
          _ => d,
        });
      }
      await schedule.putTemplate(
        changed
            ? WeeklyTemplate({
                ...template.days,
                3: TemplateDay(
                  enabled: true,
                  time: LocalTime(18, 0),
                  muscles: const [MuscleGroup.shoulders],
                ),
              })
            : template,
      );
      await pump(
        tester,
        v,
        db,
        now: DateTime(2026, 10, 8, 10),
        onboarded: true,
      );
      await tester.tap(
        find.descendant(
          of: find.byType(IronlyTabBar),
          matching: find.text(S.tabTraining),
        ),
      );
      await tester.pumpAndSettle();
    }

    Future<void> tapRow(WidgetTester tester, String text) async {
      final f = find.text(text);
      await tester.ensureVisible(f);
      await tester.pumpAndSettle();
      await tester.tap(f);
      await tester.pumpAndSettle();
    }

    testWidgets('S-20 lịch tuần đã đổi: banner Chia lại (mock S-20-1) '
        '${v.name}', (tester) async {
      await seedOctober(tester, v, changed: true);
      await tester.drag(find.byType(Scrollable).first, const Offset(0, 2000));
      await tester.pumpAndSettle();
      await snap('s20_banner_${v.name}');
    });

    testWidgets('S-21 ngày tập sắp tới (mock S-21-1) ${v.name}', (
      tester,
    ) async {
      await seedOctober(tester, v);
      await tapRow(tester, 'T4 14/10');
      await snap('s21_workout_${v.name}');
    });

    testWidgets('S-21 hôm nay nghỉ (mock S-21-2) ${v.name}', (tester) async {
      await seedOctober(tester, v);
      await tapRow(tester, 'T5 08/10');
      await snap('s21_today_rest_${v.name}');
    });

    testWidgets('S-21 chờ đánh dấu: hai nút trong bảng (mock S-21-1 Bản 2) '
        '${v.name}', (tester) async {
      await seedOctober(tester, v);
      await tapRow(tester, 'T4 07/10');
      await snap('s21_markable_${v.name}');
    });

    testWidgets('S-21 buổi đã chốt, chỉ xem (mock S-21-2 Bản 2) ${v.name}', (
      tester,
    ) async {
      await seedOctober(tester, v);
      await tapRow(tester, 'T2 05/10');
      await snap('s21_done_${v.name}');
    });

    testWidgets('S-21 "Không tập" còn trong 7 ngày (mock S-21-3 Bản 2) '
        '${v.name}', (tester) async {
      await seedOctober(tester, v, skipWed: true);
      await tapRow(tester, 'T4 07/10');
      await snap('s21_change_${v.name}');
    });

    testWidgets('S-22 lịch tuần, chế độ sửa (mock S-22-1) ${v.name}', (
      tester,
    ) async {
      await seedOctober(tester, v, changed: true);
      final open = find.byKey(const ValueKey('open-weekly'));
      await tester.scrollUntilVisible(
        open,
        -300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(open);
      await tester.pumpAndSettle();
      await snap('s22_${v.name}');
    });

    testWidgets('S-22 mở thứ 6, bộ chọn 7 viên đã chọn Chân (VS-33, UA3-10) '
        '${v.name}', (tester) async {
      await seedOctober(tester, v, changed: true);
      final open = find.byKey(const ValueKey('open-weekly'));
      await tester.scrollUntilVisible(
        open,
        -300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(open);
      await tester.pumpAndSettle();
      for (final key in ['day-row-5', 'muscle-shoulders', 'muscle-legs']) {
        final f = find.byKey(ValueKey(key));
        await tester.ensureVisible(f);
        await tester.pumpAndSettle();
        await tester.tap(f);
        await tester.pumpAndSettle();
      }
      await snap('s22_legs_${v.name}');
    });
  }
}
