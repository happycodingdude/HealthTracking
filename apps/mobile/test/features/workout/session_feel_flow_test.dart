import 'package:domain/domain.dart';
import 'package:drift/drift.dart' show OrderingTerm;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/app/app.dart';
import 'package:mobile/app/strings_vi.dart';
import 'package:mobile/core/formatters.dart';
import 'package:mobile/data/db/app_database.dart' hide ExerciseRow;
import 'package:mobile/data/sync/outbox_writer.dart';
import 'package:mobile/features/library/data/exercise_repository.dart';
import 'package:mobile/features/library/data/video_player_gateway.dart';
import 'package:mobile/features/schedule/data/schedule_repository.dart';
import 'package:mobile/features/workout/application/lift_log_edits.dart';
import 'package:mobile/features/workout/data/exercise_feel_repository.dart';
import 'package:mobile/features/workout/data/exercise_unit_repository.dart';
import 'package:mobile/features/workout/data/lift_log_repository.dart';
import 'package:mobile/features/workout/data/session_exercise_repository.dart';
import 'package:mobile/ui/components/components.dart';

import '../../support/app_harness.dart';
import '../../support/fake_server.dart';
import '../../support/fake_sync.dart';
import '../../support/library_fixture.dart';
import '../../support/schedule_fixture.dart';

