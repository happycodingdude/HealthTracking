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
import 'package:mobile/features/library/presentation/exercise_screen.dart';
import 'package:mobile/features/me/data/profile_repository.dart';
import 'package:mobile/features/training/application/training_section.dart';

import '../../support/app_harness.dart';
import '../../support/golden.dart';
import '../../support/library_fixture.dart';
import '../../support/schedule_fixture.dart';

void main() {
  // Thứ 3 13/10: ngày nghỉ → thư viện mặc định Ngực (mock S-66-1).
  final tue13 = DateTime(2026, 10, 13, 10);

  Future<ProviderContainer> pump(
    WidgetTester tester,
    GoldenVariant variant,
    AppDatabase db, {
    FakeConnectivity? connectivity,
  }) async {
    setPhoneSurface(tester);
    tester.platformDispatcher
      ..platformBrightnessTestValue = variant.brightness
      ..textScaleFactorTestValue = variant.textScale;
    addTearDown(tester.platformDispatcher.clearAllTestValues);
    final container = ProviderContainer(
      retry: (_, _) => null,
      overrides: [
        ...appOverrides(
          db: db,
          clock: FixedClock(tue13),
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
    return container;
  }

  Future<void> snap(String name) => expectLater(
    find.byType(MaterialApp),
    matchesGoldenFile('goldens/$name.png'),
  );

  Future<AppDatabase> seeded({List<Exercise>? library}) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await seedSetUp(db);
    await seedLibrary(db, library);
    return db;
  }

  Future<void> openSection(
    WidgetTester tester,
    ProviderContainer container,
    TrainingSection section,
  ) async {
    container.read(routerProvider).go('/schedule');
    container.read(trainingTabProvider.notifier).select(section);
    await tester.pumpAndSettle();
  }

  for (final v in GoldenVariant.all) {
    testWidgets('S-66 Thư viện, nhóm Ngực, thanh chọn mục ${v.name}', (
      tester,
    ) async {
      final container = await pump(tester, v, await seeded());
      await openSection(tester, container, TrainingSection.library);
      await snap('s66_${v.name}');
    });

    testWidgets('S-67 Chi tiết bài từ thư viện, video chưa phát ${v.name}', (
      tester,
    ) async {
      final library = realLibrary();
      final container = await pump(tester, v, await seeded());
      container
          .read(routerProvider)
          .go(
            exercisePath(
              exerciseOf(
                library,
                MuscleRegion.chestUpper,
                Equipment.machine,
              ).id,
              ExerciseFrom.library,
            ),
          );
      await tester.pumpAndSettle();
      await snap('s67_${v.name}');
    });

    testWidgets('S-67 video không khả dụng, bài đã rời thư viện, hồ sơ Nữ '
        '${v.name}', (tester) async {
      final library = realLibrary();
      final e = exerciseOf(library, MuscleRegion.lats, Equipment.freeWeight);
      final db = await seeded(
        library: [
          for (final x in library)
            x.id == e.id
                ? x.copyWith(
                    active: false,
                    videoAvailable: false,
                    videoUnavailableReason: VideoUnavailableReason.removed,
                  )
                : x,
        ],
      );
      await ProfileRepository(
        db,
      ).put(completedProfile().copyWith(sex: Sex.female));
      final container = await pump(tester, v, db);
      container
          .read(routerProvider)
          .go(exercisePath(e.id, ExerciseFrom.progress));
      await tester.pumpAndSettle();
      await snap('s67_unavailable_${v.name}');
    });

    testWidgets('S-67 không có mạng ${v.name}', (tester) async {
      final library = realLibrary();
      final container = await pump(
        tester,
        v,
        await seeded(),
        connectivity: FakeConnectivity()..online = false,
      );
      container
          .read(routerProvider)
          .go(
            exercisePath(
              exerciseOf(library, MuscleRegion.absMid).id,
              ExerciseFrom.library,
            ),
          );
      await tester.pumpAndSettle();
      await snap('s67_offline_${v.name}');
    });

    testWidgets('S-68 Tiến bộ trống ${v.name}', (tester) async {
      final container = await pump(tester, v, await seeded());
      await openSection(tester, container, TrainingSection.progress);
      await snap('s68_empty_${v.name}');
    });
  }
}
