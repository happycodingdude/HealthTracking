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
import 'package:mobile/features/workout/data/lift_log_repository.dart';
import 'package:mobile/features/workout/presentation/session_screen.dart';

import '../../support/app_harness.dart';
import '../../support/fake_server.dart';
import '../../support/fake_sync.dart';
import '../../support/library_fixture.dart';
import '../../support/schedule_fixture.dart';

/// 06 Bản 2 VS27-T07 (widget): S-63, S-64, khu mức tạ của S-67, phần bài tập
/// ở S-10, S-21, S-24, hộp F05-R28. templateAc2: thứ 2 Ngực + Tay sau 18:00.
void main() {
  late AppDatabase db;
  late FixedClock clock;
  late FakeScheduler scheduler;
  late ProviderContainer container;
  late List<Exercise> library;
  late LiftLogRepository logs;

  final mon = LocalDate(2026, 10, 12);
  final tue = LocalDate(2026, 10, 13);

  // Ngực trên: máy, tạ (mock S-63-1).
  late Exercise chestMachine;
  late Exercise chestDumbbell;
  late Exercise tricepsLong;
  late Exercise shoulderSide;
  late Exercise absLower;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    clock = FixedClock(DateTime(2026, 10, 12, 18, 30));
    scheduler = FakeScheduler();
    logs = LiftLogRepository(db);
    await seedSetUp(db);
    library = await seedLibrary(db);
    chestMachine = exerciseOf(library, MuscleRegion.chestUpper, 'machine');
    chestDumbbell = exerciseOf(library, MuscleRegion.chestUpper, 'free-weight');
    tricepsLong = exerciseOf(library, MuscleRegion.tricepsLong);
    shoulderSide = exerciseOf(library, MuscleRegion.deltSide);
    absLower = exerciseOf(library, MuscleRegion.absLower);
  });

  Future<void> pump(WidgetTester tester, {bool tall = false}) async {
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

  Finder key(String k) => find.byKey(ValueKey(k), skipOffstage: false);

  /// Chỉ trong S-63 (thẻ Hôm nay vẫn dựng phía sau).
  Finder inSession(Finder f) =>
      find.descendant(of: find.byType(SessionScreen), matching: f);

  Future<void> logLift(LocalDate date, Exercise e, int start, int end) =>
      logs.put(
        LiftLog(date: date, exerciseId: e.id, startKgX10: start, endKgX10: end),
      );

  /// Nhập hai ô của S-64 rồi bấm Lưu.
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

  group('S-63 và thẻ Hôm nay', () {
    testWidgets('UX-AC31, F20-AC2, UX-AC32, F21-AC1: 17:59 thẻ có vùng cơ và '
        '"Xem bài tập" → S-63 chỉ xem "Ghi mức tạ được từ 18:00"; 18:00 nút '
        '"Ghi" xuất hiện, thanh đáy có "Đã tập"', (tester) async {
      clock.set(DateTime(2026, 10, 12, 17, 59));
      await pump(tester, tall: true);
      expect(
        find.text(
          'Ngực trên · Ngực giữa · Ngực dưới · Đầu dài · '
          'Đầu ngoài và đầu trong',
        ),
        findsOneWidget,
      );
      expect(find.text(S.viewExercises), findsOneWidget);
      await tapKey(tester, 'session-view-exercises');
      expect(find.text(S.sessionTitle('Ngực và Tay sau')), findsOneWidget);
      expect(find.text(S.tabToday), findsWidgets, reason: 'nút quay lại');
      expect(find.text(S.liftOpensAt('18:00')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('session-readonly-opensLater')),
        findsOneWidget,
      );
      // Ngực trước rồi Tay sau, vùng theo F18-R9.
      final regions = [
        for (final r in [
          MuscleRegion.chestUpper,
          MuscleRegion.chestMid,
          MuscleRegion.chestLower,
          MuscleRegion.tricepsLong,
          MuscleRegion.tricepsLateralMedial,
        ])
          tester.getTopLeft(key('session-region-${r.id}')).dy,
      ];
      expect(regions, orderedEquals([...regions]..sort()));
      expect(key('session-group-chest'), findsOneWidget);
      expect(key('session-group-triceps'), findsOneWidget);
      expect(find.text(S.logLiftShort, skipOffstage: false), findsNothing);
      expect(key('session-done'), findsNothing);
      expect(key('session-logged'), findsNothing);

      await advanceTo(tester, DateTime(2026, 10, 12, 18));
      expect(find.text(S.liftOpensAt('18:00')), findsNothing);
      expect(key('lift-log-${chestMachine.id}'), findsOneWidget);
      expect(find.text(S.liftLoggedOf(0, 10)), findsOneWidget);
      expect(key('session-done'), findsOneWidget);
    });

    testWidgets('UX-AC33, F21-AC2, F21-AC12: "Ghi" → nhập 12 và 14 → Lưu → '
        'dòng bài "12 → 14 kg", thanh đáy 1/10, buổi vẫn "Chờ đánh dấu"; chạm '
        'con số → điền sẵn, "Xóa mức tạ" → hộp xác nhận → "Đã xóa mức tạ"', (
      tester,
    ) async {
      await pump(tester, tall: true);
      await go(tester, sessionPath(AppTab.today, mon));
      await tapKey(tester, 'lift-log-${chestDumbbell.id}');
      expect(find.text(chestDumbbell.nameVi), findsWidgets);
      expect(find.text(S.liftFirstTime), findsOneWidget);
      expect(key('lift-delete'), findsNothing);
      await enter(tester, start: '12', end: '14');
      expect(find.text('Đã lưu 12 → 14 kg'), findsOneWidget);
      expect(find.text('12 → 14 kg'), findsOneWidget);
      expect(find.text(S.liftLoggedOf(1, 10)), findsOneWidget);
      expect(inSession(key('session-tag-awaitingMark')), findsOneWidget);
      expect((await ScheduleRepository(db).day(mon))!.mark, isNull);

      await tapKey(tester, 'lift-value-${chestDumbbell.id}');
      expect(
        tester.widget<TextField>(key('lift-start-input')).controller!.text,
        '12',
      );
      expect(
        tester.widget<TextField>(key('lift-end-input')).controller!.text,
        '14',
      );
      await tapKey(tester, 'lift-delete');
      expect(find.text(S.deleteLiftConfirm), findsOneWidget);
      await tapKey(tester, 'lift-delete-confirm-ok');
      expect(find.text(S.liftDeleted), findsOneWidget);
      expect(key('lift-log-${chestDumbbell.id}'), findsOneWidget);
      expect(await logs.get(mon, chestDumbbell.id), isNull);
    });

    testWidgets('UX-AC35, F21-AC9, ED2-17: "Đã tập" ở thanh đáy lúc 19:00 → '
        'S-65 có dòng 2 → Lưu → nút "Ghi" vẫn còn, 20:00 ghi được; 00:00 → '
        'chỉ đọc "Mức tạ của buổi này đã khóa", con số chữ thường', (
      tester,
    ) async {
      clock.set(DateTime(2026, 10, 12, 19));
      await pump(tester, tall: true);
      await go(tester, sessionPath(AppTab.today, mon));
      await tapKey(tester, 'session-done');
      expect(find.byKey(const ValueKey('lock-confirm-line2')), findsOneWidget);
      await tapKey(tester, 'lock-confirm-save');
      expect(inSession(key('session-tag-done')), findsOneWidget);
      expect(key('session-done'), findsNothing);
      expect(key('lift-log-${chestMachine.id}'), findsOneWidget);

      await advanceTo(tester, DateTime(2026, 10, 12, 20));
      await tapKey(tester, 'lift-log-${chestMachine.id}');
      await enter(tester, start: '7', end: '8');
      expect(find.text(S.liftLoggedOf(1, 10)), findsOneWidget);

      await advanceTo(tester, DateTime(2026, 10, 13));
      expect(key('session-readonly-locked'), findsOneWidget);
      expect(find.text(S.readOnlyLocked), findsOneWidget);
      expect(key('lift-log-${chestDumbbell.id}'), findsNothing);
      expect(key('lift-value-${chestMachine.id}'), findsNothing);
      expect(key('lift-readonly-${chestMachine.id}'), findsOneWidget);
      // Thanh đáy chỉ còn số bài khi n > 0.
      expect(find.text(S.liftLoggedOf(1, 10)), findsOneWidget);
    });

    testWidgets('F20-AC3, UX-AC36, UA2-17: buổi tập thêm hôm nay Vai và Bụng '
        '→ tiêu đề nhóm, bụng 3 vùng mỗi vùng 1 bài, không có "Ghi" ở bài bụng; '
        'tổng không tính bụng', (tester) async {
      await seedExtra(db, tue, const [MuscleGroup.shoulders, MuscleGroup.abs]);
      clock.set(DateTime(2026, 10, 13, 20, 30));
      await pump(tester, tall: true);
      expect(find.text(S.viewExercisesAndLog), findsOneWidget);
      await tapKey(tester, 'session-view-exercises');
      expect(find.text(S.extraSessionTitle('Vai và Bụng')), findsOneWidget);
      expect(inSession(key('session-tag-extra-saved')), findsOneWidget);
      for (final r in MuscleRegion.of(MuscleGroup.abs)) {
        expect(key('session-region-${r.id}'), findsOneWidget);
      }
      for (final e in library.where((e) => e.group == MuscleGroup.abs)) {
        expect(key('exercise-${e.id}'), findsOneWidget);
        expect(key('lift-log-${e.id}'), findsNothing);
      }
      expect(key('lift-log-${shoulderSide.id}'), findsOneWidget);
      await tapKey(tester, 'lift-log-${shoulderSide.id}');
      await enter(tester, start: '10', end: '12');
      expect(find.text(S.liftLoggedOf(1, 6)), findsOneWidget);
      expect(key('session-done'), findsNothing);
    });

    testWidgets('F20-AC4: buổi thứ 6 tuần sau từ S-21 → "Chỉ xem · Buổi chưa '
        'đến", không ghi được', (tester) async {
      await pump(tester);
      final host = tester.element(find.byType(Scaffold).first);
      unawaited(showDaySheet(host, LocalDate(2026, 10, 16)));
      await tester.pumpAndSettle();
      await tapKey(tester, 'day-view-exercises');
      expect(find.text(S.sessionTitle('Vai')), findsOneWidget);
      expect(find.text(S.readOnlyFuture), findsOneWidget);
      expect(find.text(S.logLiftShort, skipOffstage: false), findsNothing);
    });

    testWidgets('F20-AC5: buổi tuần trước có mức tạ → chỉ đọc, chạm dòng → '
        'S-67 "Buổi này: …" không có "Sửa"', (tester) async {
      final wed = LocalDate(2026, 10, 7);
      final back = exerciseOf(library, MuscleRegion.lats, 'machine');
      await logLift(wed, back, 70, 80);
      await pump(tester, tall: true);
      await go(tester, sessionPath(AppTab.schedule, wed));
      expect(find.text(S.readOnlyLocked), findsOneWidget);
      expect(find.text('7 → 8 kg'), findsOneWidget);
      expect(key('lift-readonly-${back.id}'), findsOneWidget);
      expect(find.text(S.logLiftShort, skipOffstage: false), findsNothing);
      await tapKey(tester, 'exercise-${back.id}');
      expect(find.text(S.backSession), findsOneWidget);
      expect(find.text(S.liftThisSession('7', '8', S.unitKg)), findsOneWidget);
      expect(key('exercise-edit-lift'), findsNothing);
      expect(key('exercise-log-lift'), findsNothing);
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
      await logLift(mon, chestMachine, 70, 80);
      final repo = ExerciseRepository(db);
      await repo.put(chestMachine.copyWith(active: false));
      await repo.put(chestDumbbell.copyWith(active: false));
      await pump(tester);
      await go(tester, sessionPath(AppTab.today, mon));
      expect(key('session-not-in-library-${chestMachine.id}'), findsOneWidget);
      expect(key('exercise-${chestDumbbell.id}'), findsNothing);
      expect(find.text(S.liftLoggedOf(1, 9)), findsOneWidget);
      await tapKey(tester, 'lift-value-${chestMachine.id}');
      await enter(tester, end: '9');
      expect(find.text('7 → 9 kg'), findsOneWidget);
    });

    testWidgets('F20-E2: sửa riêng nhóm cơ hôm nay trước giờ tập → danh sách '
        'bài đổi ngay', (tester) async {
      clock.set(DateTime(2026, 10, 12, 10));
      await pump(tester);
      await go(tester, sessionPath(AppTab.today, mon));
      expect(key('session-group-chest'), findsOneWidget);
      await container
          .read(scheduleEditsProvider)
          .overrideDay(
            mon,
            time: LocalTime(18, 0),
            muscles: const [MuscleGroup.shoulders],
          );
      await tester.pumpAndSettle();
      expect(find.text(S.sessionTitle('Vai')), findsOneWidget);
      expect(key('session-region-${MuscleRegion.deltSide.id}'), findsOneWidget);
      expect(key('session-group-chest'), findsNothing);
    });

    testWidgets('UA2-08: thẻ Hôm nay hiện "Đã ghi mức tạ {n} bài"; buổi đã tập '
        'chỉ có "Xem bài tập"', (tester) async {
      await logLift(mon, chestMachine, 300, 350);
      await logLift(mon, tricepsLong, 100, 125);
      await pump(tester);
      expect(find.text(S.viewExercisesAndLog), findsOneWidget);
      expect(find.text(S.liftLoggedCount(2)), findsOneWidget);
      await seedMark(db, mon, DayMark.done);
      await tester.pumpAndSettle();
      expect(find.text(S.viewExercises), findsOneWidget);
      expect(find.text(S.liftLoggedCount(2)), findsOneWidget);
    });

    testWidgets('NAV-9: Hôm nay → S-25 → dòng ngày → S-21 → "Xem bài tập" → '
        'S-63, quay lại về Hôm nay', (tester) async {
      await pump(tester);
      await go(tester, '/today/progress/2026-10-12');
      await tester.tap(find.text('T2 12/10'));
      await tester.pumpAndSettle();
      await tapKey(tester, 'day-view-exercises');
      expect(find.text(S.sessionTitle('Ngực và Tay sau')), findsOneWidget);
      await tapKey(tester, 'session-back');
      expect(find.text(S.sessionTitle('Ngực và Tay sau')), findsNothing);
    });

    testWidgets(
      'S-21: "Xem bài tập" ở mọi ngày có buổi, không có ở ngày nghỉ',
      (tester) async {
        await pump(tester);
        final host = tester.element(find.byType(Scaffold).first);
        for (final (date, expected) in [
          (LocalDate(2026, 10, 7), true), // Wed, đã qua, chưa đánh dấu
          (mon, true),
          (tue, false),
          (LocalDate(2026, 10, 16), true),
        ]) {
          unawaited(showDaySheet(host, date));
          await tester.pumpAndSettle();
          expect(
            key('day-view-exercises'),
            expected ? findsOneWidget : findsNothing,
            reason: '$date',
          );
          await tester.tapAt(const Offset(20, 20));
          await tester.pumpAndSettle();
        }
      },
    );
  });

  group('S-64', () {
    testWidgets('UX-AC34, F21-AC4 → AC6: buổi trước 12 → 14; kết thúc 12 → '
        'cảnh báo thấp hơn 2 kg, vẫn lưu được; 26 → cao hơn 12 kg; 24 → không '
        'cảnh báo; lần đầu không cảnh báo', (tester) async {
      await logLift(LocalDate(2026, 10, 5), chestDumbbell, 120, 140);
      await pump(tester);
      await go(tester, sessionPath(AppTab.today, mon));
      await tapKey(tester, 'lift-log-${chestDumbbell.id}');
      expect(
        find.text(S.liftPrevious('05/10', '12', '14', S.unitKg)),
        findsOneWidget,
      );
      await enter(tester, start: '10', end: '12', save: false);
      expect(find.text(S.liftEndLower('2', S.unitKg)), findsOneWidget);
      await enter(tester, end: '26', save: false);
      expect(find.text(S.liftEndMuchHigher('12', S.unitKg)), findsOneWidget);
      await enter(tester, end: '24', save: false);
      expect(key('lift-warning-lower'), findsNothing);
      expect(key('lift-warning-muchHigher'), findsNothing);
      await enter(tester, end: '12');
      expect(find.text('10 → 12 kg'), findsOneWidget);

      await tapKey(tester, 'lift-log-${chestMachine.id}');
      expect(find.text(S.liftFirstTime), findsOneWidget);
      await enter(tester, start: '1', end: '1', save: false);
      expect(key('lift-warning-lower'), findsNothing);
    });

    testWidgets('F21-AC8, F21-V1 → V4: lỗi đỏ dưới ô, không lưu', (
      tester,
    ) async {
      await pump(tester);
      await go(tester, sessionPath(AppTab.today, mon));
      await tapKey(tester, 'lift-log-${chestDumbbell.id}');
      for (final (start, end, message) in [
        ('35', '', S.liftMissing),
        ('35', '72,3', S.liftKgInvalid),
        ('0', '10', S.liftKgInvalid),
        ('300.5', '10', S.liftKgInvalid),
        ('1,2,3', '10', S.liftNotNumber),
      ]) {
        await enter(tester, start: start, end: end);
        expect(find.text(message), findsOneWidget, reason: '$start/$end');
      }
      expect(await logs.get(mon, chestDumbbell.id), isNull);
      // "." hiện thành "," (UR-10).
      await enter(tester, start: '72.5', end: '75', save: false);
      expect(find.text('72,5'), findsWidgets);
      await tapKey(tester, 'lift-save');
      expect((await logs.get(mon, chestDumbbell.id))!.startKgX10, 725);
    });

    testWidgets('UA2-10: hai ô trống lúc mở, − / + chỉ bấm được khi có số '
        '(chưa bấm được thì mờ); Kết thúc trống lấy Bắt đầu làm điểm xuất '
        'phát; chặn ở 0,5 và 300', (tester) async {
      await pump(tester);
      await go(tester, sessionPath(AppTab.today, mon));
      await tapKey(tester, 'lift-log-${chestDumbbell.id}');
      IconButton button(String k) => tester.widget<IconButton>(
        find.descendant(of: key(k), matching: find.byType(IconButton)),
      );
      Color? iconColor(String k) => IconTheme.of(
        tester.element(
          find.descendant(of: key(k), matching: find.byType(Icon)),
        ),
      ).color;
      final primary = Theme.of(
        tester.element(key('lift-save')),
      ).colorScheme.primary;
      const buttons = [
        'lift-start-minus',
        'lift-start-plus',
        'lift-end-minus',
        'lift-end-plus',
      ];
      for (final k in buttons) {
        expect(button(k).onPressed, isNull, reason: k);
        expect(iconColor(k), primary.withAlpha(70), reason: k);
      }
      await enter(tester, start: '35', save: false);
      expect(button('lift-end-plus').onPressed, isNotNull);
      for (final k in buttons) {
        expect(iconColor(k), primary, reason: k);
      }
      await tapKey(tester, 'lift-end-plus');
      expect(find.text('35,5'), findsWidgets);
      await tapKey(tester, 'lift-start-minus');
      expect(find.text('34,5'), findsWidgets);
      await enter(tester, start: '0,5', end: '300', save: false);
      await tapKey(tester, 'lift-start-minus');
      await tapKey(tester, 'lift-end-plus');
      expect(find.text('0,5'), findsWidgets);
      expect(find.text('300'), findsWidgets);
    });

    testWidgets('FA2-17, F21-E4, F21-R12: mở lúc 23:58, bấm Lưu lúc 00:01 → '
        'hộp "Mức tạ của buổi này đã khóa lúc 00:00." → "Đã hiểu" → S-63 chỉ '
        'đọc, không lưu gì', (tester) async {
      clock.set(DateTime(2026, 10, 12, 23, 58));
      await pump(tester, tall: true);
      await go(tester, sessionPath(AppTab.today, mon));
      await tapKey(tester, 'lift-log-${chestDumbbell.id}');
      await enter(tester, start: '35', end: '40', save: false);
      clock.set(DateTime(2026, 10, 13, 0, 1));
      await tapKey(tester, 'lift-save');
      expect(find.text(S.liftLockedAtMidnight), findsOneWidget);
      await tapKey(tester, 'lift-locked-ok');
      expect(find.text(S.liftLockedAtMidnight), findsNothing);
      expect(key('lift-save'), findsNothing);
      scheduler.fireSync();
      await tester.pumpAndSettle();
      expect(find.text(S.readOnlyLocked), findsOneWidget);
      expect(await logs.get(mon, chestDumbbell.id), isNull);
    });
  });

  group('S-67 khu mức tạ', () {
    testWidgets('từ S-63 trong cửa sổ: chưa ghi → "Buổi trước" + "Ghi mức tạ" '
        '→ S-64; đã ghi → "Buổi này" + "Sửa"', (tester) async {
      await logLift(LocalDate(2026, 10, 5), chestDumbbell, 120, 140);
      await pump(tester, tall: true);
      await go(
        tester,
        sessionExercisePath(AppTab.today, mon, chestDumbbell.id),
      );
      expect(
        find.text(S.liftPrevious('05/10', '12', '14', S.unitKg)),
        findsOneWidget,
      );
      await tapKey(tester, 'exercise-log-lift');
      await enter(tester, start: '12', end: '15');
      expect(
        find.text(S.liftThisSession('12', '15', S.unitKg)),
        findsOneWidget,
      );
      await tapKey(tester, 'exercise-edit-lift');
      expect(key('lift-delete'), findsOneWidget);
    });

    testWidgets('F19-AC3, F19-AC4: từ thư viện — đã có bản ghi → "Gần nhất"; '
        'chưa có → ẩn; bài bụng → không có khu (UX-AC36)', (tester) async {
      await logLift(LocalDate(2026, 10, 5), chestDumbbell, 120, 140);
      await logLift(LocalDate(2026, 10, 7), chestDumbbell, 125, 145);
      await pump(tester, tall: true);
      await go(tester, '/schedule/exercise/${chestDumbbell.id}?from=library');
      expect(
        find.text(S.liftLatest('07/10', '12,5', '14,5', S.unitKg)),
        findsOneWidget,
      );
      expect(key('exercise-log-lift'), findsNothing);
      await go(tester, '/schedule/exercise/${chestMachine.id}?from=library');
      expect(key('exercise-lift-area'), findsNothing);
      await logLift(LocalDate(2026, 10, 7), absLower, 10, 10);
      await go(tester, sessionExercisePath(AppTab.today, mon, absLower.id));
      expect(key('exercise-lift-area'), findsNothing);
    });

    testWidgets(
      'UA2-18: bài đã rời thư viện, mở từ S-63 trong cửa sổ, chưa ghi '
      '→ không có "Ghi mức tạ"',
      (tester) async {
        await logLift(LocalDate(2026, 10, 5), chestMachine, 70, 80);
        await ExerciseRepository(db).put(chestMachine.copyWith(active: false));
        await pump(tester, tall: true);
        await go(
          tester,
          sessionExercisePath(AppTab.today, mon, chestMachine.id),
        );
        expect(key('exercise-log-lift'), findsNothing);
        expect(
          find.text(S.liftLatest('05/10', '7', '8', S.unitKg)),
          findsOneWidget,
        );
      },
    );
  });

  group('F05-R28', () {
    testWidgets('F05-AC28, F21-E6: buổi có mức tạ 2 bài → "Không tập" ở Hôm '
        'nay hỏi "Buổi này đã có mức tạ của 2 bài."; Hủy không đổi gì; Tiếp '
        'tục → lưu, mức tạ giữ nguyên', (tester) async {
      await logLift(mon, chestMachine, 300, 350);
      await logLift(mon, tricepsLong, 100, 125);
      await pump(tester);
      await tapKey(tester, 'mark-skipped-${mon.toKey()}');
      expect(find.text(S.liftLogsExist(2)), findsOneWidget);
      await tapKey(tester, 'lifts-kept-cancel');
      expect((await ScheduleRepository(db).day(mon))!.mark, isNull);
      await tapKey(tester, 'mark-skipped-${mon.toKey()}');
      await tapKey(tester, 'lifts-kept-continue');
      expect((await ScheduleRepository(db).day(mon))!.mark, DayMark.skipped);
      expect(find.text(S.markedSkipped), findsOneWidget);
      expect(await logs.countDay(mon), 2);
    });

    testWidgets('S-21: hộp F05-R28 trước khi lưu, bảng đóng sau "Tiếp tục"', (
      tester,
    ) async {
      await logLift(mon, chestMachine, 300, 350);
      await pump(tester);
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
      expect(key('day-view-exercises'), findsNothing);
      expect((await ScheduleRepository(db).day(mon))!.mark, DayMark.skipped);
    });

    testWidgets('không có mức tạ → "Không tập" lưu ngay, không hỏi', (
      tester,
    ) async {
      await pump(tester);
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
      await pump(tester);
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
}
