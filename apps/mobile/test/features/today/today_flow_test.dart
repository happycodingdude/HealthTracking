import 'dart:async';

import 'package:domain/domain.dart';
import 'package:domain/testing.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/app/app.dart';
import 'package:mobile/app/strings_vi.dart';
import 'package:mobile/data/db/app_database.dart';
import 'package:mobile/features/schedule/data/schedule_repository.dart';
import 'package:mobile/features/schedule/presentation/day_sheet.dart';
import 'package:mobile/features/today/presentation/today_screen.dart';
import 'package:mobile/ui/components/ironly_tab_bar.dart';

import '../../support/app_harness.dart';
import '../../support/fake_server.dart';
import '../../support/fake_sync.dart';
import '../../support/schedule_fixture.dart';

void main() {
  late AppDatabase db;
  late FixedClock clock;
  late FakeScheduler scheduler;
  late FakeServer server;

  final wed = LocalDate(2026, 10, 7);

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    clock = FixedClock(DateTime(2026, 10, 7, 18, 5));
    scheduler = FakeScheduler();
    server = FakeServer();
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
        scheduler: scheduler,
        server: server,
      ),
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const IronlyApp()),
    );
    await tester.pumpAndSettle();
  }

  /// Tua đồng hồ tới [at]; hẹn giờ của app (đồng hồ giao diện) chạy lại.
  Future<void> advanceTo(WidgetTester tester, DateTime at) async {
    clock.set(at);
    scheduler.fireSync();
    await tester.pumpAndSettle();
  }

  Future<void> tapKey(WidgetTester tester, String key) async {
    final f = find.byKey(ValueKey(key));
    await tester.ensureVisible(f);
    await tester.pumpAndSettle();
    await tester.tap(f);
    await tester.pumpAndSettle();
  }

  Future<PlanDay> day(LocalDate date) async =>
      (await ScheduleRepository(db).day(date))!;

  Future<List<String>> outbox() async => [
    for (final o in await db.select(db.outbox).get())
      '${o.entity}:${o.entityKey}',
  ];

  Finder sessionCard() => find.byKey(const ValueKey('session-card'));

  Finder inCard(Finder card, Finder f) =>
      find.descendant(of: card, matching: f);

  testWidgets(
    'UX-AC6, F05-AC1, F05-E1: 17:59 → "Đánh dấu được từ 18:00", không có nút '
    'đánh dấu; app đang mở qua 18:00 → "Chờ đánh dấu" với "Đã tập" · "Không '
    'tập"',
    (tester) async {
      clock.set(DateTime(2026, 10, 7, 17, 59));
      await seedSetUp(db);
      await pump(tester);
      expect(find.text('Chào Minh · Thứ 4, 07/10'), findsOneWidget);
      expect(inCard(sessionCard(), find.text('Lưng · 18:00')), findsOneWidget);
      expect(
        inCard(sessionCard(), find.text(S.statusUpcoming)),
        findsOneWidget,
      );
      expect(find.text(S.markableFrom('18:00')), findsOneWidget);
      expect(find.text(S.sessionDone), findsNothing);
      expect(find.text(S.sessionSkipped), findsNothing);

      await advanceTo(tester, DateTime(2026, 10, 7, 18));
      expect(
        inCard(sessionCard(), find.text(S.statusAwaiting)),
        findsOneWidget,
      );
      expect(find.text(S.markableFrom('18:00')), findsNothing);
      expect(find.byKey(ValueKey('mark-done-${wed.toKey()}')), findsOneWidget);
      expect(
        find.byKey(ValueKey('mark-skipped-${wed.toKey()}')),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'UX-AC26, F05-AC21: "Đã tập" → hộp "Đã tập Lưng?" với dòng 1, dòng 2 (hôm '
    'nay); "Hủy" không đổi gì; "Lưu" → thẻ "Đã tập · Lưng", "Đã chốt khi lưu", '
    'không nút sửa; thông báo "Đã ghi: tập Lưng" không có nút; dải tiến độ đổi',
    (tester) async {
      await seedSetUp(db);
      await pump(tester);
      await tapKey(tester, 'mark-done-${wed.toKey()}');
      expect(find.text(S.doneConfirmTitle('Lưng')), findsOneWidget);
      expect(find.text(S.lockConfirmLine1), findsOneWidget);
      expect(find.text(S.lockConfirmLine2), findsOneWidget);
      await tapKey(tester, 'lock-confirm-cancel');
      expect((await day(wed)).mark, isNull);
      expect(await outbox(), isNot(contains('day:2026-10-07')));
      expect(
        inCard(sessionCard(), find.text(S.statusAwaiting)),
        findsOneWidget,
      );

      await tapKey(tester, 'mark-done-${wed.toKey()}');
      await tapKey(tester, 'lock-confirm-save');
      expect(find.text(S.markedDone('Lưng')), findsOneWidget);
      expect(find.byKey(const ValueKey('toast-action')), findsNothing);
      expect(
        inCard(sessionCard(), find.text(S.doneLine('Lưng'))),
        findsOneWidget,
      );
      expect(
        inCard(sessionCard(), find.byKey(const ValueKey('locked-on-save'))),
        findsOneWidget,
      );
      expect(inCard(sessionCard(), find.text(S.edit)), findsNothing);
      expect(inCard(sessionCard(), find.byType(OutlinedButton)), findsNothing);
      expect(
        find.bySemanticsLabel('Thứ 4: ${S.sessionDone}'),
        findsOneWidget,
        reason: 'dải tiến độ cập nhật ngay',
      );
      final d = await day(wed);
      expect(d.mark, DayMark.done);
      expect(d.actualMuscles, [MuscleGroup.back]);
      expect(d.markedAt, DateTime(2026, 10, 7, 18, 5));
      expect(await outbox(), contains('day:2026-10-07'));
    },
  );

  testWidgets(
    'UX-AC27, UD2-03: "Không tập" → lưu ngay, "Đã ghi: không tập" kèm "Đổi '
    'sang Đã tập", không có "Hoàn tác"; thẻ "Đổi sang Đã tập được đến hết '
    '14/10"; nút trong thông báo → S-65 → Lưu → Đã tập',
    (tester) async {
      await seedSetUp(db);
      await pump(tester);
      await tapKey(tester, 'mark-skipped-${wed.toKey()}');
      expect(find.byKey(const ValueKey('lock-confirm')), findsNothing);
      expect(find.text(S.markedSkipped), findsOneWidget);
      expect(find.widgetWithText(TextButton, S.changeToDone), findsOneWidget);
      expect(find.text('Hoàn tác'), findsNothing);
      expect(
        inCard(sessionCard(), find.text(S.sessionSkipped)),
        findsOneWidget,
      );
      expect(
        inCard(sessionCard(), find.text(S.changeToDoneUntil('14/10'))),
        findsOneWidget,
      );
      expect(
        inCard(
          sessionCard(),
          find.byKey(ValueKey('change-to-done-${wed.toKey()}')),
        ),
        findsOneWidget,
      );
      expect((await day(wed)).mark, DayMark.skipped);

      await tapKey(tester, 'toast-action');
      expect(find.text(S.doneConfirmTitle('Lưng')), findsOneWidget);
      await tapKey(tester, 'lock-confirm-save');
      expect((await day(wed)).mark, DayMark.done);
      expect(
        inCard(sessionCard(), find.text(S.doneLine('Lưng'))),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'S-10 ngày nghỉ: "Hôm nay nghỉ", "Buổi tới: Thứ 6 · Vai · 18:00"; UA-11: '
    'buổi thứ 4 quên đánh dấu nằm trong "Buổi chưa đánh dấu", đánh dấu được '
    'tại chỗ; "Không tập" rồi "Đổi sang Đã tập" từ thông báo',
    (tester) async {
      clock.set(DateTime(2026, 10, 8, 9));
      await seedSetUp(db);
      await pump(tester);
      expect(inCard(sessionCard(), find.text(S.todayRest)), findsOneWidget);
      expect(find.text(S.nextSession('Thứ 6', 'Vai', '18:00')), findsOneWidget);
      final unmarked = find.byKey(const ValueKey('unmarked-card'));
      expect(inCard(unmarked, find.text('Thứ 4, 07/10')), findsOneWidget);
      expect(inCard(unmarked, find.text('Lưng · 18:00')), findsOneWidget);

      // "Không tập" → dòng biến mất; nút "Đổi sang Đã tập" của thông báo vẫn
      // mở S-65 (buổi đã qua: không có dòng 2, 04 Bản 2 S-65).
      await tapKey(tester, 'mark-skipped-${wed.toKey()}');
      expect((await day(wed)).mark, DayMark.skipped);
      expect(find.byKey(const ValueKey('unmarked-card')), findsNothing);
      await tapKey(tester, 'toast-action');
      expect(find.text(S.doneConfirmTitle('Lưng')), findsOneWidget);
      expect(find.byKey(const ValueKey('lock-confirm-line2')), findsNothing);
      await tapKey(tester, 'lock-confirm-save');
      expect((await day(wed)).mark, DayMark.done);
      expect(find.text(S.markedDone('Lưng')), findsOneWidget);
    },
  );

  testWidgets(
    'UX-AC7, FR-21: chủ nhật → "Chủ nhật luôn nghỉ" và buổi tới thứ 2; F05-AC3: '
    'buổi thứ 4 chưa đánh dấu thành "Không tập · tự động", không còn trong '
    '"Buổi chưa đánh dấu"',
    (tester) async {
      clock.set(DateTime(2026, 10, 10, 23, 59));
      await seedSetUp(db);
      await pump(tester);
      expect(find.byKey(const ValueKey('unmarked-card')), findsOneWidget);

      await advanceTo(tester, DateTime(2026, 10, 11));
      expect(find.text('Chào Minh · Chủ nhật, 11/10'), findsOneWidget);
      expect(inCard(sessionCard(), find.text(S.sundayRest)), findsOneWidget);
      expect(
        find.text(S.nextSession('Thứ 2', 'Ngực và tay sau', '18:00')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('unmarked-card')), findsNothing);
      expect(
        find.bySemanticsLabel('Thứ 4: ${S.statusAutoSkipped}'),
        findsOneWidget,
      );

      await tester.tap(
        find.descendant(
          of: find.byType(IronlyTabBar),
          matching: find.text(S.tabTraining),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text(S.statusAutoSkipped), findsWidgets);
      expect(find.text(S.statusUpcoming), findsWidgets);
    },
  );

  testWidgets(
    'F05-AC22, UR2-06: buổi Đã tập không có nút sửa hay đổi trạng thái ở Hôm '
    'nay và S-21, kể cả trong ngày',
    (tester) async {
      await seedSetUp(db);
      await seedMark(db, wed, DayMark.done);
      await pump(tester);
      // Chỉ còn liên kết "Xem bài tập" → S-63 (VS-27), không có nút sửa.
      expect(
        inCard(
          sessionCard(),
          find.byWidgetPredicate(
            (w) =>
                w is TextButton &&
                w.key != const ValueKey('session-view-exercises'),
          ),
        ),
        findsNothing,
      );
      expect(inCard(sessionCard(), find.byType(FilledButton)), findsNothing);
      unawaited(showDaySheet(tester.element(find.byType(TodayScreen)), wed));
      await tester.pumpAndSettle();
      expect(find.text(S.doneLine('Lưng')), findsWidgets);
      expect(find.byKey(const ValueKey('locked-on-save')), findsWidgets);
      expect(find.byKey(ValueKey('mark-skipped-${wed.toKey()}')), findsNothing);
      expect(
        find.byKey(ValueKey('change-to-done-${wed.toKey()}')),
        findsNothing,
      );
      expect(find.byKey(const ValueKey('day-change-time')), findsNothing);
    },
  );

  testWidgets(
    'F05-AC23, F05-R27: buổi Không tập 07/10 → S-21 "Đổi sang Đã tập" và "Đổi '
    'được đến hết 14/10" đến 23:59 14/10; từ 15/10 chỉ xem, ổ khóa và "Chỉ sửa '
    'được trong 7 ngày"',
    (tester) async {
      clock.set(DateTime(2026, 10, 14, 23, 59));
      await seedSetUp(db);
      await seedMark(db, wed, DayMark.skipped);
      await pump(tester);
      unawaited(showDaySheet(tester.element(find.byType(TodayScreen)), wed));
      await tester.pumpAndSettle();
      expect(find.text(S.changeableUntil('14/10')), findsOneWidget);
      expect(
        find.byKey(ValueKey('change-to-done-${wed.toKey()}')),
        findsOneWidget,
      );

      await advanceTo(tester, DateTime(2026, 10, 15));
      expect(
        find.byKey(ValueKey('change-to-done-${wed.toKey()}')),
        findsNothing,
      );
      expect(find.text(S.lockedNote), findsOneWidget);
      expect(
        find.bySemanticsLabel('${S.sessionSkipped}, ${S.statusLocked}'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'F05-AC29, F05-AC30, F05-E30 (legacyDoneDays): mở app Bản 2 với dữ liệu '
    'Bản 1 → buổi Đã tập hôm qua, thứ 2 cùng tuần chỉ xem; buổi lịch Ngực đã '
    'tập Vai hiện Vai; buổi tập thêm Bản 1 chỉ xem; buổi Không tập còn đổi '
    'được',
    (tester) async {
      clock.set(legacyToday);
      await seedSetUp(db);
      final schedule = ScheduleRepository(db);
      for (final d in LegacyDoneDays.all) {
        await schedule.putDay(d);
      }
      await pump(tester);
      final host = tester.element(find.byType(TodayScreen));
      Future<void> openDay(PlanDay d) async {
        unawaited(showDaySheet(host, d.date));
        await tester.pumpAndSettle();
      }

      Future<void> close() async {
        await tester.tapAt(const Offset(195, 60));
        await tester.pumpAndSettle();
      }

      for (final d in [
        LegacyDoneDays.doneYesterday,
        LegacyDoneDays.doneMonday,
      ]) {
        await openDay(d);
        expect(find.byKey(const ValueKey('locked-on-save')), findsOneWidget);
        expect(
          find.byKey(ValueKey('mark-skipped-${d.date.toKey()}')),
          findsNothing,
        );
        await close();
      }
      await openDay(LegacyDoneDays.doneOtherMuscles);
      expect(find.text(S.doneLine('Vai')), findsOneWidget);
      expect(find.text(S.doneLine('Ngực')), findsNothing);
      await close();
      await openDay(LegacyDoneDays.extra);
      expect(find.text(S.extraSessionLine('Bụng')), findsOneWidget);
      expect(find.byKey(const ValueKey('locked-on-save')), findsOneWidget);
      expect(find.byKey(const ValueKey('day-log-extra')), findsNothing);
      await close();
      await openDay(LegacyDoneDays.skipped);
      expect(
        find.byKey(
          ValueKey('change-to-done-${LegacyDoneDays.skipped.date.toKey()}'),
        ),
        findsOneWidget,
      );
      await close();
      // Dòng của ngày ở S-25 (tuần 05/10 – 10/10) cũng hiện Vai.
      await tester.tap(find.byKey(const ValueKey('progress-card')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('week-previous')));
      await tester.pumpAndSettle();
      // Thứ 6 09/10 theo lịch Vai; thứ 7 10/10 lịch Ngực, đã ghi Vai.
      expect(find.text('Vai · 18:00'), findsNWidgets(2));
      expect(find.text('Ngực · 18:00'), findsNothing);
    },
  );

  testWidgets(
    'TAC-01, UX-AC16, F05-E5: không có mạng → đánh dấu phản hồi ngay, không có '
    'lời gọi mạng trước khi giao diện đổi, đầu Hôm nay hiện "Chưa đồng bộ"; có '
    'mạng lại → đồng bộ, chỉ báo biến mất',
    (tester) async {
      await seedSetUp(db);
      await pump(tester);
      server.offline = true;
      final before = server.requests.length;
      await tapKey(tester, 'mark-done-${wed.toKey()}');
      await tester.tap(find.byKey(const ValueKey('lock-confirm-save')));
      await tester.pump();
      expect(inCard(sessionCard(), find.text(S.sessionDone)), findsOneWidget);
      expect(server.requests.length, before);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('sync-indicator')), findsOneWidget);

      // SyncEngine đẩy sau 1 giây; mất mạng → còn trong outbox.
      scheduler.fireSync(delay: const Duration(seconds: 1));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('sync-indicator')), findsOneWidget);

      server.offline = false;
      scheduler.fireSync();
      await tester.pumpAndSettle();
      expect(server.calls('POST', '/v1/sync/push'), isNotEmpty);
      expect(find.byKey(const ValueKey('sync-indicator')), findsNothing);
    },
  );
}
