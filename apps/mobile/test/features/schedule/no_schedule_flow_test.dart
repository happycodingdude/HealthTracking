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
import 'package:mobile/features/onboarding/application/setup_state.dart';
import 'package:mobile/features/onboarding/data/onboarding_draft_repository.dart';
import 'package:mobile/features/schedule/data/schedule_repository.dart';
import 'package:mobile/features/weight/data/weight_repository.dart';
import 'package:mobile/ui/components/ironly_tab_bar.dart';

import '../../support/app_harness.dart';
import '../../support/fake_notifications.dart';
import '../../support/fake_server.dart';
import '../../support/schedule_fixture.dart';

/// VS-25: "Để sau" ở bước lịch tuần và trạng thái Chưa có lịch (04 Bản 2
/// §6.5, §6.6, S-20, S-22, S-50; UX-AC24, UX-AC25).
void main() {
  late AppDatabase db;
  late FixedClock clock;
  late FakeNotificationGateway notifications;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    // 12:00 thứ 4 14/10/2026.
    clock = FixedClock(DateTime(2026, 10, 14, 12));
    notifications = FakeNotificationGateway();
  });

  Future<void> pump(WidgetTester tester) async {
    tester.view
      ..physicalSize = const Size(390 * 3, 844 * 3)
      ..devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final container = ProviderContainer(
      retry: (_, _) => null,
      overrides: appOverrides(
        db: db,
        clock: clock,
        server: FakeServer(),
        notifications: notifications,
        onboarded: false,
        initialSetup: SetupState.of(await ProfileRepository(db).get()),
      ),
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const IronlyApp()),
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

  Future<void> tab(WidgetTester tester, String label) async {
    await tester.tap(
      find.descendant(
        of: find.byType(IronlyTabBar),
        matching: find.text(label),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// Tài khoản đã qua bước 3, đang ở bước 4 (S-05).
  Future<void> seedAtStep4() async {
    await AccountRepository(db).put('Minh');
    await ProfileRepository(db).put(
      Profile(
        onboardingStep: 4,
        disclaimerAcceptedAt: DateTime(2026, 10, 14, 11, 50),
        heightCm: 175,
        birthYear: 1996,
        sex: Sex.male,
        activityLevel: ActivityLevel.moderate,
        calorieMode: CalorieMode.auto,
        calorieKcal: 2210,
      ),
    );
    await WeightRepository(db).put(LocalDate(2026, 10, 12), 800);
  }

  /// Tài khoản đã hoàn tất thiết lập với "Để sau" (Chưa có lịch), nhắc bật.
  Future<void> seedNoSchedule() async {
    await AccountRepository(db).put('Minh');
    await ProfileRepository(db).put(completedProfile(remindersEnabled: true));
  }

  testWidgets(
    'UX-AC24, F03-AC21, OB-7: Bước 4 có "Để sau" dưới "Lưu lịch tập" → bấm '
    '(không hỏi lại) → Bước 5 câu ví dụ chung + "Nhắc bắt đầu hoạt động khi '
    'Bạn xếp lịch tuần."; F04-R24: "Bật nhắc" vẫn hỏi quyền; UX-AC25, F06-AC21, '
    'F05-AC27: Hôm nay "Chưa có lịch tập", không thẻ tiến độ, không "Ghi buổi '
    'tập thêm"; F04-AC23: không hẹn nhắc nào',
    (tester) async {
      await seedAtStep4();
      await pump(tester);
      expect(find.bySemanticsLabel(S.stepOf(4)), findsOneWidget);
      final save = tester.getTopLeft(find.text(S.saveSchedule)).dy;
      final later = tester.getTopLeft(
        find.byKey(const ValueKey('schedule-later')),
      );
      expect(later.dy, greaterThan(save), reason: 'nút phụ dưới nút chính');

      // Chọn dở một ngày rồi "Để sau": không lưu, không hỏi lại.
      await tapKey(tester, 'day-switch-3');
      await tapKey(tester, 'schedule-later');
      expect(find.text(S.discardChangesTitle), findsNothing);
      expect(find.bySemanticsLabel(S.stepOf(5)), findsOneWidget);
      expect(
        find.byKey(const ValueKey('reminder-generic-example')),
        findsOneWidget,
      );
      expect(
        find.text(S.reminderGenericExample, findRichText: true),
        findsOneWidget,
      );
      expect(find.text(S.remindersStartWhenScheduled), findsNothing);
      expect(find.byKey(const ValueKey('reminder-preview')), findsNothing);
      expect(await ScheduleRepository(db).template(), isNull);
      expect(await OnboardingDraftRepository(db).template(), isNull);

      await tester.tap(find.text(S.turnOnReminders));
      await tester.pumpAndSettle();
      expect(notifications.requests, 1);
      // Bản 4 (04 S-10 H1): chỉ nút "Xếp lịch tuần", không câu.
      expect(find.byKey(const ValueKey('no-schedule-card')), findsOneWidget);
      expect(find.text(S.noScheduleTitle), findsNothing);
      expect(find.text(S.noScheduleToday), findsNothing);
      expect(find.byKey(const ValueKey('week-card')), findsNothing);
      expect(find.textContaining('0/0'), findsNothing);
      expect(find.text(S.logExtraSession), findsNothing);
      expect(find.byKey(const ValueKey('session-stats')), findsNothing);
      expect(notifications.scheduled, isEmpty);
      expect((await ProfileRepository(db).get())!.remindersEnabled, isTrue);
    },
  );

  testWidgets(
    'UX-AC25, F03-AC22: mục Lịch "Chưa có lịch tập" + "Xếp lịch tuần", không '
    'thanh tháng, không banner, không danh sách; nút "Lịch tuần" và thanh chọn '
    'mục vẫn có; UA2-15: tab Tôi "Sẽ nhắc khi Bạn đã xếp lịch tuần"',
    (tester) async {
      await seedNoSchedule();
      await pump(tester);
      await tab(tester, S.tabTraining);
      expect(find.byKey(const ValueKey('no-schedule')), findsOneWidget);
      // Bản 4 (F4-R7): thẻ chỉ còn nút, không câu mời.
      expect(find.text(S.noScheduleInvite), findsNothing);
      expect(find.byKey(const ValueKey('arrange-weekly')), findsOneWidget);
      expect(find.byKey(const ValueKey('open-weekly')), findsOneWidget);
      expect(find.byKey(const ValueKey('section-library')), findsOneWidget);
      expect(find.text(S.monthTitle(10, 2026)), findsNothing);
      expect(find.byKey(const ValueKey('redistribute-banner')), findsNothing);

      await tab(tester, S.tabMe);
      expect(find.text(S.remindersHintNoSchedule), findsOneWidget);
      expect(find.text(S.remindersHint), findsNothing);
    },
  );

  testWidgets(
    'F03-AC23, F06-AC22, F04-AC21: 12:00 thứ 4 14/10 "Xếp lịch tuần" → S-22 '
    '(không có câu "áp dụng từ tháng sau") → thứ 4 Lưng, thứ 6 Vai 18:00 → '
    'Lưu → "Đã lưu lịch tuần", về S-20 với danh sách từ 14/10, không banner '
    'Chia lại; Hôm nay có buổi Lưng 18:00 và thẻ tiến độ; nhắc 17:00 hôm nay',
    (tester) async {
      await seedNoSchedule();
      await pump(tester);
      await tab(tester, S.tabTraining);
      await tapKey(tester, 'arrange-weekly');
      expect(find.text(S.weeklySchedule), findsWidgets);
      expect(find.text(S.weeklyEditHint), findsNothing);
      for (final (w, m) in [(3, 'back'), (5, 'shoulders')]) {
        await tapKey(tester, 'day-switch-$w');
        await tapKey(tester, 'day-time-$w');
        await tester.tap(find.byKey(const ValueKey('time-done')));
        await tester.pumpAndSettle();
        await tapKey(tester, 'muscle-$m');
      }
      await tapKey(tester, 'weekly-save');
      expect(find.text(S.templateSaved), findsOneWidget);
      expect(find.byKey(const ValueKey('no-schedule')), findsNothing);
      expect(find.byKey(const ValueKey('redistribute-banner')), findsNothing);
      final days = await ScheduleRepository(db).monthDays(YearMonth(2026, 10));
      expect(
        [
          for (final d in days)
            if (d.isWorkout) d.date.day,
        ],
        [14, 16, 21, 23, 28, 30],
      );
      expect(
        (await ProfileRepository(db).get())!.scheduleStartedOn,
        LocalDate(2026, 10, 14),
      );
      expect(notifications.scheduled.first.at, DateTime(2026, 10, 14, 17));

      await tab(tester, S.tabToday);
      expect(find.byKey(const ValueKey('no-schedule-card')), findsNothing);
      // 12:00 thứ 4: buổi Lưng chưa đến giờ (H3) → hàng số liệu.
      expect(find.text('Lưng · 18:00'), findsOneWidget);
      expect(find.text('0 / 2', findRichText: true), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('tab-schedule')));
      await tester.pumpAndSettle();
      await tapKey(tester, 'week-header-2026-10-12');
      expect(
        find.byKey(const ValueKey('week-previous')),
        findsNothing,
        reason: 'F06-R22: không lùi trước tuần lưu lịch lần đầu',
      );
    },
  );
}
