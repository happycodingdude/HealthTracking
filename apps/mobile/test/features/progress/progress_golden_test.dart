@Tags(['golden'])
library;

import 'package:domain/domain.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/app/app.dart';
import 'package:mobile/app/router.dart';
import 'package:mobile/data/db/app_database.dart';
import 'package:mobile/features/library/data/video_player_gateway.dart';
import 'package:mobile/features/progress/presentation/lift_chart_screen.dart';
import 'package:mobile/features/training/application/training_section.dart';
import 'package:mobile/features/workout/data/exercise_unit_repository.dart';
import 'package:mobile/features/workout/data/lift_log_repository.dart';

import '../../support/app_harness.dart';
import '../../support/golden.dart';
import '../../support/library_fixture.dart';
import '../../support/schedule_fixture.dart';

/// 06 Bản 2 VS28-T06 (golden): S-68 danh sách (trạng thái trống có ở
/// `library_golden_test.dart`), S-69 tháng có bản ghi và tháng trống — sáng,
/// tối, cỡ chữ lớn nhất (UX-AC43). 06 Bản 3 VS37-T05: dữ liệu như mock S-68-1,
/// S-69-1 Bản 3 — đơn vị từng bài, mốc đổi sang nấc, "· trước khi đổi".
void main() {
  late List<Exercise> library;

  Exercise byId(String id) => library.firstWhere((e) => e.id == id);
  const legExtension = 'legs-quads-seated-leg-extension';

  Future<AppDatabase> seeded() async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await seedSetUp(db);
    library = await seedLibrary(db, realLibraryV3());
    final logs = LiftLogRepository(db);
    final units = ExerciseUnitRepository(db);
    Future<void> log(String id, int month, int day, int start, int end) =>
        logs.put(
          LiftLog(
            date: LocalDate(2026, month, day),
            exerciseId: id,
            startKgX10: start,
            endKgX10: end,
          ),
        );
    Future<void> unit(String id, LiftUnit u, int month, int day) => units.put(
      ExerciseUnit(
        exerciseId: id,
        unit: u,
        changedOn: LocalDate(2026, month, day),
      ),
    );
    const pecDeck = 'chest-mid-machine-pec-deck';
    await unit(pecDeck, LiftUnit.kg, 10, 17);
    await log(pecDeck, 10, 17, 400, 450);
    await log(pecDeck, 10, 21, 400, 475);
    const incline = 'chest-upper-machine-incline-machine-chest-press';
    await unit(incline, LiftUnit.steps, 10, 21);
    await log(incline, 10, 21, 80, 100);
    // Ghi kg từ tháng 8, đổi sang nấc máy ngày 16/10 (F22-R42).
    await log(legExtension, 8, 28, 100, 110);
    await log(legExtension, 10, 9, 105, 115);
    await log(legExtension, 10, 14, 110, 120);
    await unit(legExtension, LiftUnit.steps, 10, 16);
    await log(legExtension, 10, 17, 70, 80);
    await log(legExtension, 10, 21, 80, 90);
    await log(legExtension, 10, 24, 80, 100);
    const pulldown = 'lats-machine-lat-pulldown';
    await unit(pulldown, LiftUnit.kg, 10, 16);
    await log(pulldown, 10, 16, 450, 500);
    const shoulder = 'delt-front-machine-machine-shoulder-press';
    await unit(shoulder, LiftUnit.kg, 10, 15);
    await log(shoulder, 10, 15, 300, 350);
    return db;
  }

  Future<ProviderContainer> pump(
    WidgetTester tester,
    GoldenVariant variant,
    AppDatabase db,
  ) async {
    setPhoneSurface(tester);
    tester.platformDispatcher
      ..platformBrightnessTestValue = variant.brightness
      ..textScaleFactorTestValue = variant.textScale;
    addTearDown(tester.platformDispatcher.clearAllTestValues);
    final container = ProviderContainer(
      retry: (_, _) => null,
      overrides: [
        ...appOverrides(db: db, clock: FixedClock(DateTime(2026, 10, 24, 20))),
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

  Future<void> snap(String name) => expectLater(
    find.byType(MaterialApp),
    matchesGoldenFile('goldens/$name.png'),
  );

  for (final v in GoldenVariant.all) {
    testWidgets('S-68-1 Tiến bộ mức tạ ${v.name}', (tester) async {
      final c = await pump(tester, v, await seeded());
      c.read(routerProvider).go('/schedule');
      c.read(trainingTabProvider.notifier).select(TrainingSection.progress);
      await tester.pumpAndSettle();
      await snap('s68_list_${v.name}');
    });

    testWidgets('S-69-1 biểu đồ tháng hiện tại ${v.name}', (tester) async {
      final c = await pump(tester, v, await seeded());
      c.read(routerProvider).go(liftChartPath(byId(legExtension).id));
      await tester.pumpAndSettle();
      await snap('s69_month_${v.name}');
    });

    testWidgets('S-69-2 tháng không có bản ghi ${v.name}', (tester) async {
      final c = await pump(tester, v, await seeded());
      c.read(routerProvider).go(liftChartPath(byId(legExtension).id));
      await tester.pumpAndSettle();
      final previous = find.byKey(const ValueKey('chart-month-previous'));
      await tester.ensureVisible(previous);
      await tester.pumpAndSettle();
      await tester.tap(previous);
      await tester.pumpAndSettle();
      await snap('s69_empty_month_${v.name}');
    });
  }
}
