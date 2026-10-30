import 'package:domain/domain.dart';
import 'package:drift/native.dart';
import 'package:fl_chart/fl_chart.dart';
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
import 'package:mobile/features/progress/presentation/lift_chart_screen.dart';
import 'package:mobile/features/training/application/training_section.dart';
import 'package:mobile/features/workout/data/exercise_unit_repository.dart';
import 'package:mobile/features/workout/data/lift_log_repository.dart';
import 'package:mobile/features/workout/presentation/session_screen.dart';

import '../../support/app_harness.dart';
import '../../support/fake_server.dart';
import '../../support/fake_sync.dart';
import '../../support/library_fixture.dart';
import '../../support/schedule_fixture.dart';

/// 06 Bản 2 VS28-T06 (widget): S-68, S-69, lối vào biểu đồ ở S-67; 06 Bản 3
/// VS37-T05: đơn vị trên S-68, S-69, mốc đổi đơn vị.
void main() {
  late AppDatabase db;
  late FixedClock clock;
  late ProviderContainer container;
  late FakeConnectivity connectivity;
  late List<Exercise> library;
  late LiftLogRepository logs;

  late Exercise press;
  late Exercise machine;
  late Exercise lats;
  late Exercise row;
  late Exercise shoulder;
  late Exercise abs;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    clock = FixedClock(DateTime(2026, 10, 12, 19));
    connectivity = FakeConnectivity();
    logs = LiftLogRepository(db);
    await seedSetUp(db);
    library = await seedLibrary(db);
    press = exerciseOf(library, MuscleRegion.chestUpper, 'free-weight');
    machine = exerciseOf(library, MuscleRegion.chestUpper, 'machine');
    lats = exerciseOf(library, MuscleRegion.lats, 'machine');
    row = exerciseOf(library, MuscleRegion.backMid, 'free-weight');
    shoulder = exerciseOf(library, MuscleRegion.deltFront, 'machine');
    abs = exerciseOf(library, MuscleRegion.absLower);
  });

  Future<void> log(Exercise e, LocalDate date, int start, int end) => logs.put(
    LiftLog(date: date, exerciseId: e.id, startKgX10: start, endKgX10: end),
  );

  Future<void> pump(WidgetTester tester) async {
    tester.view
      ..physicalSize = const Size(390 * 3, 2400 * 3)
      ..devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    container = ProviderContainer(
      retry: (_, _) => null,
      overrides: [
        ...appOverrides(
          db: db,
          clock: clock,
          scheduler: FakeScheduler(),
          server: FakeServer(),
          connectivity: connectivity,
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

  Future<void> go(WidgetTester tester, String path) async {
    container.read(routerProvider).go(path);
    await tester.pumpAndSettle();
  }

  Future<void> openProgress(WidgetTester tester) async {
    await go(tester, '/schedule');
    container
        .read(trainingTabProvider.notifier)
        .select(TrainingSection.progress);
    await tester.pumpAndSettle();
  }

  Future<void> tapKey(WidgetTester tester, String key) async {
    final f = find.byKey(ValueKey(key));
    await tester.ensureVisible(f);
    await tester.pumpAndSettle();
    await tester.tap(f);
    await tester.pumpAndSettle();
  }

  Finder key(String k) => find.byKey(ValueKey(k));

  double top(WidgetTester t, String k) => t.getTopLeft(key(k)).dy;

  group('S-68', () {
    testWidgets('UX-AC41, F23-AC4, F23-AC5: chưa ghi bài nào → câu F23-R4, '
        'không có nút', (tester) async {
      await pump(tester);
      await openProgress(tester);
      expect(key('progress-empty'), findsOneWidget);
      expect(find.text(S.progressEmptyBody), findsOneWidget);
      expect(
        find.descendant(
          of: key('progress-empty'),
          matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
        ),
        findsNothing,
      );
    });

    testWidgets('F23-AC1, F23-AC2, F23-R5: 3 bài hôm nay ở trên, 2 bài tuần '
        'trước; mỗi dòng mức tạ và ngày gần nhất; bài bụng không có; bài rời '
        'thư viện có ghi chú; F23-AC3: chạm → biểu đồ đúng bài', (
      tester,
    ) async {
      final mon = LocalDate(2026, 10, 12);
      final last = LocalDate(2026, 10, 5);
      await log(press, last, 100, 110);
      await log(press, mon, 100, 120);
      await log(machine, mon, 300, 350);
      await log(shoulder, mon, 250, 300);
      await log(lats, last, 400, 450);
      await log(row, LocalDate(2026, 10, 7), 160, 180);
      await log(abs, mon, 10, 10);
      await ExerciseRepository(db).put(row.copyWith(active: false));
      await pump(tester);
      await openProgress(tester);
      expect(find.text(S.progressHint), findsOneWidget);
      final order = [machine, press, shoulder, row, lats];
      final tops = [for (final e in order) top(tester, 'progress-${e.id}')];
      expect(tops, orderedEquals([...tops]..sort()));
      expect(key('progress-${abs.id}'), findsNothing);
      expect(
        find.descendant(
          of: key('progress-${press.id}'),
          matching: find.text('10 → 12 kg'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: key('progress-${press.id}'),
          matching: find.text('12/10'),
        ),
        findsOneWidget,
      );
      expect(key('progress-not-in-library-${row.id}'), findsOneWidget);
      await tapKey(tester, 'progress-${lats.id}');
      expect(find.text(lats.nameVi), findsOneWidget);
      expect(find.text(S.backProgress), findsOneWidget);
    });

    testWidgets('F23-E1, F23-E2: ghi tạ hôm nay → bài lên đầu ngay; xóa bản '
        'ghi duy nhất → bài biến mất', (tester) async {
      await log(lats, LocalDate(2026, 10, 7), 400, 450);
      await pump(tester);
      await go(tester, sessionPath(AppTab.schedule, LocalDate(2026, 10, 12)));
      await tapKey(tester, 'lift-row-${press.id}');
      await tapKey(tester, 'lift-unit-kg');
      await tester.enterText(key('field-lift-start'), '10');
      await tester.enterText(key('field-lift-end'), '12');
      await tester.pumpAndSettle();
      await tapKey(tester, 'lift-save');
      await openProgress(tester);
      expect(
        top(tester, 'progress-${press.id}'),
        lessThan(top(tester, 'progress-${lats.id}')),
      );
      await logs.delete(LocalDate(2026, 10, 12), press.id);
      await tester.pumpAndSettle();
      expect(key('progress-${press.id}'), findsNothing);
    });
  });

  group('S-69', () {
    testWidgets('UX-AC38, F22-AC2, F22-AC3, F22-E1: mặc định tháng hiện tại '
        '(1 điểm); "‹" lùi từng tháng tới tháng có bản ghi đầu tiên rồi mờ; '
        '"›" ẩn ở tháng hiện tại; tháng giữa trống → "Chưa có mức tạ trong '
        'tháng này"', (tester) async {
      clock.set(DateTime(2026, 11, 2, 19));
      await log(press, LocalDate(2026, 8, 31), 80, 90);
      await log(press, LocalDate(2026, 10, 5), 100, 120);
      await log(press, LocalDate(2026, 10, 7), 100, 100);
      await log(press, LocalDate(2026, 11, 2), 110, 125);
      await pump(tester);
      await go(tester, liftChartPath(press.id));
      expect(find.text(S.chartMonth(11, 2026)), findsOneWidget);
      expect(key('chart-month-next'), findsNothing);
      expect(key('chart-row-2026-11-02'), findsOneWidget);
      expect(find.bySemanticsLabel(S.chartSemantics(11, 1)), findsOneWidget);
      await tapKey(tester, 'chart-month-previous');
      expect(find.text(S.chartMonth(10, 2026)), findsOneWidget);
      expect(key('chart-month-next'), findsOneWidget);
      // Danh sách mới nhất ở trên; bằng nhau → "{a} → {a} kg" (F22-E3).
      expect(
        tester.getTopLeft(key('chart-row-2026-10-07')).dy,
        lessThan(tester.getTopLeft(key('chart-row-2026-10-05')).dy),
      );
      expect(find.text('10 → 10 kg'), findsOneWidget);
      await tapKey(tester, 'chart-month-previous');
      expect(find.text(S.chartMonth(9, 2026)), findsOneWidget);
      expect(key('chart-month-empty'), findsOneWidget);
      expect(find.text(S.chartMonthEmpty), findsOneWidget);
      await tapKey(tester, 'chart-month-previous');
      expect(find.text(S.chartMonth(8, 2026)), findsOneWidget);
      final previous = tester.widget<IconButton>(key('chart-month-previous'));
      expect(previous.onPressed, isNull, reason: 'tháng có bản ghi đầu tiên');
      await tapKey(tester, 'chart-month-next');
      await tapKey(tester, 'chart-month-next');
      await tapKey(tester, 'chart-month-next');
      expect(find.text(S.chartMonth(11, 2026)), findsOneWidget);
    });

    testWidgets('chạm một ngày → ô "{dd/mm} · {a} → {b} kg"; F22-AC5: không có '
        'mạng vẫn mở được', (tester) async {
      connectivity.online = false;
      await log(press, LocalDate(2026, 10, 5), 100, 120);
      await log(press, LocalDate(2026, 10, 7), 110, 130);
      await pump(tester);
      await go(tester, liftChartPath(press.id));
      final chart = tester.getRect(key('lift-chart'));
      // Trục ngang 0,5 → 31,5 sau phần nhãn trái 40 điểm.
      final dayWidth = (chart.width - 40) / 31;
      await tester.tapAt(
        Offset(chart.left + 40 + (7 - 0.5) * dayWidth, chart.center.dy),
      );
      await tester.pumpAndSettle();
      // Ô được vẽ trên canvas: kiểm tra điểm đang hiện ô và chữ của ô.
      final data = tester.widget<LineChart>(find.byType(LineChart)).data;
      final shown = data.showingTooltipIndicators.single.showingSpots;
      expect(shown.single.x, 7);
      final items = data.lineTouchData.touchTooltipData.getTooltipItems(shown);
      expect(items.single?.text, S.chartTooltip('07/10', '11', '13', S.unitKg));
    });

    testWidgets('"Xem bài" → S-67, quay lại "Tiến bộ"; S-67 "Xem biểu đồ" quay '
        'lại đúng biểu đồ', (tester) async {
      await log(press, LocalDate(2026, 10, 5), 100, 120);
      await pump(tester);
      await go(tester, liftChartPath(press.id));
      await tapKey(tester, 'chart-view-exercise');
      expect(find.text(S.backProgress), findsOneWidget);
      await tapKey(tester, 'exercise-view-chart');
      expect(key('lift-chart'), findsOneWidget);
    });
  });

  group('S-67 lối vào biểu đồ', () {
    testWidgets('F19-AC3, F22-AC6, UX-AC36: bài có 2 bản ghi → "Xem biểu đồ" '
        '→ S-69, quay lại "Chi tiết bài"; bài chưa ghi, bài bụng → không có', (
      tester,
    ) async {
      await log(press, LocalDate(2026, 10, 5), 100, 120);
      await log(press, LocalDate(2026, 10, 7), 110, 130);
      await log(abs, LocalDate(2026, 10, 7), 10, 10);
      await pump(tester);
      await go(tester, '/schedule/exercise/${press.id}?from=library');
      await tapKey(tester, 'exercise-view-chart');
      expect(find.text(S.backExerciseDetail), findsOneWidget);
      expect(key('lift-chart'), findsOneWidget);
      await tapKey(tester, 'chart-view-exercise');
      expect(key('exercise-view-chart'), findsOneWidget);
      await go(tester, '/schedule/exercise/${machine.id}?from=library');
      expect(key('exercise-view-chart'), findsNothing);
      await go(tester, '/schedule/exercise/${abs.id}?from=library');
      expect(key('exercise-view-chart'), findsNothing);
    });
  });

  group('Bản 3: đơn vị (VS37-T05)', () {
    late List<Exercise> v3;
    late Exercise pecDeck;
    late Exercise legExtension;
    late Exercise shoulderPress;

    Future<void> setUnit(Exercise e, LiftUnit u, LocalDate on) =>
        ExerciseUnitRepository(
          db,
        ).put(ExerciseUnit(exerciseId: e.id, unit: u, changedOn: on));

    setUp(() async {
      v3 = await seedLibrary(db, realLibraryV3());
      pecDeck = v3.firstWhere((e) => e.id == 'chest-mid-machine-pec-deck');
      legExtension = v3.firstWhere(
        (e) => e.id == 'legs-quads-seated-leg-extension',
      );
      shoulderPress = v3.firstWhere(
        (e) => e.id == 'delt-front-machine-machine-shoulder-press',
      );
    });

    testWidgets('F23-AC41, UX-AC56: mỗi dòng đúng đơn vị của bài; F23-AC42: '
        'cùng ngày "Máy ép ngực" trước "Ngồi máy đẩy vai"', (tester) async {
      final day = LocalDate(2026, 10, 12);
      await setUnit(shoulderPress, LiftUnit.steps, day);
      await log(shoulderPress, day, 80, 100);
      await setUnit(pecDeck, LiftUnit.kg, day);
      await log(pecDeck, day, 400, 475);
      await pump(tester);
      await openProgress(tester);
      expect(
        find.descendant(
          of: key('progress-${pecDeck.id}'),
          matching: find.text('40 → 47,5 kg'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: key('progress-${shoulderPress.id}'),
          matching: find.text('8 → 10 nấc'),
        ),
        findsOneWidget,
      );
      expect(
        top(tester, 'progress-${pecDeck.id}'),
        lessThan(top(tester, 'progress-${shoulderPress.id}')),
      );
    });

    testWidgets('F22-AC41, F22-AC42, UX-AC55: 3 điểm kg rồi đổi sang nấc 10/10 '
        '→ trục "nấc", chú giải "đơn vị: nấc máy", mốc "Đổi sang nấc" (VoiceOver '
        'đọc ngày), bản ghi trước mốc "· trước khi đổi"; bài kg → trục "kg", '
        'không mốc', (tester) async {
      await log(legExtension, LocalDate(2026, 10, 1), 400, 450);
      await log(legExtension, LocalDate(2026, 10, 5), 420, 470);
      await log(legExtension, LocalDate(2026, 10, 7), 450, 500);
      await log(legExtension, LocalDate(2026, 10, 12), 80, 100);
      await setUnit(legExtension, LiftUnit.steps, LocalDate(2026, 10, 10));
      await pump(tester);
      await go(tester, liftChartPath(legExtension.id));
      expect(tester.widget<Text>(key('chart-axis-unit')).data, S.unitSteps);
      expect(find.text(S.chartLegendUnit(S.unitStepsFull)), findsOneWidget);
      final chart = tester.widget<LineChart>(find.byType(LineChart));
      final lines = chart.data.extraLinesData.verticalLines;
      expect([for (final l in lines) l.x], [10]);
      expect(lines.single.label.labelResolver(lines.single), 'Đổi sang nấc');
      expect(
        find.bySemanticsLabel(
          '${S.chartSemantics(10, 4)}. '
          '${S.unitChangeSemantics(S.unitSteps, '10/10')}',
        ),
        findsOneWidget,
      );
      expect(find.text('T4 07/10 ${S.beforeUnitChange}'), findsOneWidget);
      expect(find.text('T2 12/10'), findsOneWidget);
      expect(
        tester.widget<Text>(key('chart-row-2026-10-07')).data,
        '45 → 50 nấc',
        reason: 'số giữ nguyên, không quy đổi',
      );

      await setUnit(pecDeck, LiftUnit.kg, LocalDate(2026, 10, 12));
      await log(pecDeck, LocalDate(2026, 10, 12), 400, 450);
      await go(tester, liftChartPath(pecDeck.id));
      expect(tester.widget<Text>(key('chart-axis-unit')).data, S.unitKg);
      expect(
        tester
            .widget<LineChart>(find.byType(LineChart))
            .data
            .extraLinesData
            .verticalLines,
        isEmpty,
      );
    });

    testWidgets('S-69 chữ lớn nhất: dòng "· trước khi đổi" với số dài không '
        'tràn', (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 3.1;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await log(legExtension, LocalDate(2026, 10, 9), 1055, 1150);
      await log(legExtension, LocalDate(2026, 10, 12), 80, 100);
      await setUnit(legExtension, LiftUnit.steps, LocalDate(2026, 10, 10));
      await pump(tester);
      await go(tester, liftChartPath(legExtension.id));
      await tester.ensureVisible(key('chart-row-2026-10-09'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(
        tester.widget<Text>(key('chart-row-2026-10-09')).data,
        '105,5 → 115 nấc',
      );
    });
  });
}
