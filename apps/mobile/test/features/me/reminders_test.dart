import 'package:domain/domain.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/app/app.dart';
import 'package:mobile/app/strings_vi.dart';
import 'package:mobile/data/db/app_database.dart';
import 'package:mobile/features/me/application/reminders.dart';
import 'package:mobile/features/me/data/profile_repository.dart';
import 'package:mobile/features/onboarding/application/setup_state.dart';
import 'package:mobile/features/schedule/data/schedule_repository.dart';
import 'package:mobile/features/weight/data/weight_repository.dart';
import 'package:mobile/ui/components/ironly_switch.dart';
import 'package:mobile/ui/components/ironly_tab_bar.dart';

import '../../support/app_harness.dart';
import '../../support/fake_notifications.dart';

void main() {
  late AppDatabase db;
  late FixedClock clock;
  late FakeNotificationGateway notifications;

  // Thứ 2 05/10/2026, 08:00.
  final monday = DateTime(2026, 10, 5, 8);
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
  });
  final atStep5 = Profile(
    onboardingStep: 5,
    disclaimerAcceptedAt: DateTime(2026, 10, 4, 21),
    heightCm: 175,
    birthYear: 1996,
    sex: Sex.male,
    activityLevel: ActivityLevel.moderate,
    calorieMode: CalorieMode.auto,
    calorieKcal: 2210,
  );

  Future<void> seedSchedule() async {
    final schedule = ScheduleRepository(db);
    await schedule.putTemplate(template);
    final g = MonthGenerator.first(template, monday);
    await schedule.putPlan(g.plan);
    for (final d in g.days) {
      await schedule.putDay(d);
    }
  }

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    clock = FixedClock(monday);
    notifications = FakeNotificationGateway();
  });

  Future<ProviderContainer> pump(
    WidgetTester tester, {
    bool onboarded = false,
  }) async {
    tester.view
      ..physicalSize = const Size(390 * 3, 844 * 3)
      ..devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final container = ProviderContainer(
      retry: (_, _) => null,
      overrides: appOverrides(
        db: db,
        clock: clock,
        notifications: notifications,
        onboarded: onboarded,
        initialSetup: SetupState.of(await ProfileRepository(db).get()),
      ),
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const IronlyApp()),
    );
    await tester.pumpAndSettle();
    return container;
  }

  Finder tab(String label) => find.descendant(
    of: find.byType(IronlyTabBar),
    matching: find.text(label),
  );

  group('ReminderScheduler', () {
    late ReminderScheduler scheduler;

    setUp(() {
      scheduler = ReminderScheduler(
        gateway: notifications,
        profiles: ProfileRepository(db),
        schedule: ScheduleRepository(db),
        clock: clock,
      );
    });

    test('F04-AC1, NAV-2: buổi 18:00 → nhắc 17:00 "Hôm nay tập ngực và tay '
        'sau lúc 18:00", mở Hôm nay', () async {
      await seedSchedule();
      await ProfileRepository(db).put(atStep5.copyWith(remindersEnabled: true));
      final n = await scheduler.reschedule();
      // Tháng 10 từ 05/10 (8 buổi) + tháng 11 suy ra từ lịch tuần (9 buổi).
      expect(n, 17);
      final first = notifications.scheduled.first;
      expect(first.at, DateTime(2026, 10, 5, 17));
      expect(first.body, 'Hôm nay tập ngực và tay sau lúc 18:00');
      expect(first.payload, '/today');
      expect(notifications.scheduled[1].body, 'Hôm nay tập lưng lúc 18:00');
    });

    test(
      'F04-AC2: công tắc tắt → không có nhắc nào; chưa có quyền → không hẹn',
      () async {
        await seedSchedule();
        await ProfileRepository(
          db,
        ).put(atStep5.copyWith(remindersEnabled: true));
        await scheduler.reschedule();
        expect(notifications.scheduled, isNotEmpty);

        await ProfileRepository(
          db,
        ).put(atStep5.copyWith(remindersEnabled: false));
        expect(await scheduler.reschedule(), 0);
        expect(notifications.scheduled, isEmpty);

        await ProfileRepository(
          db,
        ).put(atStep5.copyWith(remindersEnabled: true));
        notifications.permitted = false;
        expect(await scheduler.reschedule(), 0);
        expect(notifications.scheduled, isEmpty);
      },
    );
  });

  testWidgets(
    'Demo VS-05 / UX-AC2: S-06 có ví dụ thật từ lịch; "Bật nhắc" → xin quyền '
    '→ hoàn tất thiết lập → Hôm nay, nhắc đã hẹn',
    (tester) async {
      await ProfileRepository(db).put(atStep5);
      await seedSchedule();
      await WeightRepository(db).put(LocalDate(2026, 10, 5), 725);
      await pump(tester);
      expect(find.bySemanticsLabel(S.stepOf(5)), findsOneWidget);
      expect(find.text(S.reminderStepTitle), findsOneWidget);
      expect(
        find.text('Hôm nay tập ngực và tay sau lúc 18:00'),
        findsOneWidget,
      );
      expect(find.text(S.reminderExample('17:00', 'thứ 2')), findsOneWidget);

      await tester.tap(find.text(S.turnOnReminders));
      await tester.pumpAndSettle();
      expect(notifications.requests, 1);
      expect(tab(S.tabToday), findsOneWidget);
      expect(find.text(S.tabToday), findsWidgets);
      final p = (await ProfileRepository(db).get())!;
      expect(p.isOnboardingCompleted, isTrue);
      expect(p.setupDate, LocalDate(2026, 10, 5));
      expect(p.remindersEnabled, isTrue);
      expect(p.timezone, 'Asia/Ho_Chi_Minh');
      expect(notifications.scheduled, hasLength(17));
      expect(find.byKey(const ValueKey('tab-dot-me')), findsNothing);
    },
  );

  testWidgets(
    'F04-E2, F04-AC5, UX-AC14: từ chối quyền → vẫn vào Hôm nay, công tắc bật, '
    'tab Tôi có chấm; S-50 cảnh báo kèm "Mở Cài đặt"',
    (tester) async {
      notifications
        ..permitted = false
        ..grantOnRequest = false;
      await ProfileRepository(db).put(atStep5);
      await seedSchedule();
      await pump(tester);
      await tester.tap(find.text(S.turnOnReminders));
      await tester.pumpAndSettle();
      expect(tab(S.tabToday), findsOneWidget);
      expect((await ProfileRepository(db).get())!.remindersEnabled, isTrue);
      expect(notifications.scheduled, isEmpty);
      expect(find.byKey(const ValueKey('tab-dot-me')), findsOneWidget);

      await tester.tap(tab(S.tabMe));
      await tester.pumpAndSettle();
      expect(find.text(S.notificationsBlocked), findsOneWidget);
      final toggle = tester.widget<IronlySwitch>(
        find.byKey(const ValueKey('reminders-switch')),
      );
      expect(toggle.value, isTrue);
      await tester.tap(find.text(S.openSettings));
      await tester.pumpAndSettle();
      expect(notifications.settingsOpened, 1);
    },
  );

  testWidgets(
    'OB-4: "Để sau" → công tắc tắt, vào Hôm nay, không có nhắc; ED-06: cân ban '
    'đầu ghi tuần trước được chuyển sang tuần thiết lập',
    (tester) async {
      await ProfileRepository(db).put(atStep5);
      await seedSchedule();
      // Bước 2 làm hôm chủ nhật 04/10 (tuần 28/09), hoàn tất thứ 2 05/10.
      await WeightRepository(db).put(LocalDate(2026, 9, 28), 725);
      await pump(tester);
      await tester.tap(find.text(S.later));
      await tester.pumpAndSettle();
      expect(tab(S.tabToday), findsOneWidget);
      final p = (await ProfileRepository(db).get())!;
      expect((p.isOnboardingCompleted, p.remindersEnabled), (true, false));
      expect(notifications.requests, 0);
      expect(notifications.scheduled, isEmpty);
      expect(await WeightRepository(db).all(), [
        (week: LocalDate(2026, 10, 5), kgX10: 725),
      ]);
    },
  );

  testWidgets(
    'S-50: tắt công tắc → hủy mọi nhắc, "Đã tắt nhắc đi tập"; bật lại → nhắc '
    'từ buổi kế tiếp (F04-R6), "Đã bật nhắc đi tập"; NAV-2: chạm nhắc → Hôm nay',
    (tester) async {
      await ProfileRepository(db).put(
        atStep5.copyWith(
          remindersEnabled: true,
          setupDate: LocalDate(2026, 10, 5),
          onboardingCompletedAt: monday,
        ),
      );
      await seedSchedule();
      await pump(tester, onboarded: true);
      expect(notifications.scheduled, hasLength(17));

      await tester.tap(tab(S.tabMe));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('reminders-switch')));
      await tester.pumpAndSettle();
      expect(find.text(S.remindersTurnedOff), findsOneWidget);
      expect(notifications.scheduled, isEmpty);
      expect((await ProfileRepository(db).get())!.remindersEnabled, isFalse);

      clock.set(DateTime(2026, 10, 5, 17, 30));
      await tester.tap(find.byKey(const ValueKey('reminders-switch')));
      await tester.pumpAndSettle();
      expect(find.text(S.remindersTurnedOn), findsOneWidget);
      expect(notifications.scheduled.first.at, DateTime(2026, 10, 7, 17));

      notifications.onTap!('/today');
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('reminders-switch')), findsNothing);
      expect(
        tester
            .widget<Text>(
              find
                  .descendant(
                    of: find.byType(IronlyTabBar),
                    matching: find.text(S.tabToday),
                  )
                  .first,
            )
            .style
            ?.color,
        isNotNull,
      );
    },
  );
}
