import 'package:domain/domain.dart';
import 'package:drift/drift.dart' show OrderingTerm;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/app/app.dart';
import 'package:mobile/app/router.dart';
import 'package:mobile/app/shell/app_tab.dart';
import 'package:mobile/app/strings_vi.dart';
import 'package:mobile/data/db/app_database.dart' hide ExerciseRow;
import 'package:mobile/features/library/data/video_player_gateway.dart';
import 'package:mobile/features/schedule/data/schedule_repository.dart';
import 'package:mobile/features/workout/application/session_item_edits.dart';
import 'package:mobile/features/workout/data/exercise_unit_repository.dart';
import 'package:mobile/features/workout/data/lift_log_repository.dart';
import 'package:mobile/features/workout/data/session_exercise_repository.dart';
import 'package:mobile/features/workout/presentation/session_screen.dart';
import 'package:mobile/ui/keys.dart';

import '../../support/app_harness.dart';
import '../../support/fake_server.dart';
import '../../support/fake_sync.dart';
import '../../support/library_fixture.dart';
import '../../support/schedule_fixture.dart';

/// 06 Bản 5 VS54-T05 (app): bỏ qua bài, thêm bài lẻ, xóa bài thêm, S-79,
/// "Đã ghi n / m", "+ Thêm bài" (F29-AC1 → AC5, F30-AC1 → AC5, F20-AC61,
/// F20-AC63, FC5-03, FC5-05, FC5-14; J5-02 bước 5 → 7). templateAc2: thứ 2
/// 12/10 Ngực + Tay sau 18:00; giờ 18:30.
void main() {
  late AppDatabase db;
  late FixedClock clock;
  late FakeScheduler scheduler;
  late ProviderContainer container;
  late List<Exercise> library;
  late LiftLogRepository logs;
  late SessionExerciseRepository rows;

  final mon = LocalDate(2026, 10, 12);
  final prevMon = LocalDate(2026, 10, 5);

  late List<Exercise> session; // bài gốc theo thứ tự (Ngực rồi Tay sau)
  late Exercise pecDeck; // 1. buổi trước 40 → 45
  late Exercise decline; // 4.
  late Exercise plank;
  late Exercise legPress;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    clock = FixedClock(DateTime(2026, 10, 12, 18, 30));
    scheduler = FakeScheduler();
    logs = LiftLogRepository(db);
    rows = SessionExerciseRepository(db);
    await seedSetUp(db);
    library = await seedLibrary(db, realLibraryV3());
    session = [
      for (final g in const [MuscleGroup.chest, MuscleGroup.triceps])
        for (final e in library)
          if (e.group == g && e.active) e,
    ];
    pecDeck = session[0];
    decline = session[3];
    plank = exerciseOf(library, MuscleRegion.absMid);
    legPress = library.firstWhere((e) => e.id == 'legs-quads-leg-press');
    await ExerciseUnitRepository(db).put(
      ExerciseUnit(
        exerciseId: pecDeck.id,
        unit: LiftUnit.kg,
        changedOn: prevMon,
      ),
    );
    await logs.put(
      LiftLog(
        date: prevMon,
        exerciseId: pecDeck.id,
        startKgX10: 400,
        endKgX10: 450,
      ),
    );
  });

  Future<void> pump(WidgetTester tester) async {
    tester.view
      ..physicalSize = const Size(390 * 3, 3400 * 3)
      ..devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    container = ProviderContainer(
      retry: (_, _) => null,
      overrides: [
        ...appOverrides(
          db: db,
          clock: clock,
          scheduler: scheduler,
          server: FakeServer(),
        ),
        videoPlayerGatewayProvider.overrideWithValue(FakeVideoGateway()),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const IronlyApp()),
    );
    await tester.pumpAndSettle();
  }

  Finder key(String k) => find.byKey(ValueKey(k), skipOffstage: false);

  Future<void> tapKey(WidgetTester tester, String k) async {
    await tester.ensureVisible(key(k).last);
    await tester.pumpAndSettle();
    await tester.tap(key(k).last);
    await tester.pumpAndSettle();
  }

  String stat(WidgetTester tester) =>
      tester.widget<Text>(key('stat-logged')).data!;

  double top(WidgetTester tester, String k) => tester.getTopLeft(key(k)).dy;

  double opacity(WidgetTester tester, String k) => tester
      .widget<Opacity>(
        find.descendant(of: key(k), matching: find.byType(Opacity)).first,
      )
      .opacity;

  Future<void> closeSheet(WidgetTester tester) async {
    await tester.tapAt(const Offset(195, 100));
    await tester.pumpAndSettle();
  }

  Future<List<(String, String, String)>> outbox() async => [
    for (final o in await (db.select(
      db.outbox,
    )..orderBy([(o) => OrderingTerm.asc(o.id)])).get())
      (o.entity, o.entityKey, o.op),
  ];

  testWidgets('F29-AC1, J5-02 bước 5, UD5-02: ··· bài 4 → "Bỏ qua hôm nay" → '
      'tên gạch ngang, vòng gạch, không hàng số, thông báo nhanh; "Đã ghi 0 / '
      'm−1"; S-74 bài bỏ qua có "Hủy bỏ qua" → về bình thường', (tester) async {
    await pump(tester);
    final total = session.where((e) => e.logsWeight).length;
    expect(stat(tester), S.ratio(0, total));
    await tapKey(tester, 'exercise-${decline.id}');
    expect(opacity(tester, 'action-skip'), 1);
    expect(opacity(tester, 'action-remove-extra'), 0.4);
    await tapKey(tester, 'action-skip');
    expect(find.text(S.skippedExercise(decline.nameVi)), findsOneWidget);
    expect(key('skipped-mark-${decline.id}'), findsOneWidget);
    expect(key('lift-row-${decline.id}'), findsNothing);
    final name = tester.widget<Text>(key('exercise-name-${decline.id}'));
    expect(name.style?.decoration, TextDecoration.lineThrough);
    expect(stat(tester), S.ratio(0, total - 1));
    expect(await rows.day(mon), [
      SessionExerciseRow(
        date: mon,
        exerciseId: decline.id,
        role: SessionExerciseRole.original,
        position: 3,
        skipped: true,
      ),
    ]);

    await tapKey(tester, 'exercise-${decline.id}');
    expect(find.text(S.actionUnskip), findsOneWidget);
    await tapKey(tester, 'action-skip');
    expect(key('skipped-mark-${decline.id}'), findsNothing);
    expect(key('lift-row-${decline.id}'), findsOneWidget);
    expect(stat(tester), S.ratio(0, total));
    expect(await rows.day(mon), isEmpty);
  });

  testWidgets('F29-AC3, FC5-14: bài đã ghi 40 → 45 → "Bỏ qua" → S-78 "Bỏ qua '
      'bài?"; Hủy → không đổi gì; Xóa và bỏ qua → bản ghi không còn, outbox '
      'lift_log → session_exercise', (tester) async {
    await logs.put(
      LiftLog(
        date: mon,
        exerciseId: pecDeck.id,
        startKgX10: 400,
        endKgX10: 450,
      ),
    );
    await pump(tester);
    await tapKey(tester, 'exercise-${pecDeck.id}');
    await tapKey(tester, 'action-skip');
    expect(key('records-delete-skip'), findsOneWidget);
    expect(find.text(S.skipConfirmTitle), findsOneWidget);
    expect(find.text(S.recordsDeleteBody), findsOneWidget);
    expect(find.text(S.skipConfirmAction), findsOneWidget);
    await tester.tap(find.byKey(K.dialogSecondary));
    await tester.pumpAndSettle();
    expect(await logs.get(mon, pecDeck.id), isNotNull);
    expect(key('skipped-mark-${pecDeck.id}'), findsNothing);
    expect(await outbox(), isEmpty);

    await tapKey(tester, 'exercise-${pecDeck.id}');
    await tapKey(tester, 'action-skip');
    await tapKey(tester, 'records-delete-confirm');
    expect(await logs.get(mon, pecDeck.id), isNull);
    expect(key('skipped-mark-${pecDeck.id}'), findsOneWidget);
    final k = '2026-10-12:${pecDeck.id}';
    expect(await outbox(), [
      ('lift_log', k, 'delete'),
      ('session_exercise', k, 'upsert'),
    ]);
  });

  testWidgets('F29-AC2, FC5-03, S-79: bỏ qua mọi bài → "Đã tập" → hộp "Mọi '
      'bài đã bỏ qua. Buổi sẽ ghi là Không tập." → Lưu → buổi Không tập (H6), '
      '"Đã ghi: không tập"', (tester) async {
    await pump(tester);
    for (final e in session) {
      await container.read(skipExerciseProvider)(mon, e.id, skipped: true);
    }
    await tester.pumpAndSettle();
    await tapKey(tester, 'today-mark-done');
    expect(key('lock-confirm'), findsOneWidget);
    expect(find.text(S.allSkippedBody), findsOneWidget);
    expect(find.text(S.doneConfirmBody), findsNothing);
    await tapKey(tester, 'lock-confirm-save');
    expect((await ScheduleRepository(db).day(mon))?.mark, DayMark.skipped);
    expect(find.text(S.markedSkipped), findsOneWidget);
    expect(key('today-status'), findsOneWidget);
  });

  testWidgets('F29-E1: bỏ qua 3 / 4 bài Ngực → "Đã tập" vẫn hộp S-65 thường, '
      'lưu "Đã tập"', (tester) async {
    await pump(tester);
    for (final e in session.skip(1)) {
      await container.read(skipExerciseProvider)(mon, e.id, skipped: true);
    }
    await tester.pumpAndSettle();
    expect(stat(tester), S.ratio(0, 1));
    await tapKey(tester, 'today-mark-done');
    expect(find.text(S.doneConfirmBody), findsOneWidget);
    await tapKey(tester, 'lock-confirm-save');
    expect((await ScheduleRepository(db).day(mon))?.mark, DayMark.done);
  });

  testWidgets('F30-AC1, F30-AC3, J5-02 bước 6, UD5-05: "+ Thêm bài" → S-75 '
      '"Thêm bài" ẩn bài của buổi → chọn Plank → dòng cuối có "+", chỉ ghi '
      'chú; S-75 lần sau ẩn cả Plank', (tester) async {
    await pump(tester);
    expect(key('add-exercise'), findsOneWidget);
    await tapKey(tester, 'add-exercise');
    expect(key('pick-list'), findsOneWidget);
    expect(find.text(S.pickAddTitle), findsOneWidget);
    for (final e in session) {
      expect(key('pick-${e.id}'), findsNothing, reason: e.nameVi);
    }
    await tapKey(tester, 'pick-${plank.id}');
    expect(key('pick-list'), findsNothing);
    expect(find.text(S.addedExercise(plank.nameVi)), findsOneWidget);
    expect(key('extra-mark-${plank.id}'), findsOneWidget);
    expect(key('lift-row-${plank.id}'), findsNothing);
    final last = session.last;
    expect(
      top(tester, 'lift-block-${last.id}'),
      lessThan(top(tester, 'lift-block-${plank.id}')),
    );
    expect(
      top(tester, 'lift-block-${plank.id}'),
      lessThan(top(tester, 'add-exercise')),
    );

    await tapKey(tester, 'add-exercise');
    expect(key('pick-${plank.id}'), findsNothing);
    await tapKey(tester, 'pick-${legPress.id}');
    expect(
      top(tester, 'lift-block-${plank.id}'),
      lessThan(top(tester, 'lift-block-${legPress.id}')),
    );
    expect(
      [for (final r in await rows.day(mon)) (r.exerciseId, r.role, r.position)],
      unorderedEquals([
        (plank.id, SessionExerciseRole.extra, 0),
        (legPress.id, SessionExerciseRole.extra, 1),
      ]),
    );
  });

  testWidgets('F30-AC2, F30-R6: thêm "Nằm máy đạp chân", ghi 8 → 10 nấc → bản '
      'ghi thuộc bài thêm; lịch tuần, nhóm cơ buổi không đổi; "Đã ghi" tính '
      'cả bài thêm', (tester) async {
    await pump(tester);
    final total = session.where((e) => e.logsWeight).length;
    await container.read(addExtraExerciseProvider)(mon, legPress.id);
    await tester.pumpAndSettle();
    expect(stat(tester), S.ratio(0, total + 1));
    await tapKey(tester, 'lift-row-${legPress.id}');
    await tapKey(tester, 'lift-unit-steps');
    await tester.enterText(key('field-lift-start'), '8');
    await tester.enterText(key('field-lift-end'), '10');
    await tester.pumpAndSettle();
    await tapKey(tester, 'lift-save');
    final log = await logs.get(mon, legPress.id);
    expect((log?.startKgX10, log?.endKgX10), (80, 100));
    expect(stat(tester), S.ratio(1, total + 1));
    final day = (await ScheduleRepository(db).day(mon))!;
    expect(day.muscles, const [MuscleGroup.chest, MuscleGroup.triceps]);
  });

  testWidgets('F30-AC5, F30-R5: bài thêm đã ghi tạ → "Xóa bài thêm" → S-78 '
      '"Xóa bài thêm?" · "Xóa bài" → dòng và bản ghi cùng mất; bài thêm chưa '
      'ghi → xóa ngay', (tester) async {
    await pump(tester);
    await container.read(addExtraExerciseProvider)(mon, legPress.id);
    await container.read(addExtraExerciseProvider)(mon, plank.id);
    await logs.put(
      LiftLog(
        date: mon,
        exerciseId: legPress.id,
        startKgX10: 80,
        endKgX10: 100,
      ),
    );
    await tester.pumpAndSettle();
    await tapKey(tester, 'exercise-${legPress.id}');
    expect(find.text(S.actionReplace), findsNothing);
    expect(opacity(tester, 'action-remove-extra'), 1);
    await tapKey(tester, 'action-remove-extra');
    expect(key('records-delete-remove-extra'), findsOneWidget);
    expect(find.text(S.removeExtraConfirmTitle), findsOneWidget);
    expect(find.text(S.removeExtraConfirmAction), findsOneWidget);
    await tapKey(tester, 'records-delete-confirm');
    expect(key('lift-block-${legPress.id}'), findsNothing);
    expect(await logs.get(mon, legPress.id), isNull);

    await tapKey(tester, 'exercise-${plank.id}');
    await tapKey(tester, 'action-remove-extra');
    expect(key('records-delete-remove-extra'), findsNothing);
    expect(key('lift-block-${plank.id}'), findsNothing);
    expect(await rows.day(mon), isEmpty);
  });

  testWidgets('F30-AC4, F30-R1: ngày nghỉ → không có "+ Thêm bài"; buổi tập '
      'thêm → không có', (tester) async {
    clock.set(DateTime(2026, 10, 13, 18, 30));
    await pump(tester);
    expect(key('add-exercise'), findsNothing);
    await seedExtra(db, LocalDate(2026, 10, 13), const [MuscleGroup.back]);
    await tester.pumpAndSettle();
    expect(key('session-log-list'), findsOneWidget);
    expect(key('add-exercise'), findsNothing);
    expect(
      () => container.read(addExtraExerciseProvider)(
        LocalDate(2026, 10, 13),
        plank.id,
      ),
      throwsA(isA<SessionEditException>()),
    );
  });

  testWidgets('F20-AC63, BR5-13: "Đã tập" → "+ Thêm bài" mờ; S-74 Bỏ qua / Xóa '
      'mờ; S-63 hôm sau chỉ xem bài bỏ qua (gạch ngang) và bài thêm ("+"), '
      'không "+ Thêm bài"', (tester) async {
    await pump(tester);
    await container.read(skipExerciseProvider)(mon, decline.id, skipped: true);
    await container.read(addExtraExerciseProvider)(mon, plank.id);
    await seedMark(db, mon, DayMark.done);
    await tester.pumpAndSettle();
    expect(opacity(tester, 'add-exercise'), 0.4);
    await tapKey(tester, 'add-exercise');
    expect(key('pick-list'), findsNothing);
    await tapKey(tester, 'exercise-${plank.id}');
    expect(opacity(tester, 'action-skip'), 0.4);
    expect(opacity(tester, 'action-remove-extra'), 0.4);
    await closeSheet(tester);
    expect(
      () =>
          container.read(skipExerciseProvider)(mon, pecDeck.id, skipped: true),
      throwsA(isA<SessionEditException>()),
    );

    clock.set(DateTime(2026, 10, 13, 0, 1));
    scheduler.fireSync();
    await tester.pumpAndSettle();
    container.read(routerProvider).go(sessionPath(AppTab.today, mon));
    await tester.pumpAndSettle();
    expect(key('skipped-mark-${decline.id}'), findsOneWidget);
    expect(key('extra-mark-${plank.id}'), findsOneWidget);
    expect(key('add-exercise'), findsNothing);
    expect(key('more-${plank.id}'), findsNothing);
  });
}
