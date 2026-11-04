import 'dart:async';

import 'package:domain/domain.dart';
import 'package:domain/testing.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/app/app.dart';
import 'package:mobile/app/router.dart';
import 'package:mobile/app/strings_vi.dart';
import 'package:mobile/data/db/app_database.dart';
import 'package:mobile/features/schedule/data/schedule_repository.dart';
import 'package:mobile/features/schedule/presentation/day_sheet.dart';
import 'package:mobile/features/today/presentation/today_screen.dart';

import '../../support/app_harness.dart';
import '../../support/fake_server.dart';
import '../../support/fake_sync.dart';
import '../../support/schedule_fixture.dart';

/// Kịch bản F-05, F-06 của Bản 1 → 3 chạy lại trên Hôm nay Bản 4 (06 Bản 4
/// VS44-T07, IR4-08): cùng bước, cùng kết quả; selector theo `Key` và dấu
/// hiệu (03 Bản 4 §6.4), không theo chữ trạng thái đã bỏ.
void main() {
  late AppDatabase db;
  late FixedClock clock;
  late FakeScheduler scheduler;
  late FakeServer server;
  late ProviderContainer container;

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
    container = ProviderContainer(
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

  /// S-21 của ngày [date] mở từ Hôm nay (Bản 4: "Không tập" và buổi ngày
  /// khác đánh dấu qua Chi tiết ngày).
  Future<void> openDay(WidgetTester tester, LocalDate date) async {
    unawaited(showDaySheet(tester.element(find.byType(TodayScreen)), date));
    await tester.pumpAndSettle();
  }

  Finder markDone() => find.byKey(const ValueKey('today-mark-done'));
  Finder status() => find.byKey(const ValueKey('today-status'));
  Finder ratio(String text) => find.text(text, findRichText: true);

  testWidgets(
    'UX-AC6, F05-AC1, F05-E1: 17:59 → H3 (ngày ở góc, không dấu chốt buổi, '
    'hàng số liệu "Lưng · 18:00"); app đang mở qua 18:00 → H4 dấu tích viền '
    'cam góc trên',
    (tester) async {
      clock.set(DateTime(2026, 10, 7, 17, 59));
      await seedSetUp(db);
      await pump(tester);
      expect(find.byKey(const ValueKey('today-date')), findsOneWidget);
      expect(find.text('Lưng · 18:00'), findsOneWidget);
      expect(
        find.bySemanticsLabel('Thứ 4, 07/10, ${S.statusUpcoming}'),
        findsOneWidget,
      );
      expect(markDone(), findsNothing);
      expect(find.text(S.sessionDone), findsNothing);
      expect(find.text(S.sessionSkipped), findsNothing);
      expect(find.text(S.markableFrom('18:00')), findsNothing);

      await advanceTo(tester, DateTime(2026, 10, 7, 18));
      expect(markDone(), findsOneWidget);
      expect(find.bySemanticsLabel(S.statusAwaiting), findsOneWidget);
      expect(find.byKey(const ValueKey('today-date')), findsNothing);
    },
  );

  testWidgets(
    'UX-AC26, F05-AC61: dấu tích góc trên → hộp "Đã tập Lưng?" câu mới '
    '(F05-R61); "Hủy" không đổi gì; "Lưu" → dấu tích cam đặc; thông báo "Đã '
    'ghi: tập Lưng" không có nút; Tuần 1 / 2 đổi ngay',
    (tester) async {
      await seedSetUp(db);
      await pump(tester);
      expect(ratio('0 / 2'), findsOneWidget);
      await tapKey(tester, 'today-mark-done');
      expect(find.text(S.doneConfirmTitle('Lưng')), findsOneWidget);
      expect(find.text(S.doneConfirmBody), findsOneWidget);
      await tapKey(tester, 'lock-confirm-cancel');
      expect((await day(wed)).mark, isNull);
      expect(await outbox(), isNot(contains('day:2026-10-07')));
      expect(markDone(), findsOneWidget);

      await tapKey(tester, 'today-mark-done');
      await tapKey(tester, 'lock-confirm-save');
      expect(find.text(S.markedDone('Lưng')), findsOneWidget);
      expect(find.byKey(const ValueKey('toast-action')), findsNothing);
      expect(markDone(), findsNothing);
      expect(status(), findsOneWidget);
      expect(find.bySemanticsLabel(S.sessionDone), findsWidgets);
      expect(find.text(S.edit), findsNothing);
      expect(ratio('1 / 2'), findsOneWidget, reason: 'tiến độ đổi ngay');
      final d = await day(wed);
      expect(d.mark, DayMark.done);
      expect(d.actualMuscles, [MuscleGroup.back]);
      expect(d.markedAt, DateTime(2026, 10, 7, 18, 5));
      expect(await outbox(), contains('day:2026-10-07'));
    },
  );

  testWidgets(
    'UX-AC27, UD2-03: "Không tập" (S-21) → lưu ngay, "Đã ghi: không tập" kèm '
    '"Đổi sang Đã tập", không có "Hoàn tác"; Hôm nay dấu gạch góc trên; nút '
    'trong thông báo → S-65 → Lưu → Đã tập',
    (tester) async {
      await seedSetUp(db);
      await pump(tester);
      await openDay(tester, wed);
      await tapKey(tester, 'mark-skipped-${wed.toKey()}');
      expect(find.byKey(const ValueKey('lock-confirm')), findsNothing);
      expect(find.text(S.markedSkipped), findsOneWidget);
      expect(find.widgetWithText(TextButton, S.changeToDone), findsOneWidget);
      expect(find.text('Hoàn tác'), findsNothing);
      expect(status(), findsOneWidget);
      expect(find.bySemanticsLabel(S.sessionSkipped), findsWidgets);
      expect((await day(wed)).mark, DayMark.skipped);

      await tapKey(tester, 'toast-action');
      expect(find.text(S.doneConfirmTitle('Lưng')), findsOneWidget);
      await tapKey(tester, 'lock-confirm-save');
      expect((await day(wed)).mark, DayMark.done);
      expect(find.bySemanticsLabel(S.sessionDone), findsWidgets);
    },
  );

  testWidgets(
    'S-10 ngày nghỉ (H2): thẻ Nghỉ với buổi tới "Thứ 6 · Vai · 18:00", thẻ '
    'Tuần này với dấu hiệu từng ngày; không "Buổi chưa đánh dấu" (BR4-14); '
    'F05-AC63, F05-AC66 (IR5-08, CR5-02, CR5-08): buổi thứ 4 quên đánh dấu '
    'đã là "Không tập · tự động", S-21 chỉ "Xem buổi"',
    (tester) async {
      clock.set(DateTime(2026, 10, 8, 9));
      await seedSetUp(db);
      await pump(tester);
      expect(find.byKey(const ValueKey('rest-card')), findsOneWidget);
      expect(find.text(S.rest), findsOneWidget);
      expect(find.text('Thứ 6 · Vai · 18:00'), findsOneWidget);
      expect(find.text(S.nextSession('Thứ 6', 'Vai', '18:00')), findsNothing);
      expect(find.byKey(const ValueKey('unmarked-card')), findsNothing);
      expect(find.text(S.unmarkedTitle), findsNothing);
      expect(
        find.bySemanticsLabel('Thứ 4: ${S.statusAutoSkipped}'),
        findsOneWidget,
      );

      await openDay(tester, wed);
      expect(find.byKey(ValueKey('mark-skipped-${wed.toKey()}')), findsNothing);
      expect(find.byKey(ValueKey('mark-done-${wed.toKey()}')), findsNothing);
      expect(find.byKey(const ValueKey('day-view-exercises')), findsOneWidget);
    },
  );

  testWidgets(
    'UX-AC7, FR-21: chủ nhật → thẻ Nghỉ, không "+ Buổi thêm", buổi tới thứ 2; '
    'F05-AC63 (IR5-08, CR5-08): buổi thứ 4 chưa đánh dấu thành "Không tập · '
    'tự động" ngay sau 00:00 thứ 5, không chờ chủ nhật',
    (tester) async {
      clock.set(DateTime(2026, 10, 7, 23, 59));
      await seedSetUp(db);
      await pump(tester);
      expect(markDone(), findsOneWidget);
      await advanceTo(tester, DateTime(2026, 10, 8));
      expect(
        find.bySemanticsLabel('Thứ 4: ${S.statusAutoSkipped}'),
        findsOneWidget,
      );

      await advanceTo(tester, DateTime(2026, 10, 11));
      expect(find.text('Chủ nhật, 11/10'), findsOneWidget);
      expect(find.byKey(const ValueKey('rest-card')), findsOneWidget);
      expect(find.byKey(const ValueKey('extra-log')), findsNothing);
      expect(find.text('Thứ 2 · Ngực và Tay sau · 18:00'), findsOneWidget);
      expect(find.text(S.sundayRest), findsNothing);
      expect(
        find.bySemanticsLabel('Thứ 4: ${S.statusAutoSkipped}'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'F05-AC61, F05-AC62, UA5-04, U5-AC7 (IR5-08, CR5-06): S-23 từ dấu tích ba mục; '
    'Đã tập → Không tập → Lưu; Chưa đánh dấu → Lưu → Hôm nay về H4 (ô tick); '
    'mức tạ giữ nguyên',
    (tester) async {
      clock.set(DateTime(2026, 10, 7, 19));
      await seedSetUp(db);
      await seedMark(db, wed, DayMark.done);
      await pump(tester);
      await tapKey(tester, 'today-status');
      expect(find.byKey(const ValueKey('status-sheet')), findsOneWidget);
      expect(find.text(S.unmarked), findsOneWidget);
      expect(find.text('Lưng · 18:00'), findsOneWidget);
      await tapKey(tester, 'status-skipped');
      await tapKey(tester, 'status-save');
      expect((await day(wed)).mark, DayMark.skipped);

      await tapKey(tester, 'today-status');
      await tapKey(tester, 'status-unmarked');
      await tapKey(tester, 'status-save');
      expect((await day(wed)).mark, isNull);
      expect(markDone(), findsOneWidget);
      expect(find.bySemanticsLabel(S.statusAwaiting), findsWidgets);
    },
  );

  testWidgets(
    'F05-R62, F05-E62: buổi Không tập 07/10 → S-23 đổi sang Đã tập trong '
    'ngày (qua S-65)',
    (tester) async {
      clock.set(DateTime(2026, 10, 7, 19));
      await seedSetUp(db);
      await seedMark(db, wed, DayMark.skipped);
      await pump(tester);
      await tapKey(tester, 'today-status');
      await tapKey(tester, 'status-done');
      await tapKey(tester, 'status-save');
      expect(find.text(S.doneConfirmTitle('Lưng')), findsOneWidget);
      await tapKey(tester, 'lock-confirm-cancel');
      expect((await day(wed)).mark, DayMark.skipped);

      await tapKey(tester, 'today-status');
      await tapKey(tester, 'status-done');
      await tapKey(tester, 'status-save');
      await tapKey(tester, 'lock-confirm-save');
      expect((await day(wed)).mark, DayMark.done);
      expect(find.bySemanticsLabel(S.sessionDone), findsWidgets);
    },
  );

  testWidgets(
    'F05-R62, F05-AC66 (S-21; IR5-08, CR5-02): buổi Không tập hôm nay → "Đổi '
    'sang Đã tập" (→ S-23); sang 00:00 chỉ "Xem buổi", không ổ khóa',
    (tester) async {
      clock.set(DateTime(2026, 10, 7, 23, 50));
      await seedSetUp(db);
      await seedMark(db, wed, DayMark.skipped);
      await pump(tester);
      await openDay(tester, wed);
      expect(find.byKey(const ValueKey('day-change-status')), findsOneWidget);
      expect(find.text(S.changeToDone), findsOneWidget);
      await tester.tapAt(const Offset(195, 60));
      await tester.pumpAndSettle();

      await advanceTo(tester, DateTime(2026, 10, 8));
      await openDay(tester, wed);
      expect(find.byKey(const ValueKey('day-change-status')), findsNothing);
      expect(find.byKey(const ValueKey('day-view-exercises')), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp(S.statusLocked)), findsNothing);
    },
  );

  testWidgets(
    'F05-AC29, F05-AC30, F05-E30 (legacyDoneDays): mở app Bản 4 với dữ liệu '
    'Bản 1 → buổi Đã tập hôm qua, thứ 2 cùng tuần chỉ xem; buổi lịch Ngực đã '
    'tập Vai hiện Vai; buổi tập thêm Bản 1 chỉ xem; F05-E67, FC5-12 (IR5-08, '
    'CR5-02): buổi Không tập còn "hạn 7 ngày" cũ cũng khóa, chỉ "Xem buổi"',
    (tester) async {
      clock.set(legacyToday);
      await seedSetUp(db);
      final schedule = ScheduleRepository(db);
      for (final d in LegacyDoneDays.all) {
        await schedule.putDay(d);
      }
      await pump(tester);

      Future<void> close() async {
        await tester.tapAt(const Offset(195, 60));
        await tester.pumpAndSettle();
      }

      for (final d in [
        LegacyDoneDays.doneYesterday,
        LegacyDoneDays.doneMonday,
      ]) {
        await openDay(tester, d.date);
        expect(find.bySemanticsLabel(S.sessionDone), findsWidgets);
        expect(
          find.byKey(ValueKey('mark-skipped-${d.date.toKey()}')),
          findsNothing,
        );
        await close();
      }
      await openDay(tester, LegacyDoneDays.doneOtherMuscles.date);
      expect(find.textContaining('Vai'), findsWidgets);
      expect(find.textContaining('Ngực'), findsNothing);
      await close();
      await openDay(tester, LegacyDoneDays.extra.date);
      expect(find.bySemanticsLabel(S.extraSession), findsWidgets);
      expect(find.byKey(const ValueKey('day-log-extra')), findsNothing);
      await close();
      await openDay(tester, LegacyDoneDays.skipped.date);
      expect(
        find.byKey(
          ValueKey('change-to-done-${LegacyDoneDays.skipped.date.toKey()}'),
        ),
        findsNothing,
      );
      expect(find.byKey(const ValueKey('day-change-status')), findsNothing);
      expect(find.byKey(const ValueKey('day-view-exercises')), findsOneWidget);
      await close();
      // Dòng của ngày ở S-25 (tuần 05/10 – 10/10) cũng hiện Vai.
      container.read(routerProvider).go('/today/progress/2026-10-05');
      await tester.pumpAndSettle();
      expect(find.textContaining('Vai'), findsNWidgets(2));
      expect(find.textContaining('Ngực'), findsNothing);
    },
  );

  testWidgets(
    'TAC-01, UX-AC16, F05-E5: không có mạng → đánh dấu phản hồi ngay, không có '
    'lời gọi mạng trước khi giao diện đổi; Hôm nay không hiện "Chưa đồng bộ" '
    '(BR4-14); có mạng lại → đồng bộ',
    (tester) async {
      await seedSetUp(db);
      await pump(tester);
      server.offline = true;
      final before = server.requests.length;
      await tapKey(tester, 'today-mark-done');
      await tester.tap(find.byKey(const ValueKey('lock-confirm-save')));
      await tester.pump();
      expect(status(), findsOneWidget);
      expect(server.requests.length, before);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('sync-indicator')), findsNothing);
      expect(find.text(S.syncPending), findsNothing);

      // SyncEngine đẩy sau 1 giây; mất mạng → còn trong outbox.
      scheduler.fireSync(delay: const Duration(seconds: 1));
      await tester.pumpAndSettle();
      expect(await outbox(), contains('day:2026-10-07'));

      server.offline = false;
      scheduler.fireSync();
      await tester.pumpAndSettle();
      expect(server.calls('POST', '/v1/sync/push'), isNotEmpty);
      expect(await outbox(), isEmpty);
    },
  );
}
