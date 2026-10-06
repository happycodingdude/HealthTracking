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

import '../../support/app_harness.dart';
import '../../support/fake_server.dart';
import '../../support/fake_sync.dart';
import '../../support/schedule_fixture.dart';

void main() {
  late AppDatabase db;
  late FixedClock clock;

  final sat = LocalDate(2026, 10, 10);

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    // Thứ 7 10/10 là ngày nghỉ của templateAc2.
    clock = FixedClock(DateTime(2026, 10, 10, 20));
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

  Future<PlanDay> day(LocalDate date) async =>
      (await ScheduleRepository(db).day(date))!;

  Future<List<String>> outbox() async => [
    for (final o in await db.select(db.outbox).get())
      '${o.entity}:${o.entityKey}',
  ];

  Finder sessionCard() => find.byKey(const ValueKey('session-card'));

  Finder inCard(Finder f) => find.descendant(of: sessionCard(), matching: f);

  testWidgets(
    'Demo VS-07, F05-R7, F05-V2: thứ 7 nghỉ → "Đã tập ngoài lịch? Ghi buổi '
    'tập thêm" → S-24 → chưa chọn nhóm cơ thì báo lỗi → chọn Bụng → Lưu → '
    'thẻ "Buổi tập thêm · Bụng", ô thứ 7 của dải tiến độ là "Buổi tập thêm"; '
    'F05-R12: buổi theo lịch không đổi',
    (tester) async {
      await seedSetUp(db);
      await pump(tester);
      expect(inCard(find.text(S.todayRest)), findsOneWidget);
      await tapKey(tester, 'extra-log');

      expect(
        find.text(S.extraSessionTitle('Thứ 7, 10/10', today: true)),
        findsOneWidget,
      );
      expect(
        find.text('Buổi tập thêm · Thứ 7, 10/10 · Hôm nay'),
        findsOneWidget,
      );
      expect(find.text(S.extraNotCounted), findsOneWidget);
      expect(find.byKey(const ValueKey('extra-delete')), findsNothing);

      await tester.tap(find.widgetWithText(FilledButton, S.save));
      await tester.pumpAndSettle();
      expect(find.text(S.missingActualMuscles), findsOneWidget);
      expect((await day(sat)).extraMuscles, isNull);

      await tapKey(tester, 'muscle-abs');
      expect(find.text(S.missingActualMuscles), findsNothing);
      await tester.tap(find.widgetWithText(FilledButton, S.save));
      await tester.pumpAndSettle();

      expect(find.text(S.markedDone('Bụng')), findsOneWidget);
      expect(inCard(find.text(S.extraSessionLine('Bụng'))), findsOneWidget);
      expect(inCard(find.text(S.todayRest)), findsNothing);
      expect(find.bySemanticsLabel('Thứ 7: ${S.extraSession}'), findsOneWidget);
      final d = await day(sat);
      expect(d.extraMuscles, [MuscleGroup.abs]);
      expect(d.extraLoggedAt, DateTime(2026, 10, 10, 20));
      expect(await outbox(), ['day:2026-10-10']);
      // Không tính vào kế hoạch: các buổi theo lịch giữ nguyên.
      expect((await day(LocalDate(2026, 10, 9))).mark, isNull);
    },
  );

  testWidgets(
    'S-24 sửa: Bụng → Lưng; "Xóa buổi tập thêm" → hộp xác nhận (NAV-6): Hủy '
    'giữ nguyên, Xóa → thẻ về "Hôm nay nghỉ" (F05-R11, ED-08)',
    (tester) async {
      await seedSetUp(db);
      await seedExtra(db, sat, const [MuscleGroup.abs]);
      await pump(tester);
      expect(inCard(find.text(S.extraSessionLine('Bụng'))), findsOneWidget);
      expect(find.byKey(const ValueKey('extra-log')), findsNothing);

      await tapKey(tester, 'extra-edit');
      await tapKey(tester, 'muscle-abs');
      await tapKey(tester, 'muscle-back');
      await tester.tap(find.widgetWithText(FilledButton, S.save));
      await tester.pumpAndSettle();
      expect((await day(sat)).extraMuscles, [MuscleGroup.back]);
      expect(inCard(find.text(S.extraSessionLine('Lưng'))), findsOneWidget);

      await tapKey(tester, 'extra-edit');
      await tapKey(tester, 'extra-delete');
      expect(find.text(S.deleteExtraConfirm('Thứ 7, 10/10')), findsOneWidget);
      expect(find.text('Xóa buổi tập thêm Thứ 7, 10/10?'), findsOneWidget);
      await tester.tap(find.text(S.cancel));
      await tester.pumpAndSettle();
      expect((await day(sat)).extraMuscles, [MuscleGroup.back]);

      await tapKey(tester, 'extra-delete');
      await tapKey(tester, 'extra-delete-confirm');
      final d = await day(sat);
      expect(d.extraMuscles, isNull);
      expect(d.extraLoggedAt, isNull);
      expect(find.text(S.extraNotCounted), findsNothing, reason: 'đã đóng');
      expect(inCard(find.text(S.todayRest)), findsOneWidget);
      expect(find.byKey(const ValueKey('extra-log')), findsOneWidget);
    },
  );

  testWidgets(
    'S-24 Q-2: chọn nhóm cơ rồi chạm vùng mờ → hỏi "Bỏ các thay đổi chưa '
    'lưu?"',
    (tester) async {
      await seedSetUp(db);
      await pump(tester);
      await tapKey(tester, 'extra-log');
      await tapKey(tester, 'muscle-abs');
      await tester.tapAt(const Offset(195, 60));
      await tester.pumpAndSettle();
      expect(find.text(S.discardChangesTitle), findsOneWidget);
      await tester.tap(find.text(S.discard));
      await tester.pumpAndSettle();
      expect(find.text(S.extraNotCounted), findsNothing);
      expect((await day(sat)).extraMuscles, isNull);
    },
  );

  testWidgets(
    'F05-AC6, F05-E4, F05-E6, UX-AC7: ngày tập và chủ nhật không có lựa chọn '
    'ghi buổi tập thêm',
    (tester) async {
      clock.set(DateTime(2026, 10, 9, 20));
      await seedSetUp(db);
      await pump(tester);
      expect(inCard(find.text('Vai · 18:00')), findsOneWidget);
      expect(find.byKey(const ValueKey('extra-log')), findsNothing);
      expect(find.text(S.logExtraSession), findsNothing);

      await tester.pumpWidget(const SizedBox());
      clock.set(DateTime(2026, 10, 11, 9));
      await pump(tester);
      expect(inCard(find.text(S.sundayRest)), findsOneWidget);
      expect(find.text(S.logExtraSession), findsNothing);
    },
  );

  testWidgets(
    'S-20: buổi tập thêm hiện trong dòng của ngày đó: "Nghỉ · Bụng" kèm nhãn '
    '"Buổi tập thêm"',
    (tester) async {
      await seedSetUp(db);
      await seedExtra(db, LocalDate(2026, 10, 8), const [MuscleGroup.abs]);
      await pump(tester);
      await tester.tap(
        find.descendant(
          of: find.byType(AppTabBar),
          matching: find.text(S.tabSchedule),
        ),
      );
      await tester.pumpAndSettle();
      final row = find.byKey(const ValueKey('day-2026-10-08'));
      expect(
        find.descendant(of: row, matching: find.text(S.restWithExtra('Bụng'))),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: row,
          matching: find.byKey(const ValueKey('session-tag-extra')),
        ),
        findsOneWidget,
      );
    },
  );
}
