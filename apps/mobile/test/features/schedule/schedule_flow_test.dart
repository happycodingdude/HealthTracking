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
import '../../support/fake_sync.dart';

void main() {
  late AppDatabase db;
  late FixedClock clock;
  late FakeScheduler scheduler;

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

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    // F03-AC3: thiết lập lúc 12:00 ngày 07/10/2026 (thứ 4).
    clock = FixedClock(DateTime(2026, 10, 7, 12));
    scheduler = FakeScheduler();
  });

  Future<void> pump(WidgetTester tester, {bool onboarded = false}) async {
    tester.view
      ..physicalSize = const Size(390 * 3, 844 * 3)
      ..devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final container = ProviderContainer(
      retry: (_, _) => null,
      overrides: appOverrides(
        db: db,
        clock: clock,
        scheduler: scheduler,
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

  Future<void> tapKey(WidgetTester tester, String key) async {
    final f = find.byKey(ValueKey(key));
    await tester.ensureVisible(f);
    await tester.pumpAndSettle();
    await tester.tap(f);
    await tester.pumpAndSettle();
  }

  Future<void> tapText(WidgetTester tester, String text) async {
    final f = find.text(text).last;
    await tester.ensureVisible(f);
    await tester.pumpAndSettle();
    await tester.tap(f);
    await tester.pumpAndSettle();
  }

  /// Bật [weekday], chọn giờ mặc định 18:00 và các nhóm cơ.
  Future<void> setDay(
    WidgetTester tester,
    int weekday,
    List<MuscleGroup> muscles,
  ) async {
    await tapKey(tester, 'day-switch-$weekday');
    await tapKey(tester, 'day-time-$weekday');
    await tapText(tester, S.done);
    for (final m in muscles) {
      await tapKey(tester, 'muscle-${m.name}');
    }
  }

  Future<List<String>> outboxOps() async => [
    for (final o in await db.select(db.outbox).get()) '${o.entity}:${o.op}',
  ];

  testWidgets(
    'F03-AC1, F03-V1 → V3: chủ nhật không có công tắc; lỗi dưới từng thứ, '
    'biến mất khi sửa',
    (tester) async {
      await ProfileRepository(db).put(atStep4);
      await pump(tester);
      expect(find.text(S.stepOf(4)), findsOneWidget);
      expect(find.text(S.scheduleStepTitle), findsOneWidget);
      expect(find.text(S.alwaysRest), findsOneWidget);
      expect(find.byKey(const ValueKey('day-switch-7')), findsNothing);
      expect(find.byType(Switch), findsNWidgets(6));

      await tapText(tester, S.saveSchedule);
      expect(find.text(S.noWorkoutDay), findsOneWidget);

      await tapKey(tester, 'day-switch-5');
      expect(find.text(S.noWorkoutDay), findsNothing);
      await tapText(tester, S.saveSchedule);
      expect(find.text(S.missingTimeFor('Thứ 6')), findsOneWidget);
      expect(find.text(S.missingMusclesFor('Thứ 6')), findsOneWidget);
      expect(find.text(S.stepOf(4)), findsOneWidget);

      await tapKey(tester, 'muscle-shoulders');
      expect(find.text(S.missingMusclesFor('Thứ 6')), findsNothing);
      expect(find.text(S.missingTimeFor('Thứ 6')), findsOneWidget);
      expect(await ScheduleRepository(db).template(), isNull);
    },
  );

  testWidgets(
    'Demo VS-04 / F03-AC2, F03-AC3, F03-R5: xếp lịch T2 Ngực + Tay sau, T4 '
    'Lưng, T6 Vai lúc 12:00 07/10 → lịch tháng 10 từ 07/10; sang bước 5',
    (tester) async {
      await ProfileRepository(db).put(atStep4);
      await pump(tester);
      await setDay(tester, 1, [MuscleGroup.chest, MuscleGroup.triceps]);
      await setDay(tester, 3, [MuscleGroup.back]);
      await setDay(tester, 5, [MuscleGroup.shoulders]);
      // Dòng đã thu gọn hiện tóm tắt.
      await tapKey(tester, 'day-row-5');
      expect(find.text('18:00 · Ngực và tay sau'), findsOneWidget);

      await tapText(tester, S.saveSchedule);
      expect(find.text(S.stepOf(5)), findsOneWidget);

      final schedule = ScheduleRepository(db);
      final template = (await schedule.template())!;
      expect(template.day(1).muscles, [MuscleGroup.chest, MuscleGroup.triceps]);
      expect(template.day(2).enabled, isFalse);
      final plan = (await schedule.plan(YearMonth(2026, 10)))!;
      expect(plan.startDate, LocalDate(2026, 10, 7));
      final days = await schedule.monthDays(YearMonth(2026, 10));
      expect(days.first.date, LocalDate(2026, 10, 7));
      expect(days.first.isWorkout, isTrue, reason: '18:00 sau 12:00');
      expect(days.first.muscles, [MuscleGroup.back]);
      // 07/10 → 31/10: 25 ngày, 3 chủ nhật.
      expect(days, hasLength(22));
      for (final d in days) {
        expect(d.isWorkout, {1, 3, 5}.contains(d.date.weekday), reason: '$d');
      }
      expect((await ProfileRepository(db).get())!.onboardingStep, 5);
      final ops = await outboxOps();
      expect(ops, contains('weekly_template:upsert'));
      expect(ops, contains('month_plan:ensure'));
      expect(ops.where((o) => o == 'day:ensure'), hasLength(22));

      // OB-2: quay lại bước 4 thấy lịch đã lưu; lưu lại thì chia lại bằng upsert.
      await tapText(tester, S.back);
      expect(find.text(S.stepOf(4)), findsOneWidget);
      await tapKey(tester, 'day-switch-6');
      await tapKey(tester, 'day-time-6');
      await tapText(tester, S.done);
      await tapKey(tester, 'muscle-abs');
      await tapText(tester, S.saveSchedule);
      expect(find.text(S.stepOf(5)), findsOneWidget);
      final saturday = await schedule.day(LocalDate(2026, 10, 10));
      expect(saturday!.muscles, [MuscleGroup.abs]);
      expect(await outboxOps(), contains('day:upsert'));
    },
  );

  testWidgets('F03-AC3: xếp lịch lúc 18:30 → buổi 18:00 hôm nay không có', (
    tester,
  ) async {
    clock.set(DateTime(2026, 10, 7, 18, 30));
    await ProfileRepository(db).put(atStep4);
    await pump(tester);
    await setDay(tester, 3, [MuscleGroup.back]);
    await tapText(tester, S.saveSchedule);
    final today = await ScheduleRepository(db).day(LocalDate(2026, 10, 7));
    expect(today!.kind, DayKind.rest);
  });

  testWidgets('OB-3: xếp lịch dở rồi thoát app → mở lại còn nguyên', (
    tester,
  ) async {
    await ProfileRepository(db).put(atStep4);
    await pump(tester);
    await setDay(tester, 1, [MuscleGroup.chest]);
    await tester.pumpWidget(const SizedBox());
    await pump(tester);
    expect(find.text(S.stepOf(4)), findsOneWidget);
    final on = tester.widget<Switch>(
      find.byKey(const ValueKey('day-switch-1')),
    );
    expect(on.value, isTrue);
    expect(find.text('18:00 · Ngực'), findsOneWidget);
  });

  testWidgets(
    'S-20, UA-12, F03-R13: tháng đầu từ ngày thiết lập, chủ nhật nghỉ, không '
    'có tháng sau; F03-AC4: qua 00:00 ngày 01/11 lúc app đang mở → tháng 11 tự '
    'có, "‹" về tháng 10',
    (tester) async {
      await ProfileRepository(db).put(atStep4);
      await pump(tester);
      await setDay(tester, 1, [MuscleGroup.chest, MuscleGroup.triceps]);
      await setDay(tester, 3, [MuscleGroup.back]);
      await setDay(tester, 5, [MuscleGroup.shoulders]);
      await tapText(tester, S.saveSchedule);
      // Bản dev: bỏ qua bước 5 (giữ chỗ) để vào các tab.
      await tester.pumpWidget(const SizedBox());
      await pump(tester, onboarded: true);

      await tester.tap(
        find.descendant(
          of: find.byType(AppTabBar),
          matching: find.text(S.tabTraining),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text(S.monthTitle(10, 2026)), findsOneWidget);
      expect(find.text('T4 07/10'), findsOneWidget);
      expect(
        find.text('T2 05/10'),
        findsNothing,
        reason: 'trước ngày thiết lập',
      );
      expect(find.text('Lưng · 18:00'), findsWidgets);
      expect(find.text('CN 11/10'), findsOneWidget);
      expect(find.text(S.nextMonthNotice(11)), findsOneWidget);
      expect(find.byKey(const ValueKey('month-next')), findsNothing);
      expect(find.byKey(const ValueKey('month-previous')), findsNothing);

      // 00:00 ngày 01/11: hẹn giờ của app chạy lại MonthMaterializer.
      clock.set(DateTime(2026, 11, 1, 0, 0, 1));
      scheduler.fireSync();
      await tester.pumpAndSettle();
      final nov = await ScheduleRepository(db).plan(YearMonth(2026, 11));
      expect(nov!.startDate, LocalDate(2026, 11, 1));
      expect(find.text(S.monthTitle(11, 2026)), findsOneWidget);
      expect(find.text('T2 02/11'), findsOneWidget);
      expect(find.text('Ngực và tay sau · 18:00'), findsWidgets);

      await tapKey(tester, 'month-previous');
      expect(find.text(S.monthTitle(10, 2026)), findsOneWidget);
      expect(find.text(S.nextMonthNotice(11)), findsNothing);
      await tapKey(tester, 'month-next');
      expect(find.text(S.monthTitle(11, 2026)), findsOneWidget);
    },
  );

  testWidgets(
    'S-20: hôm nay ở cuối danh sách → mở tab tự cuộn tới, dòng hôm nay không '
    'bị thanh tab che',
    (tester) async {
      final schedule = ScheduleRepository(db);
      final template = WeeklyTemplate({
        1: TemplateDay(
          enabled: true,
          time: LocalTime(18, 0),
          muscles: const [MuscleGroup.chest],
        ),
      });
      await schedule.putTemplate(template);
      final g = MonthGenerator.first(template, DateTime(2026, 10, 1, 12));
      await schedule.putPlan(g.plan);
      for (final d in g.days) {
        await schedule.putDay(d);
      }
      clock.set(DateTime(2026, 10, 27, 8));
      await pump(tester, onboarded: true);

      await tester.tap(
        find.descendant(
          of: find.byType(AppTabBar),
          matching: find.text(S.tabTraining),
        ),
      );
      await tester.pumpAndSettle();
      final row = tester.getRect(find.text('T3 27/10'));
      expect(row.top, greaterThan(0));
      expect(
        row.bottom,
        lessThanOrEqualTo(tester.getRect(find.byType(AppTabBar)).top),
      );
    },
  );
}
