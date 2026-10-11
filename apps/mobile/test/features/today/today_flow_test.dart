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
import 'package:mobile/features/schedule/data/schedule_repository.dart';
import 'package:mobile/features/schedule/presentation/mark_session_sheet.dart';
import 'package:mobile/features/today/presentation/today_screen.dart';

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
      UncontrolledProviderScope(container: container, child: const HealthApp()),
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
    'UX-AC5, UA-08, F05-AC2: 1 chạm "Đã tập" → lưu ngay nhóm cơ theo lịch, thẻ '
    'và dải tiến độ đổi; "Sửa nhóm cơ" → S-23 điền sẵn Lưng → đổi Vai → Lưu',
    (tester) async {
      await seedSetUp(db);
      await pump(tester);
      await tapKey(tester, 'mark-done-${wed.toKey()}');

      expect(find.text(S.markedDone('Lưng')), findsOneWidget);
      expect(find.text(S.editMuscles), findsOneWidget);
      expect(inCard(sessionCard(), find.text(S.sessionDone)), findsOneWidget);
      expect(inCard(sessionCard(), find.text('Lưng')), findsOneWidget);
      expect(
        find.bySemanticsLabel('Thứ 4: ${S.sessionDone}'),
        findsOneWidget,
        reason: 'dải tiến độ cập nhật ngay',
      );
      var d = await day(wed);
      expect(d.mark, DayMark.done);
      expect(d.actualMuscles, [MuscleGroup.back]);
      expect(d.markedAt, DateTime(2026, 10, 7, 18, 5));
      expect(await outbox(), contains('day:2026-10-07'));

      await tester.tap(find.text(S.editMuscles));
      await tester.pumpAndSettle();
      expect(find.text(S.plannedLine('Lưng', '18:00')), findsOneWidget);
      expect(find.text(S.actualMusclesLabel), findsOneWidget);
      final back = tester.widget<Semantics>(
        find
            .descendant(
              of: find.byKey(const ValueKey('muscle-back')),
              matching: find.byType(Semantics),
            )
            .first,
      );
      expect(back.properties.selected, isTrue, reason: 'điền sẵn Lưng');
      await tapKey(tester, 'muscle-back');
      await tapKey(tester, 'muscle-shoulders');
      await tester.tap(find.widgetWithText(FilledButton, S.save));
      await tester.pumpAndSettle();
      d = await day(wed);
      expect(d.mark, DayMark.done);
      expect(d.actualMuscles, [MuscleGroup.shoulders]);
      expect(inCard(sessionCard(), find.text('Vai')), findsOneWidget);
    },
  );

  testWidgets(
    'UA-09: "Không tập" → lưu ngay, "Đã ghi: không tập" kèm "Hoàn tác"; Hoàn '
    'tác → lại "Chờ đánh dấu"',
    (tester) async {
      await seedSetUp(db);
      await pump(tester);
      await tapKey(tester, 'mark-skipped-${wed.toKey()}');
      expect(find.text(S.markedSkipped), findsOneWidget);
      expect(
        inCard(sessionCard(), find.text(S.sessionSkipped)),
        findsOneWidget,
      );
      expect((await day(wed)).mark, DayMark.skipped);

      await tester.tap(find.text(S.undo));
      await tester.pumpAndSettle();
      expect((await day(wed)).mark, isNull);
      expect(
        inCard(sessionCard(), find.text(S.statusAwaiting)),
        findsOneWidget,
      );
      expect(find.byKey(ValueKey('mark-done-${wed.toKey()}')), findsOneWidget);
    },
  );

  testWidgets(
    'S-10 ngày nghỉ: "Hôm nay nghỉ", "Buổi tới: Thứ 6 · Vai · 18:00"; UA-11: '
    'buổi thứ 4 quên đánh dấu nằm trong "Buổi chưa đánh dấu", đánh dấu được '
    'tại chỗ',
    (tester) async {
      clock.set(DateTime(2026, 10, 8, 9));
      await seedSetUp(db);
      await pump(tester);
      expect(inCard(sessionCard(), find.text(S.todayRest)), findsOneWidget);
      expect(find.text(S.nextSession('Thứ 6', 'Vai', '18:00')), findsOneWidget);
      final unmarked = find.byKey(const ValueKey('unmarked-card'));
      expect(inCard(unmarked, find.text('Thứ 4, 07/10')), findsOneWidget);
      expect(inCard(unmarked, find.text('Lưng · 18:00')), findsOneWidget);

      await tapKey(tester, 'mark-done-${wed.toKey()}');
      expect((await day(wed)).mark, DayMark.done);
      expect(find.byKey(const ValueKey('unmarked-card')), findsNothing);
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
          of: find.byType(AppTabBar),
          matching: find.text(S.tabTraining),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text(S.statusAutoSkipped), findsWidgets);
      expect(find.text(S.statusUpcoming), findsWidgets);
    },
  );

  testWidgets('S-23: bỏ hết nhóm cơ → F05-V1; "Không tập" bỏ nhóm cơ thực tế '
      '(F05-R5)', (tester) async {
    await seedSetUp(db);
    await seedMark(db, wed, DayMark.done);
    await pump(tester);
    await tapKey(tester, 'session-edit');
    await tapKey(tester, 'muscle-back');
    await tester.tap(find.widgetWithText(FilledButton, S.save));
    await tester.pumpAndSettle();
    expect(find.text(S.missingActualMuscles), findsOneWidget);
    expect((await day(wed)).actualMuscles, [MuscleGroup.back]);

    await tapKey(tester, 'choice-skipped');
    expect(find.text(S.actualMusclesLabel), findsNothing);
    await tester.tap(find.widgetWithText(FilledButton, S.save));
    await tester.pumpAndSettle();
    final d = await day(wed);
    expect(d.mark, DayMark.skipped);
    expect(d.actualMuscles, isNull);
    expect(find.text(S.markedSkipped), findsOneWidget);
  });

  testWidgets(
    'S-23 Q-2: đổi lựa chọn rồi chạm vùng mờ → hỏi "Bỏ các thay đổi chưa '
    'lưu?"',
    (tester) async {
      await seedSetUp(db);
      await seedMark(db, wed, DayMark.done);
      await pump(tester);
      await tapKey(tester, 'session-edit');
      await tapKey(tester, 'choice-skipped');
      await tester.tapAt(const Offset(195, 60));
      await tester.pumpAndSettle();
      expect(find.text(S.discardChangesTitle), findsOneWidget);
      await tester.tap(find.text(S.discard));
      await tester.pumpAndSettle();
      expect(find.text(S.actualMusclesLabel), findsNothing);
      expect((await day(wed)).mark, DayMark.done);
    },
  );

  testWidgets(
    'F05-AC4, F05-E3: buổi 07/10 trên S-23 sửa được đến hết 14/10; từ 15/10 '
    'chỉ xem, có ổ khóa và "Chỉ sửa được trong 7 ngày"',
    (tester) async {
      clock.set(DateTime(2026, 10, 14, 23, 59));
      await seedSetUp(db);
      await seedMark(db, wed, DayMark.done);
      await pump(tester);
      // Mở S-23 trực tiếp (lối vào từ S-21 có ở VS-09).
      unawaited(
        showMarkSessionSheet(tester.element(find.byType(TodayScreen)), wed),
      );
      await tester.pumpAndSettle();
      expect(find.widgetWithText(FilledButton, S.save), findsOneWidget);

      await advanceTo(tester, DateTime(2026, 10, 15));
      expect(find.widgetWithText(FilledButton, S.save), findsNothing);
      expect(find.text(S.lockedNote), findsOneWidget);
      expect(
        find.bySemanticsLabel('${S.sessionDone}, ${S.statusLocked}'),
        findsOneWidget,
      );
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
      await tester.tap(find.byKey(ValueKey('mark-done-${wed.toKey()}')));
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
