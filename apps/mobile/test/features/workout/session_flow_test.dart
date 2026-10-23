import 'dart:async';

import 'package:domain/domain.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/app/app.dart';
import 'package:mobile/app/router.dart';
import 'package:mobile/app/shell/app_tab.dart';
import 'package:mobile/app/strings_vi.dart';
import 'package:mobile/data/db/app_database.dart' hide ExerciseRow;
import 'package:mobile/features/library/data/exercise_repository.dart';
import 'package:mobile/features/library/data/video_player_gateway.dart';
import 'package:mobile/features/schedule/application/schedule_edits.dart';
import 'package:mobile/features/schedule/data/schedule_repository.dart';
import 'package:mobile/features/schedule/presentation/day_sheet.dart';
import 'package:mobile/features/training/application/training_section.dart';
import 'package:mobile/features/workout/application/lift_log_edits.dart';
import 'package:mobile/features/workout/data/exercise_note_repository.dart';
import 'package:mobile/features/workout/data/exercise_unit_repository.dart';
import 'package:mobile/features/workout/data/lift_log_repository.dart';
import 'package:mobile/features/workout/presentation/session_screen.dart';

import '../../support/app_harness.dart';
import '../../support/fake_native.dart';
import '../../support/fake_server.dart';
import '../../support/fake_sync.dart';
import '../../support/library_fixture.dart';
import '../../support/schedule_fixture.dart';

