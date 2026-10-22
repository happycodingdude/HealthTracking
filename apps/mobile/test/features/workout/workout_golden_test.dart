@Tags(['golden'])
library;

import 'package:domain/domain.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/app/app.dart';
import 'package:mobile/app/router.dart';
import 'package:mobile/app/shell/app_tab.dart';
import 'package:mobile/data/db/app_database.dart';
import 'package:mobile/features/library/data/video_player_gateway.dart';
import 'package:mobile/features/schedule/data/schedule_repository.dart';
import 'package:mobile/features/workout/data/exercise_note_repository.dart';
import 'package:mobile/features/workout/data/exercise_unit_repository.dart';
import 'package:mobile/features/workout/data/lift_log_repository.dart';
import 'package:mobile/features/workout/presentation/session_screen.dart';

import '../../support/app_harness.dart';
import '../../support/golden.dart';
import '../../support/library_fixture.dart';
import '../../support/schedule_fixture.dart';

/// 06 Bản 3 VS36-T06 (golden): S-63 (3 biến thể theo mock S-63-1 → 3), S-64
/// (4 dạng theo mock S-64-1 → 4), khu mức tạ của S-67, S-10 có phần bài tập
/// — sáng/tối × cỡ chữ lớn nhất (UX-AC63). Dữ liệu `sessionChestV3`.
void main() {
  final mon = LocalDate(2026, 10, 12);
  final tue = LocalDate(2026, 10, 13);
  final prevMon = LocalDate(2026, 10, 5);

  late List<Exercise> library;
  late FixedClock clock;

  List<Exercise> group(MuscleGroup g) => [
    for (final e in library)
      if (e.group == g) e,
  ];

  Future<void> log(
    AppDatabase db,
    LocalDate date,
    Exercise e,
    int start,
    int end,
  ) => LiftLogRepository(db).put(
    LiftLog(date: date, exerciseId: e.id, startKgX10: start, endKgX10: end),
  );

  Future<void> unit(AppDatabase db, Exercise e, LiftUnit u) =>
      ExerciseUnitRepository(
        db,
      ).put(ExerciseUnit(exerciseId: e.id, unit: u, changedOn: prevMon));

  Future<void> note(AppDatabase db, LocalDate date, Exercise e, String text) =>
      ExerciseNoteRepository(
        db,
      ).put(ExerciseNote(date: date, exerciseId: e.id, text: text));

  /// Ngực: "Máy ép ngực" 40 → 45 kg, "Nằm ghế ngang đẩy thanh tạ" 50 → 55 kg
  /// (ghi chú "máy 2 hỏng, tập máy 5"), "Nằm máy dốc lên" 8 → 10 nấc, bài 4
  /// chưa từng ghi — đều của thứ 2 tuần trước.
  Future<AppDatabase> seeded() async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await seedSetUp(db);
    library = await seedLibrary(db, realLibraryV3());
    final chest = group(MuscleGroup.chest);
    await unit(db, chest[0], LiftUnit.kg);
    await log(db, prevMon, chest[0], 400, 450);
    await unit(db, chest[1], LiftUnit.kg);
    await log(db, prevMon, chest[1], 500, 550);
    await note(db, prevMon, chest[1], 'máy 2 hỏng, tập máy 5');
    await unit(db, chest[2], LiftUnit.steps);
    await log(db, prevMon, chest[2], 80, 100);
    return db;
  }

  Future<ProviderContainer> pump(
    WidgetTester tester,
    GoldenVariant variant,
    AppDatabase db,
    DateTime now,
  ) async {
    setPhoneSurface(tester);
    tester.platformDispatcher
      ..platformBrightnessTestValue = variant.brightness
      ..textScaleFactorTestValue = variant.textScale;
    addTearDown(tester.platformDispatcher.clearAllTestValues);
    clock = FixedClock(now);
    final container = ProviderContainer(
      retry: (_, _) => null,
      overrides: [
        ...appOverrides(db: db, clock: clock),
        videoPlayerGatewayProvider.overrideWithValue(FakeVideoGateway()),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const IronlyApp()),
    );
    await tester.pumpAndSettle();
    return container;
  }

  Future<void> go(
    WidgetTester tester,
    ProviderContainer container,
    String path,
  ) async {
    container.read(routerProvider).go(path);
    await tester.pumpAndSettle();
  }

  /// Chạm nút trong bảng S-64 (dựng đủ, chỉ cần cuộn tới).
  Future<void> tapKey(WidgetTester tester, String key) async {
    final f = find.byKey(ValueKey(key));
    await tester.ensureVisible(f);
    await tester.pumpAndSettle();
    await tester.tap(f);
    await tester.pumpAndSettle();
  }

  /// Chạm nút trên dòng bài của S-63: danh sách chỉ dựng phần đang thấy.
  Future<void> tapRow(WidgetTester tester, String key) async {
    final f = find.byKey(ValueKey(key));
    await tester.scrollUntilVisible(
      f,
      200,
      scrollable: find.descendant(
        of: find.byKey(const ValueKey('session-list')),
        matching: find.byType(Scrollable),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(f);
    await tester.pumpAndSettle();
  }

  Future<void> unfocus(WidgetTester tester) async {
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
  }

  Future<void> snap(String name) => expectLater(
    find.byType(MaterialApp),
    matchesGoldenFile('goldens/$name.png'),
  );

  for (final v in GoldenVariant.all) {
    testWidgets('S-63-1 trong cửa sổ: buổi trước mờ, bài đã ghi, biểu tượng '
        'ghi chú, "Ghi" ${v.name}', (tester) async {
      final db = await seeded();
      final chest = group(MuscleGroup.chest);
      await log(db, mon, chest[0], 400, 475);
      await note(db, mon, chest[0], 'ghế số 3');
      final c = await pump(tester, v, db, DateTime(2026, 10, 12, 18, 30));
      await go(tester, c, sessionPath(AppTab.today, mon));
      await snap('s63_window_${v.name}');
    });

    testWidgets('S-63-2 buổi Chân và Bụng: danh sách phẳng theo nhóm, bài bụng '
        'có "Ghi chú" ${v.name}', (tester) async {
      final db = await seeded();
      final legs = group(MuscleGroup.legs);
      await unit(db, legs[0], LiftUnit.kg);
      await log(db, prevMon, legs[0], 800, 900);
      await unit(db, legs[1], LiftUnit.steps);
      await log(db, prevMon, legs[1], 80, 100);
      final schedule = ScheduleRepository(db);
      final day = (await schedule.day(mon))!;
      await schedule.putDay(
        PlanDay(
          date: mon,
          kind: DayKind.workout,
          time: day.time,
          muscles: const [MuscleGroup.legs, MuscleGroup.abs],
          source: DaySource.override,
        ),
      );
      final c = await pump(tester, v, db, DateTime(2026, 10, 12, 18, 30));
      await go(tester, c, sessionPath(AppTab.today, mon));
      await snap('s63_legs_abs_${v.name}');
    });

    testWidgets('S-63-3 buổi ngày mai: chỉ xem, "GẦN NHẤT" ${v.name}', (
      tester,
    ) async {
      final db = await seeded();
      final back = group(MuscleGroup.back);
      await unit(db, back[0], LiftUnit.kg);
      await log(db, LocalDate(2026, 10, 7), back[0], 350, 400);
      await unit(db, back[2], LiftUnit.steps);
      await log(db, LocalDate(2026, 10, 7), back[2], 90, 100);
      final c = await pump(tester, v, db, DateTime(2026, 10, 13, 18, 30));
      await go(
        tester,
        c,
        sessionPath(AppTab.schedule, LocalDate(2026, 10, 14)),
      );
      await snap('s63_upcoming_${v.name}');
    });

    testWidgets('S-64-1 điền sẵn, +2,5 ở Kết thúc, ghi chú buổi trước mờ '
        '${v.name}', (tester) async {
      final db = await seeded();
      final chest = group(MuscleGroup.chest);
      final c = await pump(tester, v, db, DateTime(2026, 10, 12, 18, 30));
      await go(tester, c, sessionPath(AppTab.today, mon));
      await tapRow(tester, 'lift-prev-tap-${chest[1].id}');
      await tapKey(tester, 'lift-end-plus');
      await unfocus(tester);
      await snap('s64_prefill_${v.name}');
    });

    testWidgets('S-64-2 lần ghi đầu: chọn kg ${v.name}', (tester) async {
      final db = await seeded();
      final chest = group(MuscleGroup.chest);
      final c = await pump(tester, v, db, DateTime(2026, 10, 12, 18, 30));
      await go(tester, c, sessionPath(AppTab.today, mon));
      await tapRow(tester, 'lift-log-${chest[3].id}');
      await tapKey(tester, 'lift-unit-kg');
      await snap('s64_first_${v.name}');
    });

    testWidgets('S-64-3 nấc máy, sửa bản ghi, cảnh báo cao hơn 5 nấc '
        '${v.name}', (tester) async {
      final db = await seeded();
      final chest = group(MuscleGroup.chest);
      await log(db, mon, chest[2], 80, 140);
      final c = await pump(tester, v, db, DateTime(2026, 10, 12, 18, 30));
      await go(tester, c, sessionPath(AppTab.today, mon));
      await tapRow(tester, 'lift-value-${chest[2].id}');
      await tapKey(tester, 'lift-end-plus');
      await unfocus(tester);
      await snap('s64_steps_warning_${v.name}');
    });

    testWidgets('S-64-4 ghi chú bài bụng ${v.name}', (tester) async {
      final db = await seeded();
      final plank = exerciseOf(library, MuscleRegion.absMid);
      await note(db, LocalDate(2026, 10, 6), plank, 'giữ được 45 giây');
      await seedExtra(db, tue, const [MuscleGroup.abs]);
      final c = await pump(tester, v, db, DateTime(2026, 10, 13, 20, 30));
      await go(tester, c, sessionPath(AppTab.today, tue));
      await tapRow(tester, 'note-log-${plank.id}');
      await tester.enterText(
        find.byKey(const ValueKey('note-input')),
        'giữ được 60 giây, lần 3 hơi run',
      );
      await unfocus(tester);
      await snap('s64_note_only_${v.name}');
    });

    testWidgets('S-67 khu mức tạ mở từ S-63, có buổi trước ${v.name}', (
      tester,
    ) async {
      final db = await seeded();
      final e = group(MuscleGroup.chest)[1];
      final c = await pump(tester, v, db, DateTime(2026, 10, 12, 18, 30));
      await go(tester, c, sessionExercisePath(AppTab.today, mon, e.id));
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('exercise-lift-area')),
        300,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.pumpAndSettle();
      await snap('s67_lift_area_${v.name}');
    });

    testWidgets('S-10-2 thẻ buổi tập có phần bài tập ${v.name}', (
      tester,
    ) async {
      final db = await seeded();
      await log(db, mon, group(MuscleGroup.chest)[0], 400, 450);
      await log(
        db,
        mon,
        exerciseOf(library, MuscleRegion.tricepsLong),
        100,
        125,
      );
      await pump(tester, v, db, DateTime(2026, 10, 12, 18, 30));
      await snap('s10_session_exercises_${v.name}');
    });
  }
}
