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
import 'package:mobile/features/today/application/mark_session.dart';
import 'package:mobile/features/today/presentation/today_screen.dart';

import '../../support/app_harness.dart';
import '../../support/fake_server.dart';
import '../../support/fake_sync.dart';
import '../../support/schedule_fixture.dart';

void main() {
  late AppDatabase db;
  late FixedClock clock;
  late ProviderContainer container;

  // templateAc2 thiết lập 12:00 thứ 4 07/10: tuần 05/10 – 10/10 có buổi thứ 4
  // Lưng và thứ 6 Vai (thứ 2 trước ngày thiết lập).
  final wed = LocalDate(2026, 10, 7);
  final sat = LocalDate(2026, 10, 10);

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    clock = FixedClock(DateTime(2026, 10, 7, 18, 5));
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
        scheduler: FakeScheduler(),
        server: FakeServer(),
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

  Finder card() => find.byKey(const ValueKey('progress-card'));

  Finder inCard(Finder f) => find.descendant(of: card(), matching: f);

  Finder summary() => find.byKey(const ValueKey('progress-summary'));

  testWidgets(
    'F06-AC1, UX-AC5, F06-R6: thẻ tiến độ "Đã tập 0/2 buổi theo lịch" → 1 '
    'chạm "Đã tập" → "Đã tập 1/2" ngay; F06-AC2, F05-AC5: thứ 7 ghi buổi tập '
    'thêm → "+1 buổi thêm", dòng chính không đổi',
    (tester) async {
      await seedSetUp(db);
      await pump(tester);
      expect(inCard(find.text(S.progressLine(0, 2))), findsOneWidget);
      expect(find.byKey(const ValueKey('extra-count')), findsNothing);

      await tapKey(tester, 'mark-done-${wed.toKey()}');
      expect(inCard(find.text(S.progressLine(1, 2))), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      clock.set(DateTime(2026, 10, 10, 20));
      await pump(tester);
      await tapKey(tester, 'extra-log');
      await tapKey(tester, 'muscle-abs');
      await tester.tap(find.widgetWithText(FilledButton, S.save));
      await tester.pumpAndSettle();
      expect(inCard(find.text(S.progressLine(1, 2))), findsOneWidget);
      expect(inCard(find.text(S.extraCount(1))), findsOneWidget);
    },
  );

  testWidgets(
    'S-25, F06-AC4, F06-E3: chạm thẻ → tuần hiện tại; "‹" về tuần thiết lập '
    'thì hết lùi; không có "›" ở tuần hiện tại; không có ngày trước ngày '
    'thiết lập; "‹ Hôm nay" quay lại',
    (tester) async {
      await seedSetUp(db);
      await seedMark(db, wed, DayMark.done);
      await seedExtra(db, sat, const [MuscleGroup.abs]);
      clock.set(DateTime(2026, 10, 14, 19));
      await pump(tester);

      await tester.tap(card());
      await tester.pumpAndSettle();
      expect(find.text(S.weekProgressTitle), findsOneWidget);
      expect(find.text('12/10 – 17/10'), findsOneWidget);
      expect(find.byKey(const ValueKey('week-next')), findsNothing);
      expect(
        find.descendant(of: summary(), matching: find.text('0/3')),
        findsOneWidget,
      );

      await tapKey(tester, 'week-previous');
      expect(find.text('05/10 – 10/10'), findsOneWidget);
      expect(find.byKey(const ValueKey('week-previous')), findsNothing);
      expect(
        find.descendant(of: summary(), matching: find.text('1/2')),
        findsOneWidget,
      );
      expect(find.text(S.progressLine(1, 2)), findsOneWidget);
      expect(find.text(S.extraCount(1)), findsOneWidget);
      for (final d in [5, 6]) {
        expect(
          find.byKey(ValueKey('progress-day-2026-10-0$d')),
          findsNothing,
          reason: 'trước ngày thiết lập',
        );
      }
      for (final d in [7, 8, 9, 10]) {
        expect(
          find.byKey(ValueKey('progress-day-2026-10-${'$d'.padLeft(2, '0')}')),
          findsOneWidget,
        );
      }
      expect(find.text(S.restWithExtra('Bụng')), findsOneWidget);
      expect(find.text(S.statusAutoSkipped), findsOneWidget, reason: 'thứ 6');

      await tapKey(tester, 'week-next');
      expect(find.text('12/10 – 17/10'), findsOneWidget);

      await tester.tap(find.text(S.tabToday).first);
      await tester.pumpAndSettle();
      expect(find.byType(TodayScreen), findsOneWidget);
      expect(find.text(S.weekProgressTitle), findsNothing);
    },
  );

  testWidgets(
    'F06-AC3, F05-E2: đang xem S-25 tuần trước, buổi thứ 6 "Không tập (tự '
    'động)" được sửa thành "Đã tập" → tiến độ tuần trước tăng 1',
    (tester) async {
      await seedSetUp(db);
      await seedMark(db, wed, DayMark.done);
      clock.set(DateTime(2026, 10, 13, 9));
      await pump(tester);
      await tester.tap(card());
      await tester.pumpAndSettle();
      await tapKey(tester, 'week-previous');
      expect(find.text(S.progressLine(1, 2)), findsOneWidget);

      await container
          .read(markSessionProvider)
          .call(
            LocalDate(2026, 10, 9),
            DayMark.done,
            actual: const [MuscleGroup.shoulders],
          );
      await tester.pumpAndSettle();
      expect(find.text(S.progressLine(2, 2)), findsOneWidget);
    },
  );

  testWidgets(
    'F06-E1: tuần không có buổi theo lịch → "Tuần này không có buổi tập theo '
    'lịch"',
    (tester) async {
      await seedSetUp(db);
      final schedule = ScheduleRepository(db);
      for (final d in [12, 14, 16]) {
        await schedule.putDay(
          PlanDay(
            date: LocalDate(2026, 10, d),
            kind: DayKind.rest,
            source: DaySource.override,
          ),
        );
      }
      clock.set(DateTime(2026, 10, 13, 9));
      await pump(tester);
      expect(inCard(find.text(S.noPlannedSessions)), findsOneWidget);
    },
  );

  testWidgets(
    'S-20: tiêu đề tuần "Đã tập 1/2 ›" → S-25 của tuần đó, quay lại "‹ Lịch '
    'tập"; tuần chưa tới có số buổi nhưng không mở được',
    (tester) async {
      await seedSetUp(db);
      await seedMark(db, wed, DayMark.done);
      clock.set(DateTime(2026, 10, 9, 9));
      await pump(tester);
      await tester.tap(
        find.descendant(
          of: find.byType(AppTabBar),
          matching: find.text(S.tabTraining),
        ),
      );
      await tester.pumpAndSettle();
      final first = find.byKey(const ValueKey('week-header-2026-10-05'));
      expect(
        find.descendant(of: first, matching: find.text(S.weekDone(1, 2))),
        findsOneWidget,
      );
      final future = find.byKey(const ValueKey('week-header-2026-10-12'));
      await tester.ensureVisible(future);
      await tester.pumpAndSettle();
      expect(
        find.descendant(of: future, matching: find.text(S.weekDone(0, 3))),
        findsOneWidget,
      );
      expect(
        find.descendant(of: future, matching: find.byIcon(Icons.chevron_right)),
        findsNothing,
      );
      await tester.tap(future);
      await tester.pumpAndSettle();
      expect(find.text(S.weekProgressTitle), findsNothing);

      await tapKey(tester, 'week-header-2026-10-05');
      expect(find.text(S.weekProgressTitle), findsOneWidget);
      expect(find.text('05/10 – 10/10'), findsOneWidget);
      final back = find.ancestor(
        of: find.text(S.tabTraining),
        matching: find.byWidgetPredicate((w) => w is TextButton),
      );
      expect(back, findsOneWidget);
      await tester.tap(back);
      await tester.pumpAndSettle();
      expect(find.text(S.weekProgressTitle), findsNothing);
      expect(first, findsOneWidget);
    },
  );
}
