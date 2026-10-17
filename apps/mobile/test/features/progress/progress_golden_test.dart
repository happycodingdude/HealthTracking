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
import 'package:mobile/features/library/data/exercise_repository.dart';
import 'package:mobile/features/library/data/video_player_gateway.dart';
import 'package:mobile/features/progress/presentation/lift_chart_screen.dart';
import 'package:mobile/features/training/application/training_section.dart';
import 'package:mobile/features/workout/data/lift_log_repository.dart';

import '../../support/app_harness.dart';
import '../../support/golden.dart';
import '../../support/library_fixture.dart';
import '../../support/schedule_fixture.dart';

/// 06 Bản 2 VS28-T06 (golden): S-68 danh sách (trạng thái trống có ở
/// `library_golden_test.dart`), S-69 tháng có bản ghi và tháng trống — sáng,
/// tối, cỡ chữ lớn nhất (UX-AC43). Dữ liệu như mock S-68-1, S-69-1.
void main() {
  late List<Exercise> library;

  Exercise ex(MuscleRegion region, [Equipment? equipment]) =>
      exerciseOf(library, region, equipment);

  Future<AppDatabase> seeded() async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await seedSetUp(db);
    library = await seedLibrary(db);
    final logs = LiftLogRepository(db);
    Future<void> log(Exercise e, int month, int day, int start, int end) =>
        logs.put(
          LiftLog(
            date: LocalDate(2026, month, day),
            exerciseId: e.id,
            startKgX10: start,
            endKgX10: end,
          ),
        );
    final press = ex(MuscleRegion.chestUpper, Equipment.freeWeight);
    await log(press, 8, 28, 90, 100);
    await log(press, 10, 2, 100, 120);
    await log(press, 10, 5, 120, 140);
    await log(press, 10, 7, 100, 120);
    await log(press, 10, 9, 120, 120);
    await log(ex(MuscleRegion.chestUpper, Equipment.machine), 10, 7, 70, 80);
    await log(ex(MuscleRegion.lats, Equipment.machine), 10, 5, 90, 100);
    await log(ex(MuscleRegion.backMid, Equipment.freeWeight), 10, 5, 160, 180);
    await log(ex(MuscleRegion.deltFront, Equipment.machine), 10, 2, 50, 60);
    final gone = ex(MuscleRegion.lats, Equipment.freeWeight);
    await log(gone, 9, 28, 200, 200);
    await ExerciseRepository(db).put(gone.copyWith(active: false));
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
        ...appOverrides(db: db, clock: FixedClock(DateTime(2026, 10, 10, 20))),
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
      c
          .read(routerProvider)
          .go(
            liftChartPath(ex(MuscleRegion.chestUpper, Equipment.freeWeight).id),
          );
      await tester.pumpAndSettle();
      await snap('s69_month_${v.name}');
    });

    testWidgets('S-69-2 tháng không có bản ghi ${v.name}', (tester) async {
      final c = await pump(tester, v, await seeded());
      c
          .read(routerProvider)
          .go(
            liftChartPath(ex(MuscleRegion.chestUpper, Equipment.freeWeight).id),
          );
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
