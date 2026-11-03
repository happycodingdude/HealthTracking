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
void main() {
  final mon = LocalDate(2026, 10, 12);
  final prevMon = LocalDate(2026, 10, 5);
  late List<Exercise> library;

  List<Exercise> chest() => [
    for (final e in library)
      if (e.group == MuscleGroup.chest) e,
  ];
  Exercise backPlate() => library.firstWhere(
    (e) => e.id == 'back-back-mid-plate-loaded-row-machine',
  );

  Future<AppDatabase> seeded() async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await seedSetUp(db);
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

    testWidgets('S-63 buổi đã qua: bài thay ⇄ + tên gốc, không ··· ${v.name}', (
      tester,
    ) async {
      final c = await replaced(tester, v, DateTime(2026, 10, 13, 9, 40));
      await go(tester, c, sessionPath(AppTab.today, mon));
      await snap('s63_replacement_${v.name}');
    });
  }
}
