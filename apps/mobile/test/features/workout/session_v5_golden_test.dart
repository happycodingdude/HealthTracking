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
import 'package:mobile/features/workout/application/session_item_edits.dart';
import 'package:mobile/features/workout/data/exercise_feel_repository.dart';
import 'package:mobile/features/workout/data/exercise_note_repository.dart';
import 'package:mobile/features/workout/data/exercise_unit_repository.dart';
import 'package:mobile/features/workout/data/lift_log_repository.dart';
import 'package:mobile/features/workout/presentation/pick_exercise_screen.dart';
import 'package:mobile/features/workout/presentation/session_screen.dart';

import '../../support/app_harness.dart';
import '../../support/golden.dart';
import '../../support/library_fixture.dart';
import '../../support/schedule_fixture.dart';

/// 06 Bản 5 VS53-T05 (golden, `reviewMatrix` ED5-09): S-10 H4 dòng bài gốc +
/// bài thay, S-74 (bài gốc, bài thay), S-75 "Đổi bài", S-78 "Đổi bài?", S-63
/// buổi đã qua có bài thay — theme tối × 2 cỡ chữ. Buổi Ngực + Tay sau thứ 2
/// 12/10 18:00; "Nằm ghế ngang đẩy thanh tạ" đổi sang "Máy dốc gắn bánh tạ".
///
/// VS55-T05: S-64 có mức thoải mái (kg, nấc máy, bài bụng), S-10 dòng có dấu
/// ba vạch (cam hôm nay, xám buổi trước — mock s10-h4), S-63 buổi đã qua có
/// dấu ba vạch cam (mock s63).
void main() {
  final mon = LocalDate(2026, 10, 12);
  final prevMon = LocalDate(2026, 10, 5);
  late List<Exercise> library;
  late AppDatabase lastDb;

  List<Exercise> chest() => [
    for (final e in library)
      if (e.group == MuscleGroup.chest) e,
  ];
  Exercise backPlate() => library.firstWhere(
    (e) => e.id == 'back-back-mid-plate-loaded-row-machine',
  );

  Exercise plank() => exerciseOf(library, MuscleRegion.absMid);

  // Mock s10-h4: buổi Ngực 18:00 thứ 2 (một nhóm).
  final chestOnly = WeeklyTemplate({
    1: TemplateDay(
      enabled: true,
      time: LocalTime(18, 0),
      muscles: const [MuscleGroup.chest],
    ),
  });

  Future<AppDatabase> seeded({WeeklyTemplate? template}) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    lastDb = db;
    await seedSetUp(db, template: template);
    library = await seedLibrary(db, realLibraryV3());
    final c = chest();
    final units = ExerciseUnitRepository(db);
    final logs = LiftLogRepository(db);
    for (final e in [c[0], c[3]]) {
      await units.put(
        ExerciseUnit(exerciseId: e.id, unit: LiftUnit.kg, changedOn: prevMon),
      );
    }
    await logs.put(
      LiftLog(
        date: prevMon,
        exerciseId: c[0].id,
        startKgX10: 400,
        endKgX10: 450,
      ),
    );
    await logs.put(
      LiftLog(
        date: prevMon,
        exerciseId: c[3].id,
        startKgX10: 225,
        endKgX10: 250,
      ),
    );
    await logs.put(
      LiftLog(date: mon, exerciseId: c[0].id, startKgX10: 400, endKgX10: 450),
    );
    return db;
  }

  Future<ProviderContainer> pump(
    WidgetTester tester,
    GoldenVariant variant,
    AppDatabase db,
    DateTime now,
  ) async {
    setPhoneSurface(tester);
    applyVariant(tester, variant);
    final container = ProviderContainer(
      retry: (_, _) => null,
      overrides: [
        ...appOverrides(db: db, clock: FixedClock(now)),
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

  Future<void> tapKey(WidgetTester tester, String key) async {
    final f = find.byKey(ValueKey(key));
    await tester.ensureVisible(f);
    await tester.pumpAndSettle();
    await tester.tap(f);
    await tester.pumpAndSettle();
  }

  Future<void> snap(String name) => expectLater(
    find.byType(MaterialApp),
    matchesGoldenFile('goldens/$name.png'),
  );

  Future<ProviderContainer> replaced(
    WidgetTester tester,
    GoldenVariant v,
    DateTime now,
  ) async {
    final db = await seeded();
    final c = await pump(tester, v, db, DateTime(2026, 10, 12, 18, 30));
    await c.read(replaceExerciseProvider)(mon, chest()[1].id, backPlate().id);
    await tester.pumpAndSettle();
    if (now != DateTime(2026, 10, 12, 18, 30)) {
      return pump(tester, v, db, now);
    }
    return c;
  }

  /// Buổi Ngực có đủ 5 loại dòng (mock s10-h4): bài 1 đã ghi 40 → 45 · Vừa,
  /// bài 2 đổi sang "Máy dốc gắn bánh tạ", bài 3 bỏ qua, bài 4 chưa ghi (buổi
  /// trước 22,5 → 25 · Thoải mái), Plank thêm cuối có ghi chú.
  Future<ProviderContainer> fiveRows(
    WidgetTester tester,
    GoldenVariant v,
  ) async {
    final db = await seeded(template: chestOnly);
    final c = await pump(tester, v, db, DateTime(2026, 10, 12, 18, 12));
    final ch = chest();
    await c.read(replaceExerciseProvider)(mon, ch[1].id, backPlate().id);
    await c.read(skipExerciseProvider)(mon, ch[2].id, skipped: true);
    await c.read(addExtraExerciseProvider)(mon, plank().id);
    await ExerciseNoteRepository(
      db,
    ).put(ExerciseNote(date: mon, exerciseId: plank().id, text: '60 giây'));
    final feels = ExerciseFeelRepository(db);
    await feels.put(
      ExerciseFeel(date: mon, exerciseId: ch[0].id, feel: Feel.medium),
    );
    await feels.put(
      ExerciseFeel(date: prevMon, exerciseId: ch[3].id, feel: Feel.easy),
    );
    await tester.pumpAndSettle();
    return c;
  }

  for (final v in GoldenVariant.all) {
    testWidgets('S-10 H4 Bản 5: bài đã ghi, bài thay (⇄ + "thay …", "—"), bài '
        'gốc buổi trước mờ ${v.name}', (tester) async {
      await replaced(tester, v, DateTime(2026, 10, 12, 18, 30));
      await snap('s10_replacement_${v.name}');
    });

    testWidgets('S-74 bài gốc: Xem bài · Đổi bài · Bỏ qua hôm nay · Xóa bài '
        'thêm (mờ) ${v.name}', (tester) async {
      final db = await seeded();
      await pump(tester, v, db, DateTime(2026, 10, 12, 18, 30));
      await tapKey(tester, 'exercise-${chest()[3].id}');
      await snap('s74_original_${v.name}');
    });

    testWidgets('S-74 bài thay: thêm "Chọn lại bài gốc" ${v.name}', (
      tester,
    ) async {
      await replaced(tester, v, DateTime(2026, 10, 12, 18, 30));
      await tapKey(tester, 'exercise-${backPlate().id}');
      await snap('s74_replacement_${v.name}');
    });

    testWidgets('S-75 "Đổi bài": ẩn bài trong buổi, nhóm đầu không tiêu đề '
        '${v.name}', (tester) async {
      final db = await seeded();
      final c = await pump(tester, v, db, DateTime(2026, 10, 12, 18, 30));
      await go(tester, c, pickExercisePath(mon, slot: chest()[1].id));
      await snap('s75_replace_${v.name}');
    });

    testWidgets('S-78 "Đổi bài?" — bài đã ghi mức tạ hôm nay ${v.name}', (
      tester,
    ) async {
      final db = await seeded();
      await pump(tester, v, db, DateTime(2026, 10, 12, 18, 30));
      await tapKey(tester, 'exercise-${chest()[0].id}');
      await tapKey(tester, 'action-replace');
      await snap('s78_replace_${v.name}');
    });

    // 06 Bản 5 VS54-T05: S-10 H4 đủ 5 loại dòng, S-74 bài thêm / bài bỏ
    // qua, S-75 "Thêm bài", S-78 "Bỏ qua bài?" / "Xóa bài thêm?", S-79.
    testWidgets('S-10 H4 Bản 5 (mock s10-h4): bài đã ghi, bài thay, bài bỏ '
        'qua, bài chưa ghi, bài thêm Plank có ghi chú, "+ Thêm bài" '
        '${v.name}', (tester) async {
      final c = await fiveRows(tester, v);
      expect(c, isNotNull);
      await snap('s10_items_${v.name}');
    });

    testWidgets('S-74 bài thêm: không "Đổi bài", "Xóa bài thêm" đỏ ${v.name}', (
      tester,
    ) async {
      await fiveRows(tester, v);
      await tapKey(tester, 'exercise-${plank().id}');
      await snap('s74_extra_${v.name}');
    });

    testWidgets('S-74 bài bỏ qua: "Hủy bỏ qua" ${v.name}', (tester) async {
      await fiveRows(tester, v);
      await tapKey(tester, 'exercise-${chest()[2].id}');
      await snap('s74_skipped_${v.name}');
    });

    testWidgets('S-75 "Thêm bài": ẩn bài trong buổi ${v.name}', (tester) async {
      final db = await seeded();
      final c = await pump(tester, v, db, DateTime(2026, 10, 12, 18, 30));
      await go(tester, c, pickExercisePath(mon));
      await snap('s75_add_${v.name}');
    });

    testWidgets('S-78 "Bỏ qua bài?" — bài đã ghi ${v.name}', (tester) async {
      final db = await seeded();
      await pump(tester, v, db, DateTime(2026, 10, 12, 18, 30));
      await tapKey(tester, 'exercise-${chest()[0].id}');
      await tapKey(tester, 'action-skip');
      await snap('s78_skip_${v.name}');
    });

    testWidgets('S-78 "Xóa bài thêm?" — bài thêm đã ghi ghi chú ${v.name}', (
      tester,
    ) async {
      await fiveRows(tester, v);
      await tapKey(tester, 'exercise-${plank().id}');
      await tapKey(tester, 'action-remove-extra');
      await snap('s78_remove_extra_${v.name}');
    });

    testWidgets('S-79: mọi bài đã bỏ qua → hộp "Đã tập Ngực?" câu mới '
        '${v.name}', (tester) async {
      final db = await seeded(template: chestOnly);
      final c = await pump(tester, v, db, DateTime(2026, 10, 12, 19, 5));
      for (final e in chest()) {
        await c.read(skipExerciseProvider)(mon, e.id, skipped: true);
      }
      await tester.pumpAndSettle();
      await tapKey(tester, 'today-mark-done');
      await snap('s79_${v.name}');
    });

    testWidgets('S-63 buổi đã qua: bài thay ⇄ + tên gốc, không ··· ${v.name}', (
      tester,
    ) async {
      final c = await replaced(tester, v, DateTime(2026, 10, 13, 9, 40));
      await go(tester, c, sessionPath(AppTab.today, mon));
      await snap('s63_replacement_${v.name}');
    });

    testWidgets('S-78 "Chọn lại bài gốc?" — bài thay đã ghi ${v.name}', (
      tester,
    ) async {
      await replaced(tester, v, DateTime(2026, 10, 12, 18, 30));
      await LiftLogRepository(lastDb).put(
        LiftLog(
          date: mon,
          exerciseId: backPlate().id,
          startKgX10: 200,
          endKgX10: 250,
        ),
      );
      await tester.pumpAndSettle();
      await tapKey(tester, 'exercise-${backPlate().id}');
      await tapKey(tester, 'action-restore');
      await snap('s78_restore_${v.name}');
    });

    // 06 Bản 5 VS55-T05: S-64 × 3 (kg / nấc máy / bài bụng), S-63 có dấu.
    testWidgets('S-64 kg (mock s64): Kết thúc + 1 vạch xám (buổi trước Thoải '
        'mái), +2,5, chọn Vừa ${v.name}', (tester) async {
      await fiveRows(tester, v);
      await tapKey(tester, 'lift-row-${chest()[3].id}');
      await tapKey(tester, 'lift-end-plus');
      await tapKey(tester, 'lift-feel-medium');
      await snap('s64_feel_${v.name}');
    });

    testWidgets('S-64 nấc máy: buổi trước 8 → 10 nấc · Mệt (3 vạch xám), '
        'thanh chọn trống ${v.name}', (tester) async {
      final db = await seeded();
      final flat = chest()[1];
      await ExerciseUnitRepository(db).put(
        ExerciseUnit(
          exerciseId: flat.id,
          unit: LiftUnit.steps,
          changedOn: prevMon,
        ),
      );
      await LiftLogRepository(db).put(
        LiftLog(
          date: prevMon,
          exerciseId: flat.id,
          startKgX10: 80,
          endKgX10: 100,
        ),
      );
      await ExerciseFeelRepository(
        db,
      ).put(ExerciseFeel(date: prevMon, exerciseId: flat.id, feel: Feel.hard));
      await pump(tester, v, db, DateTime(2026, 10, 12, 18, 30));
      await tapKey(tester, 'lift-row-${flat.id}');
      await snap('s64_feel_steps_${v.name}');
    });

    testWidgets('S-64 bài bụng (Plank thêm): chỉ thanh ba mức + ghi chú, chọn '
        'Mệt ${v.name}', (tester) async {
      await fiveRows(tester, v);
      await tapKey(tester, 'note-line-${plank().id}');
      await tapKey(tester, 'lift-feel-hard');
      await snap('s64_feel_abs_${v.name}');
    });

    testWidgets('S-63 buổi đã qua (mock s63): dấu ba vạch cam của buổi đó '
        'sau tên, viền cam bài đã ghi ${v.name}', (tester) async {
      await fiveRows(tester, v);
      final db = lastDb;
      final ch = chest();
      final logs = LiftLogRepository(db);
      await logs.put(
        LiftLog(
          date: mon,
          exerciseId: backPlate().id,
          startKgX10: 200,
          endKgX10: 250,
        ),
      );
      await logs.put(
        LiftLog(
          date: mon,
          exerciseId: ch[3].id,
          startKgX10: 225,
          endKgX10: 275,
        ),
      );
      final feels = ExerciseFeelRepository(db);
      for (final (id, f) in [
        (backPlate().id, Feel.medium),
        (ch[3].id, Feel.medium),
        (plank().id, Feel.hard),
      ]) {
        await feels.put(ExerciseFeel(date: mon, exerciseId: id, feel: f));
      }
      final c = await pump(tester, v, db, DateTime(2026, 10, 13, 9, 40));
      await go(tester, c, sessionPath(AppTab.today, mon));
      await snap('s63_feel_${v.name}');
    });
  }
}
