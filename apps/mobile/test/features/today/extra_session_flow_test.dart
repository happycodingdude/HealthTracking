import 'dart:async';

import 'package:domain/domain.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/app/app.dart';
import 'package:mobile/app/strings_vi.dart';
import 'package:mobile/data/db/app_database.dart';
import 'package:mobile/features/schedule/data/schedule_repository.dart';
import 'package:mobile/features/schedule/presentation/extra_session_sheet.dart';
import 'package:mobile/features/schedule/presentation/schedule_screen.dart';
import 'package:mobile/ui/components/ironly_tab_bar.dart';

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

  Future<PlanDay> day(LocalDate date) async =>
      (await ScheduleRepository(db).day(date))!;

  Future<List<String>> outbox() async => [
    for (final o in await db.select(db.outbox).get())
      '${o.entity}:${o.entityKey}',
  ];

  Finder restCard() => find.byKey(const ValueKey('rest-card'));

  testWidgets(
    'Demo VS-24, F05-R32, F05-V21, UX-AC28: thứ 7 nghỉ → "Đã tập ngoài lịch? '
    'Ghi buổi tập thêm" → S-24 → chưa chọn nhóm cơ thì báo lỗi → chọn Bụng → '
    'Lưu → S-65 "Lưu buổi tập thêm?" (hôm nay: có dòng 2) → Hủy không lưu → '
    'Lưu → thẻ "Buổi tập thêm · Bụng" + "Đã chốt khi lưu", không có nút sửa '
    'hay xóa; ô thứ 7 của dải tiến độ là "Buổi tập thêm"',
    (tester) async {
      await seedSetUp(db);
      await pump(tester);
      expect(restCard(), findsOneWidget);
      await tapKey(tester, 'extra-log');

      // Bản 4 (04 S-24): tiêu đề ngày, không câu giải thích.
      expect(find.byKey(const ValueKey('extra-sheet')), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('extra-sheet')),
          matching: find.text('Thứ 7, 10/10'),
        ),
        findsOneWidget,
      );
      expect(find.text(S.extraNotCounted), findsNothing);
      expect(find.text(S.delete), findsNothing);

      await tapKey(tester, 'extra-save');
      expect(find.text(S.missingActualMuscles), findsOneWidget);
      expect(find.byKey(const ValueKey('lock-confirm')), findsNothing);
      expect((await day(sat)).extraMuscles, isNull);

      await tapKey(tester, 'muscle-abs');
      expect(find.text(S.missingActualMuscles), findsNothing);
      await tapKey(tester, 'extra-save');
      expect(find.text(S.extraConfirmTitle), findsOneWidget);
      expect(find.text(S.lockConfirmLine1), findsOneWidget);
      expect(find.text(S.lockConfirmLine2), findsOneWidget);
      await tapKey(tester, 'lock-confirm-cancel');
      expect((await day(sat)).extraMuscles, isNull);
      expect(find.byKey(const ValueKey('extra-sheet')), findsOneWidget);

      await tapKey(tester, 'extra-save');
      await tapKey(tester, 'lock-confirm-save');
      expect(find.text(S.extraLogged('Bụng')), findsOneWidget);
      expect(find.byKey(const ValueKey('extra-sheet')), findsNothing);
      // Hôm nay chuyển sang buổi tập thêm: dấu "+" góc trên, hàng số liệu
      // "+ Bụng", danh sách bài; không nút sửa / xóa (UR2-06).
      expect(find.byKey(const ValueKey('today-status')), findsOneWidget);
      expect(find.bySemanticsLabel(S.extraSession), findsWidgets);
      expect(find.text('+ Bụng'), findsOneWidget);
      expect(find.text(S.edit), findsNothing);
      expect(find.byKey(const ValueKey('extra-log')), findsNothing);
      expect(restCard(), findsNothing);
      await tester.tap(find.byKey(const ValueKey('tab-today-button')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('today-status')), findsOneWidget);
      final d = await day(sat);
      expect(d.extraMuscles, [MuscleGroup.abs]);
      expect(d.extraLoggedAt, DateTime(2026, 10, 10, 20));
      expect(await outbox(), ['day:2026-10-10']);
      // Không tính vào kế hoạch: các buổi theo lịch giữ nguyên.
      expect((await day(LocalDate(2026, 10, 9))).mark, isNull);
    },
  );

  testWidgets(
    'S-24 cho ngày đã qua (S-21 → "Ghi buổi tập thêm"): S-65 không có dòng 2 '
    '(UA2-02); vuốt hay chạm vùng mờ = Hủy',
    (tester) async {
      await seedSetUp(db);
      await pump(tester);
      await tester.tap(
        find.descendant(
          of: find.byType(IronlyTabBar),
          matching: find.text(S.tabTraining),
        ),
      );
      await tester.pumpAndSettle();
      // Thứ 5 08/10 nghỉ, đã qua, trong 7 ngày.
      unawaited(
        showExtraSessionSheet(
          tester.element(find.byType(ScheduleScreen)),
          LocalDate(2026, 10, 8),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('extra-sheet')),
          matching: find.text('Thứ 5, 08/10'),
        ),
        findsOneWidget,
      );
      await tapKey(tester, 'muscle-back');
      await tapKey(tester, 'extra-save');
      expect(find.text(S.lockConfirmLine1), findsOneWidget);
      expect(find.byKey(const ValueKey('lock-confirm-line2')), findsNothing);
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('lock-confirm')), findsNothing);
      expect((await day(LocalDate(2026, 10, 8))).extraMuscles, isNull);
      await tapKey(tester, 'extra-save');
      await tapKey(tester, 'lock-confirm-save');
      expect((await day(LocalDate(2026, 10, 8))).extraMuscles, [
        MuscleGroup.back,
      ]);
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
      expect(find.text('Vai · 18:00'), findsOneWidget);
      expect(find.byKey(const ValueKey('extra-log')), findsNothing);
      expect(find.text(S.logExtraSession), findsNothing);

      await tester.pumpWidget(const SizedBox());
      clock.set(DateTime(2026, 10, 11, 9));
      await pump(tester);
      expect(restCard(), findsOneWidget);
      expect(find.byKey(const ValueKey('extra-log')), findsNothing);
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
          of: find.byType(IronlyTabBar),
          matching: find.text(S.tabTraining),
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