/// 06 Bản 3 VS36-T06 (widget): S-63 danh sách phẳng 8 tình huống, biểu tượng
/// ghi chú; S-64 điền sẵn, ±bước, chọn đơn vị, cảnh báo, ghi chú, dạng chỉ
/// ghi chú, hộp "Bỏ thay đổi chưa lưu?"; khu mức tạ của S-67; hộp F05-R28.
/// templateAc2: thứ 2 12/10 Ngực + Tay sau 18:00. Dữ liệu `sessionChestV3`
/// (06 Bản 3 §6.11.2): "Máy ép ngực" buổi trước 40 → 45 kg; bài 2 có ghi chú
/// buổi trước; bài 3 chưa từng ghi; bài 4 nấc 8 → 10.
void main() {
  late AppDatabase db;
  late FixedClock clock;
  late FakeScheduler scheduler;
  late ProviderContainer container;
  late List<Exercise> library;
  late LiftLogRepository logs;
  late ExerciseUnitRepository units;
  late ExerciseNoteRepository notes;

  final mon = LocalDate(2026, 10, 12);
  final tue = LocalDate(2026, 10, 13);
  final prevMon = LocalDate(2026, 10, 5);

  late Exercise pecDeck; // 1. kg, buổi trước 40 → 45
  late Exercise bench; // 2. kg, buổi trước 50 → 55, có ghi chú
  late Exercise incline; // 3. chưa từng ghi
  late Exercise decline; // 4. nấc, buổi trước 8 → 10
  late Exercise tricepsLong;
  late Exercise shoulderSide;
  late Exercise plank;

  Future<void> logLift(LocalDate date, Exercise e, int start, int end) =>
      logs.put(
        LiftLog(date: date, exerciseId: e.id, startKgX10: start, endKgX10: end),
      );

  Future<void> setUnit(Exercise e, LiftUnit unit) =>
      units.put(ExerciseUnit(exerciseId: e.id, unit: unit, changedOn: prevMon));

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    clock = FixedClock(DateTime(2026, 10, 12, 18, 30));
    scheduler = FakeScheduler();
    logs = LiftLogRepository(db);
    units = ExerciseUnitRepository(db);
    notes = ExerciseNoteRepository(db);
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
    shoulderSide = exerciseOf(library, MuscleRegion.deltSide);
    plank = exerciseOf(library, MuscleRegion.absMid);
    await setUnit(pecDeck, LiftUnit.kg);
    await logLift(prevMon, pecDeck, 400, 450);
    await setUnit(bench, LiftUnit.kg);
    await logLift(prevMon, bench, 500, 550);
    await notes.put(
      ExerciseNote(date: prevMon, exerciseId: bench.id, text: 'máy 2 hỏng'),
    );
    await setUnit(decline, LiftUnit.steps);
    await logLift(prevMon, decline, 80, 100);
  });

  Future<void> pump(
    WidgetTester tester, {
    bool tall = true,
    FakeServer? server,
    FakeConnectivity? connectivity,
    FakeNativeBridge? native,
  }) async {
    tester.view
      ..physicalSize = Size(390 * 3, (tall ? 2600 : 844) * 3)
      ..devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    container = ProviderContainer(
      retry: (_, _) => null,
      overrides: [
        ...appOverrides(
          db: db,
          clock: clock,
          scheduler: scheduler,
          server: server ?? FakeServer(),
          connectivity: connectivity,
          native: native,
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

  /// Tua đồng hồ tới [at]; hẹn giờ của app (đồng hồ giao diện) chạy lại.
  Future<void> advanceTo(WidgetTester tester, DateTime at) async {
    clock.set(at);
    scheduler.fireSync();
    await tester.pumpAndSettle();
  }

  Future<void> tapKey(WidgetTester tester, String key) async {
    final f = find.byKey(ValueKey(key), skipOffstage: false);
    await tester.ensureVisible(f);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(ValueKey(key)));
    await tester.pumpAndSettle();
  }

  Future<void> go(WidgetTester tester, String path) async {
    container.read(routerProvider).go(path);
    await tester.pumpAndSettle();
  }

  Future<void> openMonday(WidgetTester tester) async {
    await pump(tester);
    await go(tester, sessionPath(AppTab.today, mon));
  }

  Finder key(String k) => find.byKey(ValueKey(k), skipOffstage: false);

  /// Chỉ trong S-63 (thẻ Hôm nay vẫn dựng phía sau).
  Finder inSession(Finder f) =>
      find.descendant(of: find.byType(SessionScreen), matching: f);

  Finder inRow(Exercise e, Finder f) =>
      find.descendant(of: key('exercise-${e.id}'), matching: f);

  /// Gõ hai ô của S-64 rồi (tùy) bấm Lưu.
  Future<void> enter(
    WidgetTester tester, {
    String? start,
    String? end,
    bool save = true,
  }) async {
    if (start != null) {
      await tester.enterText(key('lift-start-input'), start);
    }
    if (end != null) await tester.enterText(key('lift-end-input'), end);
    await tester.pumpAndSettle();
    if (save) await tapKey(tester, 'lift-save');
  }

  String fieldText(WidgetTester tester, String field) =>
      tester.widget<TextField>(key('lift-$field-input')).controller!.text;

  Color? valueColor(WidgetTester tester, String field) =>
      tester.widget<Text>(key('lift-$field-value')).style?.color;

  /// Đóng bảng như chạm vùng mờ phía trên.
  Future<void> dismissSheet(WidgetTester tester) async {
    await tester.tapAt(const Offset(20, 20));
    await tester.pumpAndSettle();
  }

  group('S-63 danh sách bài', () {
    testWidgets('F20-R41, F20-AC45: mỗi nhóm một tiêu đề nhỏ, danh sách phẳng '
        'theo thứ tự thư viện, không tiêu đề vùng; UX-AC46, F20-AC41: '
        '"BUỔI TRƯỚC" + số xám; F20-AC43: bài chưa từng ghi → "Ghi"; nấc ghi '
        '"nấc"; F20-AC44: biểu tượng ghi chú mờ; dòng chú thích cuối; UA3-01: '
        'tổng không tính bài bụng', (tester) async {
      await openMonday(tester);
      expect(key('session-group-chest'), findsOneWidget);
      expect(key('session-group-triceps'), findsOneWidget);
      expect(key('session-region-chest_mid'), findsNothing);
      final ys = [
        for (final e in library)
          if (e.group == MuscleGroup.chest || e.group == MuscleGroup.triceps)
            tester.getTopLeft(key('exercise-${e.id}')).dy,
      ];
      expect(ys, hasLength(7));
      expect(ys, orderedEquals([...ys]..sort()));
      expect(
        tester.getTopLeft(key('session-group-triceps')).dy,
        greaterThan(tester.getTopLeft(key('exercise-${decline.id}')).dy),
      );

      expect(
        find.descendant(
          of: key('lift-prev-${pecDeck.id}'),
          matching: find.text(S.liftPreviousLabel),
        ),
        findsOneWidget,
      );
      expect(inRow(pecDeck, find.text('40 → 45 kg')), findsOneWidget);
      expect(inRow(decline, find.text('8 → 10 nấc')), findsOneWidget);
      expect(key('lift-log-${incline.id}'), findsOneWidget);
      expect(key('note-mark-${bench.id}-previous'), findsOneWidget);
      expect(key('note-mark-${pecDeck.id}-previous'), findsNothing);
      for (final word in ['Máy', 'Tạ']) {
        expect(inSession(find.text(word)), findsNothing);
      }
      expect(key('session-footnote'), findsOneWidget);
      expect(find.text(S.sessionFootnote), findsOneWidget);
      expect(find.text(S.liftLoggedOf(0, 7)), findsOneWidget);
    });

    testWidgets('UA3-05: 17:59 → "GẦN NHẤT" + số xám, "Chưa ghi", không nút; '
        '18:00 → "BUỔI TRƯỚC", nút "Ghi", thanh đáy có "Đã tập"', (
      tester,
    ) async {
      clock.set(DateTime(2026, 10, 12, 17, 59));
      await openMonday(tester);
      expect(find.text(S.liftOpensAt('18:00')), findsOneWidget);
      expect(
        find.descendant(
          of: key('lift-latest-${pecDeck.id}'),
          matching: find.text(S.liftLatestLabel),
        ),
        findsOneWidget,
      );
      expect(key('lift-none-${incline.id}'), findsOneWidget);
      expect(find.text(S.logLiftShort, skipOffstage: false), findsNothing);
      expect(key('session-footnote'), findsNothing);
      expect(key('session-done'), findsNothing);

      await advanceTo(tester, DateTime(2026, 10, 12, 18));
      expect(key('lift-prev-${pecDeck.id}'), findsOneWidget);
      expect(key('lift-log-${incline.id}'), findsOneWidget);
      expect(key('session-done'), findsOneWidget);
    });

    testWidgets('F20-AC4, FA3-09: buổi thứ 6 tuần sau từ S-21 → "Chỉ xem · '
        'Buổi chưa đến", mức gần nhất mờ, không ghi được', (tester) async {
      await logLift(prevMon, shoulderSide, 100, 120);
      await setUnit(shoulderSide, LiftUnit.kg);
      await pump(tester, tall: false);
      final host = tester.element(find.byType(Scaffold).first);
      unawaited(showDaySheet(host, LocalDate(2026, 10, 16)));
      await tester.pumpAndSettle();
      await tapKey(tester, 'day-view-exercises');
      expect(find.text(S.sessionTitle('Vai')), findsOneWidget);
      expect(find.text(S.readOnlyFuture), findsOneWidget);
      expect(key('lift-latest-${shoulderSide.id}'), findsOneWidget);
      expect(find.text(S.logLiftShort, skipOffstage: false), findsNothing);
      expect(find.text(S.liftNotLogged, skipOffstage: false), findsWidgets);
    });

    testWidgets('F20-AC46: buổi tuần trước có mức tạ → con số của buổi đó, '
        'không "BUỔI TRƯỚC"; chạm dòng → S-67 "Buổi này: …" không có "Sửa"', (
      tester,
    ) async {
      final wed = LocalDate(2026, 10, 7);
      final lats = exerciseOf(library, MuscleRegion.lats);
      await setUnit(lats, LiftUnit.steps);
      await logLift(wed, lats, 70, 80);
      await pump(tester);
      await go(tester, sessionPath(AppTab.schedule, wed));
      expect(find.text(S.readOnlyLocked), findsOneWidget);
      expect(key('lift-readonly-${lats.id}'), findsOneWidget);
      expect(find.text('7 → 8 nấc'), findsOneWidget);
      expect(find.text(S.liftPreviousLabel), findsNothing);
      expect(find.text(S.logLiftShort, skipOffstage: false), findsNothing);
      await tapKey(tester, 'exercise-${lats.id}');
      expect(find.text(S.backSession), findsOneWidget);
      expect(
        find.text(S.liftThisSession('7', '8', S.unitSteps)),
        findsOneWidget,
      );
      expect(key('exercise-edit-lift'), findsNothing);
    });

    testWidgets('F20-AC10, F20-E4: buổi tập thêm cho ngày đã qua → "Chỉ xem · '
        'Buổi tập thêm cho ngày đã qua không ghi mức tạ"', (tester) async {
      final sat = LocalDate(2026, 10, 10);
      final schedule = ScheduleRepository(db);
      final d = (await schedule.day(sat))!;
      await schedule.putDay(
        d.withExtra(const [
          MuscleGroup.back,
        ], loggedAt: DateTime(2026, 10, 11, 9)),
      );
      await pump(tester);
      await go(tester, sessionPath(AppTab.schedule, sat));
      expect(find.text(S.readOnlyPastExtra), findsOneWidget);
      expect(find.text(S.logLiftShort, skipOffstage: false), findsNothing);
    });

    testWidgets('F20-E1, F21-E7, UA2-18: bài đã rời thư viện có bản ghi hôm '
        'nay vẫn hiện kèm ghi chú, sửa được; bài rời thư viện chưa ghi không '
        'hiện', (tester) async {
      await logLift(mon, pecDeck, 400, 450);
      final repo = ExerciseRepository(db);
      await repo.put(pecDeck.copyWith(active: false));
      await repo.put(incline.copyWith(active: false));
      await openMonday(tester);
      expect(key('session-not-in-library-${pecDeck.id}'), findsOneWidget);
      expect(key('exercise-${incline.id}'), findsNothing);
      expect(find.text(S.liftLoggedOf(1, 6)), findsOneWidget);
      await tapKey(tester, 'lift-value-${pecDeck.id}');
      await enter(tester, end: '50');
      expect(inRow(pecDeck, find.text('40 → 50 kg')), findsOneWidget);
    });

    testWidgets('F20-E2: sửa riêng nhóm cơ hôm nay trước giờ tập → danh sách '
        'bài đổi ngay', (tester) async {
      clock.set(DateTime(2026, 10, 12, 10));
      await openMonday(tester);
      expect(key('session-group-chest'), findsOneWidget);
      await container
          .read(scheduleEditsProvider)
          .overrideDay(
            mon,
            time: LocalTime(18, 0),
            muscles: const [MuscleGroup.legs],
          );
      await tester.pumpAndSettle();
      expect(find.text(S.sessionTitle('Chân')), findsOneWidget);
      expect(key('session-group-legs'), findsOneWidget);
      expect(key('session-group-chest'), findsNothing);
      for (final e in library.where((e) => e.group == MuscleGroup.legs)) {
        expect(key('exercise-${e.id}'), findsOneWidget);
      }
    });

    testWidgets('F20-E42: xóa bản ghi hôm nay → dòng quay về "BUỔI TRƯỚC"; '
        'F20-E43: đổi đơn vị → con số cũ với đơn vị mới', (tester) async {
      await logLift(mon, pecDeck, 400, 475);
      await openMonday(tester);
      expect(inRow(pecDeck, find.text('40 → 47,5 kg')), findsOneWidget);
      await tapKey(tester, 'lift-value-${pecDeck.id}');
      await tapKey(tester, 'lift-delete');
      await tapKey(tester, 'lift-delete-confirm-ok');
      expect(find.text(S.liftDeleted), findsOneWidget);
      expect(key('lift-prev-${pecDeck.id}'), findsOneWidget);

      await container
          .read(changeExerciseUnitProvider)
          .call(pecDeck.id, LiftUnit.steps);
      await tester.pumpAndSettle();
      expect(inRow(pecDeck, find.text('40 → 45 nấc')), findsOneWidget);
    });

    testWidgets('UA2-08: thẻ Hôm nay hiện "Đã ghi mức tạ {n} bài"; buổi đã tập '
        'chỉ có "Xem bài tập"', (tester) async {
      await logLift(mon, pecDeck, 300, 350);
      await logLift(mon, tricepsLong, 100, 125);
      await pump(tester, tall: false);
      expect(find.text(S.viewExercisesAndLog), findsOneWidget);
      expect(find.text(S.liftLoggedCount(2)), findsOneWidget);
      await seedMark(db, mon, DayMark.done);
      await tester.pumpAndSettle();
      expect(find.text(S.viewExercises), findsOneWidget);
    });

    testWidgets('NAV-9: Hôm nay → S-25 → dòng ngày → S-21 → "Xem bài tập" → '
        'S-63, quay lại về Hôm nay', (tester) async {
      await pump(tester, tall: false);
      await go(tester, '/today/progress/2026-10-12');
      await tester.tap(find.text('T2 12/10'));
      await tester.pumpAndSettle();
      await tapKey(tester, 'day-view-exercises');
      expect(find.text(S.sessionTitle('Ngực và Tay sau')), findsOneWidget);
      await tapKey(tester, 'session-back');
      expect(find.text(S.sessionTitle('Ngực và Tay sau')), findsNothing);
    });

    testWidgets('UX-AC35, F21-AC9: "Đã tập" lúc 19:00 → vẫn ghi được; 00:00 → '
        'chỉ đọc, con số chữ thường, không "BUỔI TRƯỚC", không nút, không dòng '
        'chú thích (F26-AC6)', (tester) async {
      clock.set(DateTime(2026, 10, 12, 19));
      await openMonday(tester);
      await tapKey(tester, 'session-done');
      await tapKey(tester, 'lock-confirm-save');
      expect(inSession(key('session-tag-done')), findsOneWidget);
      await tapKey(tester, 'lift-prev-tap-${pecDeck.id}');
      await tapKey(tester, 'lift-save');
      expect(find.text(S.liftLoggedOf(1, 7)), findsOneWidget);

      await advanceTo(tester, DateTime(2026, 10, 13));
      expect(find.text(S.readOnlyLocked), findsOneWidget);
      expect(key('lift-readonly-${pecDeck.id}'), findsOneWidget);
      expect(key('lift-prev-${bench.id}'), findsNothing);
      expect(key('lift-log-${incline.id}'), findsNothing);
      expect(key('session-footnote'), findsNothing);
    });
  });

  group('S-64 ghi mức tạ', () {
    testWidgets('UX-AC46 → AC47, F21-AC41: chạm số mờ → điền sẵn 40 và 45 '
        'xám, nút −2,5 / +2,5; "+2,5" ở Kết thúc → 47,5 màu thường → Lưu → '
        '"Đã lưu 40 → 47,5 kg", dòng đậm, thanh đáy 1/7 (2 chạm)', (
      tester,
    ) async {
      await openMonday(tester);
      await tapKey(tester, 'lift-prev-tap-${pecDeck.id}');
      expect(
        find.text(S.liftPrevious('05/10', '40', '45', S.unitKg)),
        findsOneWidget,
      );
      expect(
        (fieldText(tester, 'start'), fieldText(tester, 'end')),
        ('40', '45'),
      );
      final gray = valueColor(tester, 'start');
      expect(valueColor(tester, 'end'), gray);
      expect(
        find.descendant(of: key('lift-end-plus'), matching: find.text('+2,5')),
        findsOneWidget,
      );
      expect(find.text(S.liftStepGuide('2,5 kg')), findsOneWidget);
      expect(key('lift-unit-bar'), findsNothing, reason: 'UA3-09');

      await tapKey(tester, 'lift-end-plus');
      expect(fieldText(tester, 'end'), '47,5');
      expect(valueColor(tester, 'end'), isNot(gray));
      expect(valueColor(tester, 'start'), gray);
      await tapKey(tester, 'lift-save');
      expect(find.text('Đã lưu 40 → 47,5 kg'), findsOneWidget);
      expect(key('lift-value-${pecDeck.id}'), findsOneWidget);
      expect(inRow(pecDeck, find.text('40 → 47,5 kg')), findsOneWidget);
      expect(find.text(S.liftLoggedOf(1, 7)), findsOneWidget);
      expect(
        await logs.get(mon, pecDeck.id),
        LiftLog(
          date: mon,
          exerciseId: pecDeck.id,
          startKgX10: 400,
          endKgX10: 475,
        ),
      );
    });

    testWidgets('UX-AC48, F21-AC42: mở rồi đóng ngay → không hỏi; mở → Lưu '
        'ngay → bản ghi bằng buổi trước, không cảnh báo (1 chạm)', (
      tester,
    ) async {
      await openMonday(tester);
      await tapKey(tester, 'lift-prev-tap-${bench.id}');
      await dismissSheet(tester);
      expect(key('discard-changes'), findsNothing);
      expect(key('lift-save'), findsNothing);

      await tapKey(tester, 'lift-prev-tap-${bench.id}');
      expect(key('lift-warning-lower'), findsNothing);
      await tapKey(tester, 'lift-save');
      expect((await logs.get(mon, bench.id))!.endKgX10, 550);
      expect(find.text('Đã lưu 50 → 55 kg'), findsOneWidget);
    });

    testWidgets('UX-AC49, F21-AC43, F21-AC44: bài chưa từng ghi → "Bài này ghi '
        'bằng" kg | nấc máy không chọn sẵn, hai ô "—"; Lưu → "Chọn kg hoặc '
        'nấc máy cho bài này"; chọn nấc máy → −1 / +1, "nấc"; 8 và 10 → "8 → '
        '10 nấc"; mở lại → 8 và 10, ±1', (tester) async {
      await openMonday(tester);
      await tapKey(tester, 'lift-log-${incline.id}');
      expect(find.text(S.liftFirstTime), findsOneWidget);
      expect(find.text(S.liftUnitPrompt), findsOneWidget);
      expect(key('lift-unit-bar'), findsOneWidget);
      expect(find.text('—'), findsNWidgets(2));
      expect(key('lift-guide'), findsNothing);
      await tapKey(tester, 'lift-save');
      expect(find.text(S.liftUnitRequired), findsOneWidget);
      expect(await logs.get(mon, incline.id), isNull);

      await tapKey(tester, 'lift-unit-steps');
      expect(find.text(S.liftUnitRequired), findsNothing);
      expect(
        find.descendant(of: key('lift-start-minus'), matching: find.text('−1')),
        findsOneWidget,
      );
      expect(find.text(S.liftStepGuideFirst('1 nấc')), findsOneWidget);
      await enter(tester, start: '8', end: '10');
      expect(find.text('Đã lưu 8 → 10 nấc'), findsOneWidget);
      expect(inRow(incline, find.text('8 → 10 nấc')), findsOneWidget);
      expect((await units.get(incline.id))!.unit, LiftUnit.steps);

      await tapKey(tester, 'lift-value-${incline.id}');
      expect(key('lift-unit-bar'), findsNothing);
      expect(
        (fieldText(tester, 'start'), fieldText(tester, 'end')),
        ('8', '10'),
      );
      expect(
        find.descendant(of: key('lift-end-plus'), matching: find.text('+1')),
        findsOneWidget,
      );
    });

    testWidgets('UX-AC50, F21-AC45: nấc buổi trước 8 → 10; Kết thúc 15 → khu '
        'cảnh báo vàng "cao hơn buổi trước 5 nấc", vẫn lưu được; 14 → không; 9 '
        '→ "thấp hơn … 1 nấc"', (tester) async {
      await openMonday(tester);
      await tapKey(tester, 'lift-prev-tap-${decline.id}');
      await enter(tester, end: '15', save: false);
      expect(find.text(S.liftEndMuchHigher('5', S.unitSteps)), findsOneWidget);
      await enter(tester, end: '14', save: false);
      expect(key('lift-warning-muchHigher'), findsNothing);
      await enter(tester, end: '9', save: false);
      expect(find.text(S.liftEndLower('1', S.unitSteps)), findsOneWidget);
      await enter(tester, end: '15');
      expect(inRow(decline, find.text('8 → 15 nấc')), findsOneWidget);
    });

    testWidgets('F21-V42 → V45: lỗi đỏ dưới hai ô, không lưu; "." hiện thành '
        '","', (tester) async {
      await openMonday(tester);
      await tapKey(tester, 'lift-prev-tap-${bench.id}');
      for (final (start, end, message) in [
        ('35', '', S.liftMissing),
        ('35', '72,3', S.liftKgInvalid),
        ('0', '10', S.liftKgInvalid),
        ('13,25', '10', S.liftKgInvalid),
        ('1,2,3', '10', S.liftNotNumber),
      ]) {
        await enter(tester, start: start, end: end);
        expect(find.text(message), findsOneWidget, reason: '$start/$end');
      }
      expect(await logs.get(mon, bench.id), isNull);
      await enter(tester, start: '72.5', end: '75', save: false);
      expect(fieldText(tester, 'start'), '72,5');
      await tapKey(tester, 'lift-save');
      expect((await logs.get(mon, bench.id))!.startKgX10, 725);

      await tapKey(tester, 'lift-prev-tap-${decline.id}');
      await enter(tester, start: '8', end: '51');
      expect(find.text(S.liftStepsInvalid), findsOneWidget);
    });

    testWidgets(
      'F21-AC49, FA3-05, F21-AC47: ô trống bấm ±bước không đổi; 13 → '
      '+2,5 → 15,5; chặn ở 0,5 và 300; UA3-03: đã bấm ±bước → đóng phải hỏi',
      (tester) async {
        await openMonday(tester);
        await tapKey(tester, 'lift-log-${incline.id}');
        await tapKey(tester, 'lift-unit-kg');
        await tapKey(tester, 'lift-start-plus');
        expect(fieldText(tester, 'start'), '');
        await enter(tester, start: '13', end: '0,5', save: false);
        await tapKey(tester, 'lift-start-plus');
        expect(fieldText(tester, 'start'), '15,5');
        await tapKey(tester, 'lift-end-minus');
        expect(fieldText(tester, 'end'), '0,5');
        await enter(tester, end: '300', save: false);
        await tapKey(tester, 'lift-end-plus');
        expect(fieldText(tester, 'end'), '300');

        await dismissSheet(tester);
        expect(find.text(S.discardChanges), findsOneWidget);
        await tapKey(tester, 'discard-confirm');
        expect(key('lift-save'), findsNothing);
        expect(await logs.get(mon, incline.id), isNull);

        // Chỉ bấm ±bước khi ô trống (số không đổi) vẫn là có thay đổi.
        await tapKey(tester, 'lift-log-${incline.id}');
        await tapKey(tester, 'lift-unit-kg');
        await tapKey(tester, 'lift-end-plus');
        await dismissSheet(tester);
        expect(find.text(S.discardChanges), findsOneWidget);
      },
    );

    testWidgets('UX-AC51, F26-AC8: gõ ghi chú rồi đóng → "Bỏ thay đổi chưa '
        'lưu?"; "Tiếp tục ghi" → còn nguyên; hai ô trống + ghi chú → "Đã lưu '
        'ghi chú", biểu tượng rõ, vẫn "Ghi", thanh đáy không đổi; F26-AC3: bộ '
        'đếm 200/200', (tester) async {
      await openMonday(tester);
      await tapKey(tester, 'lift-log-${incline.id}');
      await tester.enterText(key('note-input'), 'máy 2 hỏng, tập máy 5');
      await tester.pumpAndSettle();
      expect(find.text(S.noteCounter(21)), findsOneWidget);
      await dismissSheet(tester);
      expect(find.text(S.discardChanges), findsOneWidget);
      await tapKey(tester, 'discard-keep');
      expect(
        tester.widget<TextField>(key('note-input')).controller!.text,
        'máy 2 hỏng, tập máy 5',
      );
      await tapKey(tester, 'lift-save');
      expect(find.text(S.noteSaved), findsOneWidget);
      expect(key('note-mark-${incline.id}-today'), findsOneWidget);
      expect(key('lift-log-${incline.id}'), findsOneWidget);
      expect(find.text(S.liftLoggedOf(0, 7)), findsOneWidget);
      expect((await notes.get(mon, incline.id))!.text, 'máy 2 hỏng, tập máy 5');

      await tapKey(tester, 'lift-log-${incline.id}');
      await tester.enterText(key('note-input'), 'a' * 201);
      await tester.pumpAndSettle();
      expect(find.text(S.noteCounter(200)), findsOneWidget);
      expect(
        tester.widget<TextField>(key('note-input')).controller!.text,
        'a' * 200,
      );
    });

    testWidgets('UX-AC52, F26-AC2: ghi chú buổi trước mờ "05/10: …" trên ô; '
        'F26-AC5: xóa hết chữ của ghi chú hôm nay → Lưu → biểu tượng về mờ', (
      tester,
    ) async {
      await notes.put(
        ExerciseNote(date: mon, exerciseId: bench.id, text: 'ghế số 3'),
      );
      await openMonday(tester);
      expect(key('note-mark-${bench.id}-today'), findsOneWidget);
      await tapKey(tester, 'lift-prev-tap-${bench.id}');
      expect(find.text(S.notePrevious('05/10', 'máy 2 hỏng')), findsOneWidget);
      expect(
        tester.widget<TextField>(key('note-input')).controller!.text,
        'ghế số 3',
      );
      await tester.enterText(key('note-input'), '  ');
      await tester.pumpAndSettle();
      await enter(tester, start: '', end: '');
      expect(find.text(S.noteSaved), findsOneWidget);
      expect(await notes.get(mon, bench.id), isNull);
      expect(key('note-mark-${bench.id}-previous'), findsOneWidget);
      expect(await logs.get(mon, bench.id), isNull);
    });

    testWidgets('F26-E4, FA2-17: mở lúc 23:58, Lưu lúc 00:01 → hộp "Mức tạ và '
        'ghi chú của buổi này đã khóa lúc 00:00." → "Đã hiểu" → chỉ đọc, '
        'không lưu gì', (tester) async {
      clock.set(DateTime(2026, 10, 12, 23, 58));
      await openMonday(tester);
      await tapKey(tester, 'lift-prev-tap-${pecDeck.id}');
      await tester.enterText(key('note-input'), 'muộn');
      await tester.pumpAndSettle();
      clock.set(DateTime(2026, 10, 13, 0, 1));
      await tapKey(tester, 'lift-save');
      expect(find.text(S.liftAndNoteLocked), findsOneWidget);
      await tapKey(tester, 'lift-locked-ok');
      expect(key('lift-save'), findsNothing);
      scheduler.fireSync();
      await tester.pumpAndSettle();
      expect(find.text(S.readOnlyLocked), findsOneWidget);
      expect(await logs.get(mon, pecDeck.id), isNull);
      expect(await notes.get(mon, pecDeck.id), isNull);
    });

    testWidgets('UX-AC53, F21-AC50, F26-AC4: buổi tập thêm Vai và Bụng: bài '
        'bụng có nút "Ghi chú" → S-64 chỉ có ô ghi chú, không ô số, không thanh '
        'đơn vị; tổng không tính bụng', (tester) async {
      await seedExtra(db, tue, const [MuscleGroup.shoulders, MuscleGroup.abs]);
      clock.set(DateTime(2026, 10, 13, 20, 30));
      await pump(tester);
      await tapKey(tester, 'session-view-exercises');
      expect(find.text(S.extraSessionTitle('Vai và Bụng')), findsOneWidget);
      expect(key('session-group-abs'), findsOneWidget);
      for (final e in library.where((e) => e.group == MuscleGroup.abs)) {
        expect(key('note-log-${e.id}'), findsOneWidget);
        expect(key('lift-log-${e.id}'), findsNothing);
      }
      // Buổi tập thêm chưa có mức tạ: thanh đáy ẩn (UA2-09).
      expect(key('session-logged'), findsNothing);
      await tapKey(tester, 'note-log-${plank.id}');
      expect(find.text(S.liftNoWeight), findsOneWidget);
      expect(key('lift-start-input'), findsNothing);
      expect(key('lift-unit-bar'), findsNothing);
      await tester.enterText(key('note-input'), 'giữ được 60 giây');
      await tester.pumpAndSettle();
      await tapKey(tester, 'lift-save');
      expect(find.text(S.noteSaved), findsOneWidget);
      expect(key('note-mark-${plank.id}-today'), findsOneWidget);
      expect(key('session-logged'), findsNothing, reason: 'UA3-01');
      await tapKey(tester, 'lift-log-${shoulderSide.id}');
      await tapKey(tester, 'lift-unit-kg');
      await enter(tester, start: '10', end: '12');
      expect(find.text(S.liftLoggedOf(1, 6)), findsOneWidget);
    });
  });

  group('S-67 khu cuối trang (UA3-12)', () {
    testWidgets('từ S-63 trong cửa sổ, chưa ghi → "Ghi mức tạ", "Đơn vị: kg" + '
        '"Đổi sang nấc máy", "Gần nhất (05/10)" + "Xem biểu đồ", viền đậm; '
        'Ghi → S-64 điền sẵn; đã ghi → "Buổi này" + "Sửa"; ghi chú hôm nay', (
      tester,
    ) async {
      await pump(tester);
      await go(tester, sessionExercisePath(AppTab.today, mon, bench.id));
      expect(key('exercise-log-lift'), findsOneWidget);
      expect(find.text('Đơn vị: kg'), findsOneWidget);
      expect(find.text(S.changeUnitTo(S.unitStepsFull)), findsOneWidget);
      expect(find.text('Gần nhất (05/10): 50 → 55 kg'), findsOneWidget);
      expect(key('exercise-view-chart'), findsOneWidget);
      final border =
          (tester.widget<Container>(key('exercise-lift-area')).decoration!
                  as BoxDecoration)
              .border!
              .top;
      expect(border.width, 2);

      await tapKey(tester, 'exercise-log-lift');
      expect(
        (fieldText(tester, 'start'), fieldText(tester, 'end')),
        ('50', '55'),
      );
      await tester.enterText(key('note-input'), 'ghế số 3');
      await enter(tester, end: '57,5');
      expect(find.text('Buổi này: 50 → 57,5 kg'), findsOneWidget);
      expect(find.text(S.noteToday('ghế số 3')), findsOneWidget);
      expect(key('exercise-log-lift'), findsNothing);
      await tapKey(tester, 'exercise-edit-lift');
      expect(key('lift-delete'), findsOneWidget);
    });

    testWidgets('F19-AC41: bài nấc máy → "Đơn vị: nấc máy" + "Đổi sang kg"; '
        'F19-AC42, F19-AC3: bài chưa ghi mở từ thư viện → không khu, không '
        'đơn vị; bài bụng từ thư viện → không khu', (tester) async {
      await pump(tester);
      await go(tester, '/schedule/exercise/${decline.id}?from=library');
      expect(find.text('Đơn vị: nấc máy'), findsOneWidget);
      expect(find.text(S.changeUnitTo(S.unitKg)), findsOneWidget);
      expect(find.text('Gần nhất (05/10): 8 → 10 nấc'), findsOneWidget);
      expect(key('exercise-log-lift'), findsNothing);
      await go(tester, '/schedule/exercise/${incline.id}?from=library');
      expect(key('exercise-lift-area'), findsNothing);
      expect(key('exercise-unit'), findsNothing);
      await go(tester, '/schedule/exercise/${plank.id}?from=library');
      expect(key('exercise-lift-area'), findsNothing);
    });

    testWidgets('UX-AC53, FA3-08: bài bụng mở từ buổi trong cửa sổ → ghi chú '
        'buổi trước mờ, "Bài này không ghi mức tạ" + "Ghi chú" → S-64 chỉ ghi '
        'chú; không có dòng đơn vị', (tester) async {
      await notes.put(
        ExerciseNote(date: prevMon, exerciseId: plank.id, text: 'giữ 45 giây'),
      );
      await seedExtra(db, tue, const [MuscleGroup.abs]);
      clock.set(DateTime(2026, 10, 13, 20, 30));
      await pump(tester);
      await go(tester, sessionExercisePath(AppTab.today, tue, plank.id));
      expect(
        find.text(S.notePreviousSession('05/10', 'giữ 45 giây')),
        findsOneWidget,
      );
      expect(find.text(S.liftNoWeight), findsOneWidget);
      expect(key('exercise-unit'), findsNothing);
      await tapKey(tester, 'exercise-note');
      expect(key('lift-start-input'), findsNothing);
      expect(key('note-input'), findsOneWidget);
    });

    testWidgets(
      'UA2-18: bài đã rời thư viện, mở từ S-63 trong cửa sổ, chưa ghi '
      '→ không có "Ghi mức tạ", vẫn có đơn vị và "Gần nhất"',
      (tester) async {
        await ExerciseRepository(db).put(pecDeck.copyWith(active: false));
        await pump(tester);
        await go(tester, sessionExercisePath(AppTab.today, mon, pecDeck.id));
        expect(key('exercise-log-lift'), findsNothing);
        expect(find.text('Đơn vị: kg'), findsOneWidget);
        expect(find.text('Gần nhất (05/10): 40 → 45 kg'), findsOneWidget);
      },
    );
  });

  group('S-72 đổi đơn vị', () {
    testWidgets('F21-AC48, UX-AC54: "Đổi sang nấc máy" → hộp câu nguyên văn → '
        'Hủy không đổi; xác nhận → "Đã đổi sang nấc máy", số cũ giữ với "nấc" '
        'ở chi tiết bài, S-63, S-64; bảng S-64 không có lối đổi (UD3-02)', (
      tester,
    ) async {
      await pump(tester);
      await go(tester, sessionExercisePath(AppTab.today, mon, pecDeck.id));
      await tapKey(tester, 'exercise-change-unit');
      expect(find.text(S.changeUnitTitle(S.unitStepsFull)), findsOneWidget);
      expect(
        find.text(
          'Mức tạ đã ghi của bài này giữ nguyên con số, không quy đổi sang '
          'nấc máy. Biểu đồ sẽ hiện theo nấc máy.',
        ),
        findsOneWidget,
      );
      await tapKey(tester, 'change-unit-cancel');
      expect((await units.get(pecDeck.id))!.unit, LiftUnit.kg);

      await tapKey(tester, 'exercise-change-unit');
      await tapKey(tester, 'change-unit-confirm');
      expect(find.text(S.unitChanged(S.unitStepsFull)), findsOneWidget);
      expect(find.text('Đơn vị: nấc máy'), findsOneWidget);
      expect(find.text('Gần nhất (05/10): 40 → 45 nấc'), findsOneWidget);
      final changed = (await units.get(pecDeck.id))!;
      expect((changed.unit, changed.changedOn), (LiftUnit.steps, mon));
      expect(await logs.get(prevMon, pecDeck.id), isNotNull);

      await tapKey(tester, 'exercise-back');
      expect(inRow(pecDeck, find.text('40 → 45 nấc')), findsOneWidget);
      await tapKey(tester, 'lift-prev-tap-${pecDeck.id}');
      expect(
        find.descendant(of: key('lift-end-plus'), matching: find.text('+1')),
        findsOneWidget,
      );
      expect(key('lift-unit-bar'), findsNothing);
      expect(find.textContaining('Đổi sang'), findsNothing);
    });
  });

  group('F05-R28', () {
    testWidgets('F05-AC28, FA3-15: buổi có mức tạ 2 bài → "Không tập" ở Hôm '
        'nay hỏi "Buổi này đã có mức tạ của 2 bài."; ghi chú không tính; Tiếp '
        'tục → lưu, mức tạ giữ nguyên', (tester) async {
      await logLift(mon, pecDeck, 300, 350);
      await logLift(mon, tricepsLong, 100, 125);
      await notes.put(
        ExerciseNote(date: mon, exerciseId: bench.id, text: 'chỉ ghi chú'),
      );
      await pump(tester, tall: false);
      await tapKey(tester, 'mark-skipped-${mon.toKey()}');
      expect(find.text(S.liftLogsExist(2)), findsOneWidget);
      await tapKey(tester, 'lifts-kept-cancel');
      expect((await ScheduleRepository(db).day(mon))!.mark, isNull);
      await tapKey(tester, 'mark-skipped-${mon.toKey()}');
      await tapKey(tester, 'lifts-kept-continue');
      expect((await ScheduleRepository(db).day(mon))!.mark, DayMark.skipped);
      expect(await logs.countDay(mon), 2);
    });

    testWidgets('S-21: hộp F05-R28 trước khi lưu, bảng đóng sau "Tiếp tục"', (
      tester,
    ) async {
      await logLift(mon, pecDeck, 300, 350);
      await pump(tester, tall: false);
      final host = tester.element(find.byType(Scaffold).first);
      unawaited(showDaySheet(host, mon));
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(DaySheet),
          matching: find.byKey(ValueKey('mark-skipped-${mon.toKey()}')),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text(S.liftLogsExist(1)), findsOneWidget);
      await tapKey(tester, 'lifts-kept-continue');
      expect((await ScheduleRepository(db).day(mon))!.mark, DayMark.skipped);
    });

    testWidgets('không có mức tạ → "Không tập" lưu ngay, không hỏi', (
      tester,
    ) async {
      await pump(tester, tall: false);
      await tapKey(tester, 'mark-skipped-${mon.toKey()}');
      expect(key('lifts-kept-confirm'), findsNothing);
      expect((await ScheduleRepository(db).day(mon))!.mark, DayMark.skipped);
    });
  });

  testWidgets(
    'S-24, FA2-11: lưu buổi tập thêm cho hôm nay → thông báo nhanh có '
    '"Ghi mức tạ" → S-63 ghi được ngay',
    (tester) async {
      clock.set(DateTime(2026, 10, 13, 20));
      await pump(tester, tall: false);
      await tapKey(tester, 'extra-log');
      await tapKey(tester, 'muscle-shoulders');
      await tapKey(tester, 'extra-save');
      await tapKey(tester, 'lock-confirm-save');
      expect(find.text(S.extraLogged('Vai')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('toast-action')));
      await tester.pumpAndSettle();
      expect(find.text(S.extraSessionTitle('Vai')), findsOneWidget);
      expect(key('lift-log-${shoulderSide.id}'), findsOneWidget);
    },
  );
  group('UX-AC61 không mạng', () {
    testWidgets('UX-AC61, UR3-14: tắt mạng → S-63, S-64 (mức tạ, ghi chú), '
        '"Đã tập" vẫn ghi nội dung widget mới; S-67, S-72, S-66, S-68, S-69 '
        'dùng bình thường; không vòng xoay', (tester) async {
      final server = FakeServer()..offline = true;
      final native = FakeNativeBridge();
      await pump(
        tester,
        server: server,
        connectivity: FakeConnectivity()..online = false,
        native: native,
      );
      Finder spinner() => find.byType(CircularProgressIndicator);

      // S-63 → S-64: ghi mức tạ 2 chạm, ghi chú.
      await go(tester, sessionPath(AppTab.today, mon));
      expect(inRow(pecDeck, find.text('40 → 45 kg')), findsOneWidget);
      expect(spinner(), findsNothing);
      await tapKey(tester, 'lift-prev-tap-${pecDeck.id}');
      await tapKey(tester, 'lift-end-plus');
      await tapKey(tester, 'lift-save');
      expect(find.text(S.liftSaved('40', '47,5', S.unitKg)), findsOneWidget);
      expect(inRow(pecDeck, find.text('40 → 47,5 kg')), findsOneWidget);
      final saved = (await logs.get(mon, pecDeck.id))!;
      expect((saved.startKgX10, saved.endKgX10), (400, 475));
      await tapKey(tester, 'lift-log-${incline.id}');
      await tester.enterText(key('note-input'), 'máy 2 hỏng, tập máy 5');
      await tapKey(tester, 'lift-save');
      expect(find.text(S.noteSaved), findsOneWidget);
      expect((await notes.get(mon, incline.id))!.text, 'máy 2 hỏng, tập máy 5');

      // "Đã tập" khi không có mạng → widget có nội dung mới (TR3-10).
      final before = native.written.length;
      await tester.pump(const Duration(seconds: 5)); // thông báo nhanh tắt
      await tester.pumpAndSettle();
      await tapKey(tester, 'session-done');
      await tapKey(tester, 'lock-confirm-save');
      expect(native.written.length, greaterThan(before));
      final today = (native.written.last['days']! as List).first as Map;
      expect((today['date'], today['mark']), ('2026-10-12', 'done'));

      // S-67 → S-72: đổi đơn vị.
      await go(tester, sessionExercisePath(AppTab.today, mon, bench.id));
      expect(spinner(), findsNothing);
      await tapKey(tester, 'exercise-change-unit');
      await tapKey(tester, 'change-unit-confirm');
      expect(find.text(S.unitChanged(S.unitStepsFull)), findsOneWidget);
      expect((await units.get(bench.id))!.unit, LiftUnit.steps);

      // S-66: thư viện 7 nhóm, nhóm Chân 5 bài.
      await go(tester, '/schedule');
      container
          .read(trainingTabProvider.notifier)
          .select(TrainingSection.library);
      await tester.pumpAndSettle();
      await tapKey(tester, 'group-legs');
      for (final e in library.where((e) => e.group == MuscleGroup.legs)) {
        expect(key('exercise-${e.id}'), findsOneWidget);
      }
      expect(spinner(), findsNothing);

      // S-68 → S-69: Tiến bộ và biểu đồ theo đơn vị.
      container
          .read(trainingTabProvider.notifier)
          .select(TrainingSection.progress);
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: key('progress-${pecDeck.id}'),
          matching: find.text('40 → 47,5 kg'),
        ),
        findsOneWidget,
      );
      await tapKey(tester, 'progress-${pecDeck.id}');
      expect(tester.widget<Text>(key('chart-axis-unit')).data, S.unitKg);
      expect(spinner(), findsNothing);
      expect(server.requests, isEmpty, reason: 'không request nào tới được');
    });
  });
}