/// 06 Bản 5 VS55-T03 → T05 (app): mức thoải mái set cuối trong S-64, dấu ba
/// vạch cam / xám ở Hôm nay (F33-AC1 → AC6, F20-AC62, F21-AC61, F33-E3,
/// F33-E5; J5-02 bước 2, 4, 6). templateAc2: thứ 2 12/10 Ngực + Tay sau
/// 18:00; giờ 18:30; buổi trước thứ 2 05/10.
void main() {
  late AppDatabase db;
  late FixedClock clock;
  late FakeScheduler scheduler;
  late ProviderContainer container;
  late List<Exercise> library;
  late LiftLogRepository logs;
  late ExerciseFeelRepository feels;

  final mon = LocalDate(2026, 10, 12);
  final prevMon = LocalDate(2026, 10, 5);

  late List<Exercise> session;
  late Exercise pecDeck; // buổi trước 40 → 45 · Mệt
  late Exercise flat; // buổi trước 50 → 55, không chọn mức
  late Exercise incline; // chưa từng ghi
  late Exercise plank;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    clock = FixedClock(DateTime(2026, 10, 12, 18, 30));
    scheduler = FakeScheduler();
    logs = LiftLogRepository(db);
    feels = ExerciseFeelRepository(db);
    await seedSetUp(db);
    library = await seedLibrary(db, realLibraryV3());
    session = [
      for (final g in const [MuscleGroup.chest, MuscleGroup.triceps])
        for (final e in library)
          if (e.group == g && e.active) e,
    ];
    pecDeck = session[0];
    flat = session[1];
    incline = session[2];
    plank = exerciseOf(library, MuscleRegion.absMid);
    for (final e in [pecDeck, flat]) {
      await ExerciseUnitRepository(db).put(
        ExerciseUnit(exerciseId: e.id, unit: LiftUnit.kg, changedOn: prevMon),
      );
    }
    await logs.put(
      LiftLog(
        date: prevMon,
        exerciseId: pecDeck.id,
        startKgX10: 400,
        endKgX10: 450,
      ),
    );
    await logs.put(
      LiftLog(
        date: prevMon,
        exerciseId: flat.id,
        startKgX10: 500,
        endKgX10: 550,
      ),
    );
    await feels.put(
      ExerciseFeel(date: prevMon, exerciseId: pecDeck.id, feel: Feel.hard),
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

  Future<void> dismissSheet(WidgetTester tester) async {
    await tester.tapAt(const Offset(20, 20));
    await tester.pumpAndSettle();
  }

  /// Số vạch sáng của dấu [k] (1 / 2 / 3 = Thoải mái / Vừa / Mệt).
  int lit(WidgetTester tester, String k) => find
      .descendant(
        of: key(k),
        matching: find.byWidgetPredicate(
          (w) =>
              w.key is ValueKey<String> &&
              (w.key! as ValueKey<String>).value.endsWith('-on'),
        ),
      )
      .evaluate()
      .length;

  bool isPrevious(WidgetTester tester, String k) =>
      tester.widget<FeelGlyph>(key(k)).previous;

  Feel? selected(WidgetTester tester) =>
      tester.widget<SegmentBar<Feel>>(key('lift-feel-bar')).selected;

  Future<List<(String, String, String)>> outbox() async => [
    for (final o in await (db.select(
      db.outbox,
    )..orderBy([(o) => OrderingTerm.asc(o.id)])).get())
      (o.entity, o.entityKey, o.op),
  ];

  testWidgets(
    'F20-AC62, F33-AC2, U5-AC4, F21-AC61, J5-02 bước 2: buổi trước 40 → 45 '
    '· Mệt → ô BUỔI TRƯỚC có 3 vạch xám; S-64 cạnh "Kết thúc" 3 vạch xám, '
    'thanh chọn trống; +bước, chọn Vừa, Lưu → 40 → 47,5 · 2 vạch cam sau '
    'tên',
    (tester) async {
      await pump(tester);
      expect(key('feel-previous-${pecDeck.id}'), findsOneWidget);
      expect(isPrevious(tester, 'feel-previous-${pecDeck.id}'), isTrue);
      expect(lit(tester, 'feel-previous-${pecDeck.id}'), 3);
      // F33-AC3: buổi trước không chọn mức → không dấu.
      expect(key('feel-previous-${flat.id}'), findsNothing);
      expect(key('feel-today-${pecDeck.id}'), findsNothing);
      expect(
        find.bySemanticsLabel(RegExp(S.feelPrevious(S.feelHard))),
        findsOneWidget,
      );

      await tapKey(tester, 'lift-row-${pecDeck.id}');
      expect(key('lift-previous-feel'), findsOneWidget);
      expect(isPrevious(tester, 'lift-previous-feel'), isTrue);
      expect(lit(tester, 'lift-previous-feel'), 3);
      expect(selected(tester), isNull);
      expect(find.text(S.feelEasy), findsOneWidget);
      expect(find.text(S.feelMedium), findsOneWidget);
      expect(find.text(S.feelHard), findsOneWidget);
      await tapKey(tester, 'lift-end-plus');
      await tapKey(tester, 'lift-feel-medium');
      expect(selected(tester), Feel.medium);
      await tapKey(tester, 'lift-save');

      final log = await logs.get(mon, pecDeck.id);
      expect((log?.startKgX10, log?.endKgX10), (400, 475));
      expect((await feels.get(mon, pecDeck.id))?.feel, Feel.medium);
      expect(key('feel-today-${pecDeck.id}'), findsOneWidget);
      expect(isPrevious(tester, 'feel-today-${pecDeck.id}'), isFalse);
      expect(lit(tester, 'feel-today-${pecDeck.id}'), 2);
      // Đã ghi buổi này: ô BUỔI TRƯỚC không còn dấu xám.
      expect(key('feel-previous-${pecDeck.id}'), findsNothing);
      expect(
        find.text(S.liftSaved('40', '47,5', Fmt.liftUnit(LiftUnit.kg))),
        findsOneWidget,
      );
      // Một lần Lưu: mức tạ rồi mức thoải mái, cùng outbox (F21-R61).
      expect(await outbox(), [
        ('lift_log', LiftLog.keyOf(mon, pecDeck.id), 'upsert'),
        ('exercise_feel', ExerciseFeel.keyOf(mon, pecDeck.id), 'upsert'),
      ]);
    },
  );

  testWidgets('F33-AC1, F33-AC4, F33-R1, F33-AC6: Lưu 40 → 45 với Thoải mái → '
      '1 vạch cam; Chi tiết bài / Tiến bộ không có dấu; sửa Kết thúc 47,5 → '
      'vẫn Thoải mái; chạm lại mục đang chọn → bỏ chọn → tombstone, mất dấu', (
    tester,
  ) async {
    await pump(tester);
    await tapKey(tester, 'lift-row-${pecDeck.id}');
    await tapKey(tester, 'lift-feel-easy');
    await tapKey(tester, 'lift-save');
    expect(lit(tester, 'feel-today-${pecDeck.id}'), 1);
    expect(
      find.bySemanticsLabel(RegExp('${pecDeck.nameVi}.*${S.feelEasy}')),
      findsOneWidget,
    );

    await tapKey(tester, 'lift-row-${pecDeck.id}');
    expect(selected(tester), Feel.easy);
    await tapKey(tester, 'lift-end-plus');
    await tapKey(tester, 'lift-save');
    expect((await logs.get(mon, pecDeck.id))?.endKgX10, 475);
    expect((await feels.get(mon, pecDeck.id))?.feel, Feel.easy);
    expect(lit(tester, 'feel-today-${pecDeck.id}'), 1);

    await tapKey(tester, 'lift-row-${pecDeck.id}');
    await tapKey(tester, 'lift-feel-easy');
    expect(selected(tester), isNull);
    await tapKey(tester, 'lift-save');
    expect(await feels.get(mon, pecDeck.id), isNull);
    expect(key('feel-today-${pecDeck.id}'), findsNothing);
    expect((await outbox()).last, (
      'exercise_feel',
      ExerciseFeel.keyOf(mon, pecDeck.id),
      'delete',
    ));

    // F33-R6: Chi tiết bài (Tiến bộ, biểu đồ) không hiện mức thoải mái.
    await tapKey(tester, 'lift-row-${pecDeck.id}');
    await tapKey(tester, 'lift-feel-hard');
    await tapKey(tester, 'lift-save');
    expect(key('feel-today-${pecDeck.id}'), findsOneWidget);
    await tapKey(tester, 'exercise-${pecDeck.id}');
    await tapKey(tester, 'action-view');
    expect(find.text(pecDeck.nameVi), findsWidgets);
    expect(find.byType(FeelGlyph), findsNothing);
  });

  testWidgets('04 Bản 5 S-64: hai ô trống mà chọn mức → chỉ lưu mức thoải mái '
      '(không lỗi chọn đơn vị); đổi mức rồi đóng → đóng ngay, không hỏi, mức '
      'không lưu (Bạn yêu cầu 06/11/2026)', (tester) async {
    await pump(tester);
    await tapKey(tester, 'lift-row-${incline.id}');
    await tapKey(tester, 'lift-feel-hard');
    await dismissSheet(tester);
    expect(find.text(S.discardChanges), findsNothing);
    expect(key('lift-save'), findsNothing);
    expect(await feels.get(mon, incline.id), isNull);
    await tapKey(tester, 'lift-row-${incline.id}');
    await tapKey(tester, 'lift-feel-hard');
    expect(selected(tester), Feel.hard);
    await tapKey(tester, 'lift-save');
    expect(key('lift-error'), findsNothing);
    expect(key('lift-save'), findsNothing);
    expect(await logs.get(mon, incline.id), isNull);
    expect((await feels.get(mon, incline.id))?.feel, Feel.hard);
    expect(lit(tester, 'feel-today-${incline.id}'), 3);
    expect(await outbox(), [
      ('exercise_feel', ExerciseFeel.keyOf(mon, incline.id), 'upsert'),
    ]);
  });

  testWidgets('F33-E3, F33-R3: chọn Mệt rồi "Xóa mức tạ" → mức thoải mái còn; '
      'dòng quay về mức buổi trước, dấu cam sau tên vẫn còn', (tester) async {
    await pump(tester);
    await tapKey(tester, 'lift-row-${flat.id}');
    await tapKey(tester, 'lift-feel-hard');
    await tapKey(tester, 'lift-save');
    expect(await logs.get(mon, flat.id), isNotNull);

    await tapKey(tester, 'lift-row-${flat.id}');
    await tapKey(tester, 'lift-delete');
    await tapKey(tester, 'lift-delete-confirm-ok');
    expect(await logs.get(mon, flat.id), isNull);
    expect((await feels.get(mon, flat.id))?.feel, Feel.hard);
    expect(key('feel-today-${flat.id}'), findsOneWidget);
    expect(tester.widget<Text>(key('lift-prev-${flat.id}')).data, '50 → 55');
  });

  testWidgets('F33-E5, FC5-05, J5-02 bước 6: bài bụng thêm (Plank) → S-64 chỉ '
      'thanh ba mức + ghi chú; chọn Mệt + "60 giây" → lưu cả hai', (
    tester,
  ) async {
    await SessionExerciseRepository(db).put(
      SessionExerciseRow(
        date: mon,
        exerciseId: plank.id,
        role: SessionExerciseRole.extra,
        position: session.length,
      ),
    );
    await pump(tester);
    await tapKey(tester, 'note-mark-${plank.id}-none');
    expect(key('lift-box-start'), findsNothing);
    expect(key('lift-feel-bar'), findsOneWidget);
    expect(key('lift-previous-feel'), findsNothing);
    await tapKey(tester, 'lift-feel-hard');
    await tester.enterText(key('note-input'), '60 giây');
    await tester.pumpAndSettle();
    await tapKey(tester, 'lift-save');
    expect((await feels.get(mon, plank.id))?.feel, Feel.hard);
    expect(find.text('60 giây'), findsOneWidget);
    expect(lit(tester, 'feel-today-${plank.id}'), 3);
  });

  test(
    'F33-AC5: sau 00:00 không chọn / đổi được (cửa sổ ghi tạ đóng)',
    () async {
      clock = FixedClock(DateTime(2026, 10, 13, 0, 1));
      final save = SaveExerciseFeel(
        db: db,
        feels: feels,
        schedule: ScheduleRepository(db),
        exercises: ExerciseRepository(db),
        outbox: OutboxWriter(db, clock),
        clock: clock,
        sessionRows: SessionExerciseRepository(db),
      );
      await expectLater(
        save(mon, pecDeck.id, Feel.easy),
        throwsA(
          isA<LiftException>().having(
            (e) => e.error,
            'error',
            LiftError.windowClosed,
          ),
        ),
      );
      expect(await feels.get(mon, pecDeck.id), isNull);
    },
  );
}
