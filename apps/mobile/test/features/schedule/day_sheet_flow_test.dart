import 'dart:async';

import 'package:domain/domain.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/app/app.dart';
import 'package:mobile/app/shell/app_tab_bar.dart';
import 'package:mobile/app/strings_vi.dart';
import 'package:mobile/data/db/app_database.dart';
import 'package:mobile/features/schedule/application/month_materializer.dart';
import 'package:mobile/features/schedule/data/schedule_repository.dart';
import 'package:mobile/features/schedule/presentation/day_sheet.dart';
import 'package:mobile/features/schedule/presentation/schedule_screen.dart';

import '../../support/app_harness.dart';
import '../../support/fake_notifications.dart';
import '../../support/fake_server.dart';
import '../../support/fake_sync.dart';
import '../../support/schedule_fixture.dart';

void main() {
  late AppDatabase db;
  late FixedClock clock;
  late FakeScheduler scheduler;
  late FakeNotificationGateway notifications;
  late ProviderContainer container;

  // templateAc2 thiết lập 12:00 thứ 4 07/10; hôm nay 10:00 thứ 4 14/10.
  final wed14 = LocalDate(2026, 10, 14);

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    clock = FixedClock(DateTime(2026, 10, 14, 10));
    scheduler = FakeScheduler();
    notifications = FakeNotificationGateway();
  });

  Future<void> pump(WidgetTester tester) async {
    tester.view
      ..physicalSize = const Size(390 * 3, 844 * 3)
      ..devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    container = ProviderContainer(
      retry: (_, _) => null,
      overrides: appOverrides(
        db: db,
        clock: clock,
        scheduler: scheduler,
        server: FakeServer(),
        notifications: notifications,
      ),
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const HealthApp()),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(AppTabBar),
        matching: find.text(S.tabTraining),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> tapKey(WidgetTester tester, String key) async {
    final f = find.byKey(ValueKey(key));
    // S-20 tự cuộn tới hôm nay; phần đầu (tiêu đề, thanh chọn mục, nút "Lịch
    // tuần") có thể đã ra khỏi vùng dựng sẵn của danh sách → cuộn lên.
    if (f.evaluate().isEmpty) {
      await tester.scrollUntilVisible(
        f,
        -300,
        scrollable: find
            .descendant(
              of: find.byType(ScheduleScreen),
              matching: find.byType(Scrollable),
            )
            .first,
      );
    }
    await tester.ensureVisible(f);
    await tester.pumpAndSettle();
    await tester.tap(f);
    await tester.pumpAndSettle();
  }

  /// Mở S-21 của ngày [date] như chạm vào dòng ở S-20.
  Future<void> open(WidgetTester tester, LocalDate date) async {
    unawaited(showDaySheet(tester.element(find.byType(ScheduleScreen)), date));
    await tester.pumpAndSettle();
  }

  Future<PlanDay> day(int d) async =>
      (await ScheduleRepository(db).day(LocalDate(2026, 10, d)))!;

  group('UX-AC8: S-21 chỉ hiện thao tác hợp lệ', () {
    testWidgets(
      'ngày tập hôm nay chưa đến giờ (mock S-21-1): đổi giờ, đổi nhóm cơ, cho '
      'nghỉ; chạm dòng ở S-20 mở S-21',
      (tester) async {
        await seedSetUp(db);
        await pump(tester);
        await tapKey(tester, 'day-2026-10-16');
        expect(find.text('Thứ 6, 16/10'), findsOneWidget);
        expect(find.text('Vai · 18:00 · ${S.fromTemplate}'), findsOneWidget);
        for (final k in ['day-change-time', 'day-change-muscles', 'day-rest']) {
          expect(find.byKey(ValueKey(k)), findsOneWidget, reason: k);
        }
        expect(find.byKey(const ValueKey('day-revert')), findsNothing);
        expect(find.text(S.onlyThisDay), findsOneWidget);
      },
    );

    testWidgets('ngày nghỉ từ ngày mai: chỉ "Lên lịch tập ngày này"', (
      tester,
    ) async {
      await seedSetUp(db);
      await pump(tester);
      await open(tester, LocalDate(2026, 10, 15));
      expect(find.text(S.scheduleThisDay), findsOneWidget);
      expect(find.text(S.logExtraSession), findsNothing);
      expect(find.byKey(const ValueKey('day-rest')), findsNothing);
    });

    testWidgets(
      'hôm nay nghỉ (mock S-21-2): lên lịch tập hôm nay · ghi buổi tập thêm; '
      'đã có buổi tập thêm → chỉ sửa buổi tập thêm, câu F03-E4',
      (tester) async {
        clock.set(DateTime(2026, 10, 15, 9));
        await seedSetUp(db);
        await pump(tester);
        await open(tester, LocalDate(2026, 10, 15));
        expect(find.text('Thứ 5, 15/10 · Hôm nay'), findsOneWidget);
        expect(find.text(S.scheduleToday), findsOneWidget);
        expect(find.text(S.logExtraSession), findsOneWidget);
        await tapKey(tester, 'day-log-extra');
        expect(find.text(S.extraNotCounted), findsOneWidget, reason: 'S-24');

        await tester.pumpWidget(const SizedBox());
        await seedExtra(db, LocalDate(2026, 10, 15), const [MuscleGroup.abs]);
        await pump(tester);
        await open(tester, LocalDate(2026, 10, 15));
        expect(find.text(S.scheduleToday), findsNothing);
        expect(find.text(S.editExtraSession), findsOneWidget);
        expect(find.text(S.extraBlocksSchedule), findsOneWidget);
      },
    );

    testWidgets(
      'buổi đã đến giờ hoặc đã qua trong 7 ngày → "Đánh dấu buổi tập" mở '
      'S-23; ngày nghỉ đã qua → S-24; quá 7 ngày → khóa; chủ nhật → chỉ xem',
      (tester) async {
        await seedSetUp(db);
        await pump(tester);
        await open(tester, LocalDate(2026, 10, 9));
        expect(find.byKey(const ValueKey('day-change-time')), findsNothing);
        await tapKey(tester, 'day-mark');
        expect(find.text(S.plannedLine('Vai', '18:00')), findsOneWidget);
        await tester.tapAt(const Offset(195, 60));
        await tester.pumpAndSettle();

        await open(tester, LocalDate(2026, 10, 13));
        await tapKey(tester, 'day-extra');
        expect(find.text(S.extraNotCounted), findsOneWidget, reason: 'S-24');
        await tester.tapAt(const Offset(195, 60));
        await tester.pumpAndSettle();

        clock.set(DateTime(2026, 10, 16, 10));
        scheduler.fireSync();
        await tester.pumpAndSettle();
        await open(tester, LocalDate(2026, 10, 7));
        expect(find.text(S.lockedNote), findsOneWidget);
        expect(find.byKey(const ValueKey('day-mark')), findsNothing);
        await tester.tapAt(const Offset(195, 60));
        await tester.pumpAndSettle();

        await open(tester, LocalDate(2026, 10, 18));
        expect(find.text(S.sundayRest), findsOneWidget);
        expect(find.byType(ListTile), findsNothing);
      },
    );
  });

  testWidgets(
    'F03-AC8 (spec ghi thứ 5 23/10; năm 2026 thứ 5 là 22/10): "Lên lịch tập '
    'ngày này" → chưa chọn nhóm cơ báo F03-V4 → Bụng 18:00 → "Đã sửa riêng '
    'Thứ 5 22/10", S-20 có nhãn "Đã sửa riêng"; "Trả về theo lịch tuần" → '
    'hộp xác nhận → lại nghỉ',
    (tester) async {
      await seedSetUp(db, profile: completedProfile(remindersEnabled: true));
      await pump(tester);
      await open(tester, LocalDate(2026, 10, 22));
      await tapKey(tester, 'day-schedule');
      await tester.tap(find.widgetWithText(FilledButton, S.save));
      await tester.pumpAndSettle();
      expect(find.text(S.missingTimeOrMuscles), findsOneWidget);
      await tapKey(tester, 'muscle-abs');
      await tester.tap(find.widgetWithText(FilledButton, S.save));
      await tester.pumpAndSettle();
      expect(find.text('Đã sửa riêng Thứ 5 22/10'), findsOneWidget);
      final d = await day(22);
      expect((d.isWorkout, d.time), (true, LocalTime(18, 0)));
      expect(d.muscles, [MuscleGroup.abs]);
      expect(
        notifications.scheduled.map((n) => n.at),
        contains(DateTime(2026, 10, 22, 17)),
      );
      final row = find.byKey(const ValueKey('day-2026-10-22'));
      expect(
        find.descendant(of: row, matching: find.text(S.overridden)),
        findsOneWidget,
      );

      await tapKey(tester, 'day-2026-10-22');
      await tapKey(tester, 'day-revert');
      expect(find.text(S.revertConfirmTitle), findsOneWidget);
      await tapKey(tester, 'confirm-revert');
      expect((await day(22)).isWorkout, isFalse);
      expect((await day(22)).source, DaySource.template);
    },
  );

  testWidgets(
    'F04-E4: "Cho nghỉ ngày này" → hộp xác nhận "Cho nghỉ Thứ 4, 14/10? Nhắc '
    'của ngày này sẽ được hủy." → ngày nghỉ, nhắc bị hủy; F03-E2: đổi giờ hôm '
    'nay còn chưa đầy 1 giờ → ghi chú không có nhắc',
    (tester) async {
      clock.set(DateTime(2026, 10, 14, 17, 10));
      await seedSetUp(db, profile: completedProfile(remindersEnabled: true));
      await pump(tester);
      await open(tester, wed14);
      await tapKey(tester, 'day-change-time');
      expect(find.byKey(const ValueKey('under-hour-note')), findsOneWidget);
      expect(find.text(S.noReminderUnderHour), findsOneWidget);
      await tester.tapAt(const Offset(195, 60));
      await tester.pumpAndSettle();
      if (find.text(S.discardChangesTitle).evaluate().isNotEmpty) {
        await tester.tap(find.text(S.discard));
        await tester.pumpAndSettle();
      }

      await open(tester, wed14);
      await tapKey(tester, 'day-rest');
      expect(
        find.text('Cho nghỉ Thứ 4, 14/10? Nhắc của ngày này sẽ được hủy.'),
        findsOneWidget,
      );
      await tapKey(tester, 'confirm-rest');
      expect((await day(14)).isWorkout, isFalse);
      expect(
        notifications.scheduled.where(
          (n) => LocalDate.fromDateTime(n.at) == wed14,
        ),
        isEmpty,
      );
      expect(find.text('Đã sửa riêng Thứ 4 14/10'), findsOneWidget);
    },
  );

  testWidgets(
    'UX-AC9, F03-AC5 → AC7: S-22 đổi thứ 4 sang Vai → "Đã lưu lịch tuần", '
    'banner + chấm ở tab Lịch tập; Chia lại → hộp xác nhận → "Đã chia lại '
    'lịch từ 14/10 đến 31/10. Giữ nguyên 1 ngày Bạn đã sửa riêng.", banner và '
    'chấm biến mất',
    (tester) async {
      await seedSetUp(db);
      final schedule = ScheduleRepository(db);
      await schedule.putDay(
        OverrideRules.override(await day(21), now: clock.now()),
      );
      await pump(tester);
      expect(find.byKey(const ValueKey('redistribute-banner')), findsNothing);
      expect(find.byKey(const ValueKey('tab-dot-schedule')), findsNothing);

      await tapKey(tester, 'open-weekly');
      expect(find.text(S.weeklyEditHint), findsOneWidget);
      await tapKey(tester, 'day-row-3');
      await tapKey(tester, 'muscle-back');
      await tapKey(tester, 'muscle-shoulders');
      await tester.tap(find.widgetWithText(FilledButton, S.save));
      await tester.pumpAndSettle();
      expect(find.text(S.templateSaved), findsOneWidget);
      expect(find.byKey(const ValueKey('redistribute-banner')), findsOneWidget);
      expect(find.text(S.templateChangedBanner), findsOneWidget);
      expect(find.byKey(const ValueKey('tab-dot-schedule')), findsOneWidget);
      expect((await day(14)).muscles, [MuscleGroup.back], reason: 'F03-AC5');

      await tapKey(tester, 'redistribute');
      expect(find.text(S.redistributeTitle), findsOneWidget);
      expect(find.text(S.redistributeBody), findsOneWidget);
      expect(find.text(S.redistributeNote), findsOneWidget);
      await tapKey(tester, 'confirm-redistribute');
      expect(
        find.text(
          'Đã chia lại lịch từ 14/10 đến 31/10. Giữ nguyên 1 ngày Bạn đã sửa '
          'riêng.',
        ),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('redistribute-banner')), findsNothing);
      expect(find.byKey(const ValueKey('tab-dot-schedule')), findsNothing);
      expect((await day(14)).muscles, [MuscleGroup.shoulders]);
      expect((await day(21)).isWorkout, isFalse);
    },
  );

  testWidgets(
    'F03-E5: lịch tuần đã đổi nhưng chưa chia lại, sang tháng mới → tháng mới '
    'theo lịch tuần mới, banner biến mất',
    (tester) async {
      await seedSetUp(db);
      await pump(tester);
      await tapKey(tester, 'open-weekly');
      await tapKey(tester, 'day-row-3');
      await tapKey(tester, 'muscle-back');
      await tapKey(tester, 'muscle-shoulders');
      await tester.tap(find.widgetWithText(FilledButton, S.save));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('redistribute-banner')), findsOneWidget);

      clock.set(DateTime(2026, 11, 1, 0, 0, 1));
      await container.read(monthMaterializerProvider).run();
      scheduler.fireSync();
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('redistribute-banner')), findsNothing);
      expect(
        (await ScheduleRepository(db).day(LocalDate(2026, 11, 4)))!.muscles,
        [MuscleGroup.shoulders],
      );
    },
  );

  testWidgets(
    'S-22: đổi rồi bấm "‹ Lịch tập" → hỏi "Bỏ các thay đổi chưa lưu?"; Bỏ → '
    'về S-20, lịch tuần không đổi',
    (tester) async {
      await seedSetUp(db);
      await pump(tester);
      await tapKey(tester, 'open-weekly');
      await tapKey(tester, 'day-switch-2');
      await tapKey(tester, 'weekly-back');
      expect(find.text(S.discardChangesTitle), findsOneWidget);
      await tester.tap(find.text(S.discard));
      await tester.pumpAndSettle();
      expect(find.text(S.weeklyEditHint), findsNothing);
      expect(
        (await ScheduleRepository(db).template())!.contentHash,
        templateAc2.contentHash,
      );
    },
  );
}
