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
import 'package:mobile/features/workout/data/exercise_note_repository.dart';
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

/// 06 Bản 5 VS53-T05 (app): đổi bài tạm trong buổi hôm nay — S-74 (··· của
/// bài), S-75 (chọn bài, ẩn bài trong buổi), S-78 (xóa bản ghi trước khi
/// đổi), dòng bài thay (⇄ + "thay {tên gốc}"), S-63 chỉ xem (F28-AC1 → AC5,
/// FC5-04, FC5-14, J5-02 bước 3). templateAc2: thứ 2 12/10 Ngực + Tay sau
/// 18:00; giờ 18:30.
void main() {
  late AppDatabase db;
  late FixedClock clock;
  late FakeScheduler scheduler;
  late ProviderContainer container;
  late List<Exercise> library;
  late LiftLogRepository logs;
  late ExerciseNoteRepository notes;
  late SessionExerciseRepository rows;

  final mon = LocalDate(2026, 10, 12);
  final prevMon = LocalDate(2026, 10, 5);

  late Exercise pecDeck; // 1. buổi trước 40 → 45
  late Exercise bench; // 2.
  late Exercise incline; // 3.
  late Exercise decline; // 4.
  late Exercise tricepsLong;
  late Exercise backPlate; // "Máy dốc gắn bánh tạ" (lưng)
  late Exercise latPulldown;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    clock = FixedClock(DateTime(2026, 10, 12, 18, 30));
    scheduler = FakeScheduler();
    logs = LiftLogRepository(db);
    notes = ExerciseNoteRepository(db);
    rows = SessionExerciseRepository(db);
    await seedSetUp(db);
    library = await seedLibrary(db, realLibraryV3());
    final chest = [
      for (final e in library)
        if (e.group == MuscleGroup.chest) e,
    ];
    (pecDeck, bench, incline, decline) = (
      chest[0],
      chest[1],
      chest[2],
      chest[3],
    );
    tricepsLong = exerciseOf(library, MuscleRegion.tricepsLong);
    backPlate = library.firstWhere(
      (e) => e.id == 'back-back-mid-plate-loaded-row-machine',
    );
    latPulldown = library.firstWhere(
      (e) => e.id == 'lats-machine-lat-pulldown',
    );
    final units = ExerciseUnitRepository(db);
    await units.put(
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
      ..physicalSize = const Size(390 * 3, 2600 * 3)
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

  Future<void> go(WidgetTester tester, String path) async {
    container.read(routerProvider).go(path);
    await tester.pumpAndSettle();
  }

  double top(WidgetTester tester, Exercise e) =>
      tester.getTopLeft(key('lift-block-${e.id}')).dy;

  /// Thứ tự hàng mutation trong outbox (entity, key, op).
  Future<List<(String, String, String)>> outbox() async => [
    for (final o in await (db.select(
      db.outbox,
    )..orderBy([(o) => OrderingTerm.asc(o.id)])).get())
      (o.entity, o.entityKey, o.op),
  ];

  testWidgets('F28-AC1, J5-02 bước 3, UA5-01: ··· bài 2 → S-74 (Xem bài · Đổi '
      'bài) → S-75 ẩn bài trong buổi → chọn "Máy dốc gắn bánh tạ" → về S-10, '
      'dòng 2 là bài thay (⇄ + "thay …"), ba ô "—", thông báo nhanh; vẫn 4 dòng '
      'ngực theo thứ tự', (tester) async {
    await pump(tester);
    await tapKey(tester, 'exercise-${bench.id}');
    expect(key('exercise-actions'), findsOneWidget);
    expect(find.text(S.actionViewExercise), findsOneWidget);
    expect(find.text(S.actionReplace), findsOneWidget);
    expect(find.text(S.actionRestoreOriginal), findsNothing);
    expect(find.text(S.actionSkipToday), findsOneWidget);
    expect(find.text(S.actionRemoveExtra), findsOneWidget);

    await tapKey(tester, 'action-replace');
    expect(key('pick-list'), findsOneWidget);
    expect(find.text(S.actionReplace), findsWidgets);
    for (final e in [pecDeck, bench, incline, decline, tricepsLong]) {
      expect(key('pick-${e.id}'), findsNothing, reason: e.nameVi);
    }
    expect(key('pick-${backPlate.id}'), findsOneWidget);
    expect(key('pick-${latPulldown.id}'), findsOneWidget);

    await tapKey(tester, 'pick-${backPlate.id}');
    expect(key('pick-list'), findsNothing);
    expect(find.text(S.replacedTo(backPlate.nameVi)), findsOneWidget);
    expect(key('replaced-mark-${backPlate.id}'), findsOneWidget);
    expect(find.text(S.replacedFrom(bench.nameVi)), findsOneWidget);
    expect(key('lift-block-${bench.id}'), findsNothing);
    expect(tester.widget<Text>(key('lift-prev-${backPlate.id}')).data, '—');
    expect(tester.widget<Text>(key('lift-start-${backPlate.id}')).data, '—');
    expect(top(tester, pecDeck), lessThan(top(tester, backPlate)));
    expect(top(tester, backPlate), lessThan(top(tester, incline)));
    expect(top(tester, incline), lessThan(top(tester, decline)));

    expect(await rows.day(mon), [
      SessionExerciseRow(
        date: mon,
        exerciseId: backPlate.id,
        role: SessionExerciseRole.replacement,
        replacesExerciseId: bench.id,
        position: 1,
      ),
    ]);
    expect(
      await outbox(),
      contains(('session_exercise', '2026-10-12:${backPlate.id}', 'upsert')),
    );
  });

  testWidgets('F28-AC2, F28-E2, F21-R62: bài thay chưa từng ghi → chọn đơn vị '
      'như lần đầu; ghi 20 → 25 kg → bản ghi thuộc bài thay, bài gốc không '
      'có', (tester) async {
    await pump(tester);
    await container.read(replaceExerciseProvider)(mon, bench.id, backPlate.id);
    await tester.pumpAndSettle();
    await tapKey(tester, 'lift-row-${backPlate.id}');
    expect(key('lift-unit-bar'), findsOneWidget);
    await tapKey(tester, 'lift-unit-kg');
    await tester.enterText(key('field-lift-start'), '20');
    await tester.enterText(key('field-lift-end'), '25');
    await tester.pumpAndSettle();
    await tapKey(tester, 'lift-save');
    final log = await logs.get(mon, backPlate.id);
    expect((log?.startKgX10, log?.endKgX10), (200, 250));
    expect(await logs.get(mon, bench.id), isNull);
    expect(tester.widget<Text>(key('lift-end-${backPlate.id}')).data, '25');
  });

  testWidgets('F28-AC4, F28-R5, FC5-14: bài 1 đã ghi 40 → 45 + ghi chú → Đổi '
      'bài → S-78 câu cố định; Hủy → không đổi gì; Xóa và đổi bài → S-75 → '
      'chọn → bản ghi không còn ở đâu; outbox lift_log → exercise_note → '
      'session_exercise', (tester) async {
    await logs.put(
      LiftLog(
        date: mon,
        exerciseId: pecDeck.id,
        startKgX10: 400,
        endKgX10: 450,
      ),
    );
    await notes.put(
      ExerciseNote(date: mon, exerciseId: pecDeck.id, text: 'Ghế nấc 3'),
    );
    await pump(tester);
    await tapKey(tester, 'exercise-${pecDeck.id}');
    await tapKey(tester, 'action-replace');
    expect(key('records-delete-replace'), findsOneWidget);
    expect(find.text(S.replaceConfirmTitle), findsOneWidget);
    expect(find.text(S.recordsDeleteBody), findsOneWidget);
    expect(find.text(S.replaceConfirmAction), findsOneWidget);
    await tester.tap(find.byKey(K.dialogSecondary));
    await tester.pumpAndSettle();
    expect(key('pick-list'), findsNothing);
    expect(await logs.get(mon, pecDeck.id), isNotNull);
    expect(await outbox(), isEmpty);

    await tapKey(tester, 'exercise-${pecDeck.id}');
    await tapKey(tester, 'action-replace');
    await tapKey(tester, 'records-delete-confirm');
    expect(key('pick-list'), findsOneWidget);
    await tapKey(tester, 'pick-${latPulldown.id}');
    expect(await logs.get(mon, pecDeck.id), isNull);
    expect(await notes.get(mon, pecDeck.id), isNull);
    expect(key('lift-block-${pecDeck.id}'), findsNothing);
    expect(key('replaced-mark-${latPulldown.id}'), findsOneWidget);
    final key1 = '2026-10-12:${pecDeck.id}';
    expect(await outbox(), [
      ('lift_log', key1, 'delete'),
      ('exercise_note', key1, 'delete'),
      ('session_exercise', '2026-10-12:${latPulldown.id}', 'upsert'),
    ]);
  });

  testWidgets('F28-R6, FC5-04: bài thay có "Chọn lại bài gốc"; đổi tiếp — S-75 '
      'ẩn bài gốc đang bị thay và bài thay; chọn lại bài gốc → bài gốc về chỗ, '
      'không còn dòng nào', (tester) async {
    await pump(tester);
    await container.read(replaceExerciseProvider)(mon, bench.id, backPlate.id);
    await tester.pumpAndSettle();
    await tapKey(tester, 'exercise-${backPlate.id}');
    expect(find.text(S.actionRestoreOriginal), findsOneWidget);
    await tapKey(tester, 'action-replace');
    expect(key('pick-${bench.id}'), findsNothing);
    expect(key('pick-${backPlate.id}'), findsNothing);
    await tapKey(tester, 'pick-${latPulldown.id}');
    expect(key('replaced-mark-${latPulldown.id}'), findsOneWidget);
    expect(find.text(S.replacedFrom(bench.nameVi)), findsOneWidget);
    expect(key('lift-block-${backPlate.id}'), findsNothing);
    expect(
      [for (final r in await rows.day(mon)) r.exerciseId],
      [latPulldown.id],
    );

    await tapKey(tester, 'exercise-${latPulldown.id}');
    await tapKey(tester, 'action-restore');
    expect(key('lift-block-${bench.id}'), findsOneWidget);
    expect(key('replaced-mark-${latPulldown.id}'), findsNothing);
    expect(await rows.day(mon), isEmpty);
    expect(
      () =>
          container.read(replaceExerciseProvider)(mon, incline.id, pecDeck.id),
      throwsA(
        isA<SessionEditException>().having(
          (e) => e.error,
          'error',
          SessionEditError.notPickable,
        ),
      ),
    );
  });

  testWidgets('F28-AC5, BR5-13: "Đã tập" → S-74 chỉ Xem bài sáng, Đổi bài mờ; '
      'bỏ "Đã tập" → Đổi bài sáng lại; sau 00:00 → S-63 chỉ xem: bài thay có '
      '⇄ + tên gốc, không ···, chạm tên → S-67', (tester) async {
    await pump(tester);
    await container.read(replaceExerciseProvider)(mon, bench.id, backPlate.id);
    await seedMark(db, mon, DayMark.done);
    await tester.pumpAndSettle();
    await tapKey(tester, 'exercise-${pecDeck.id}');
    double opacity(String k) => tester
        .widget<Opacity>(
          find.descendant(of: key(k), matching: find.byType(Opacity)).first,
        )
        .opacity;
    expect(opacity('action-view'), 1);
    expect(opacity('action-replace'), 0.4);
    await tester.tap(key('action-replace'));
    await tester.pumpAndSettle();
    expect(key('pick-list'), findsNothing);
    await tester.tapAt(const Offset(195, 100));
    await tester.pumpAndSettle();

    final schedule = ScheduleRepository(db);
    final d = (await schedule.day(mon))!;
    await schedule.putDay(d.withMark(null));
    await tester.pumpAndSettle();
    await tapKey(tester, 'exercise-${pecDeck.id}');
    expect(opacity('action-replace'), 1);
    await tester.tapAt(const Offset(195, 100));
    await tester.pumpAndSettle();

    clock.set(DateTime(2026, 10, 13, 0, 1));
    scheduler.fireSync();
    await tester.pumpAndSettle();
    await go(tester, sessionPath(AppTab.today, mon));
    expect(key('replaced-mark-${backPlate.id}'), findsOneWidget);
    expect(find.text(S.replacedFrom(bench.nameVi)), findsOneWidget);
    expect(key('more-${pecDeck.id}'), findsNothing);
    await tapKey(tester, 'exercise-${pecDeck.id}');
    expect(key('exercise-actions'), findsNothing);
    expect(
      () => container.read(replaceExerciseProvider)(
        mon,
        incline.id,
        latPulldown.id,
      ),
      throwsA(isA<SessionEditException>()),
    );
  });
}
