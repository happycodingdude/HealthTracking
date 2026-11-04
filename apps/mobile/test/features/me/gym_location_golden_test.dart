@Tags(['golden'])
library;

import 'dart:async';

import 'package:domain/domain.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/app/app.dart';
import 'package:mobile/app/router.dart';
import 'package:mobile/data/db/app_database.dart';
import 'package:mobile/features/me/data/account_repository.dart';
import 'package:mobile/features/me/data/gym_location_repository.dart';
import 'package:mobile/features/me/presentation/gym_location_screen.dart';
import 'package:mobile/features/native/gym_region_bridge.dart';

import '../../support/app_harness.dart';
import '../../support/fake_native.dart';
import '../../support/golden.dart';

/// 06 Bản 5 VS58-T06, ED5-09: S-50 dòng "Vị trí phòng gym", S-77 × 3 (chưa
/// lưu / đang lấy vị trí / đã lưu) — mock s50, s77a, s77b.
void main() {
  // Thứ 3 03/11/2026, 17:20 (mock S-77).
  final tue = DateTime(2026, 11, 3, 17, 20);

  Future<FakeGymRegionBridge> pump(
    WidgetTester tester,
    GoldenVariant variant,
    String location, {
    GymLocation? saved,
    bool fetching = false,
  }) async {
    setPhoneSurface(tester);
    tester.platformDispatcher
      ..platformBrightnessTestValue = variant.brightness
      ..textScaleFactorTestValue = variant.textScale;
    addTearDown(tester.platformDispatcher.clearAllTestValues);
    final db = AppDatabase(NativeDatabase.memory());
    await AccountRepository(db).put('Anton');
    if (saved != null) await GymLocationRepository(db).put(saved);
    final gym = FakeGymRegionBridge()..access = LocationAccess.always;
    if (fetching) gym.hold = Completer<GymFix?>();
    final container = ProviderContainer(
      retry: (_, _) => null,
      overrides: appOverrides(db: db, clock: FixedClock(tue), gym: gym),
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const IronlyApp()),
    );
    await tester.pumpAndSettle();
    container.read(routerProvider).go(location);
    await tester.pumpAndSettle();
    if (fetching) {
      await tester.tap(find.byKey(const ValueKey('gym-save')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
    }
    return gym;
  }

  Future<void> snap(String name) => expectLater(
    find.byType(MaterialApp),
    matchesGoldenFile('goldens/$name.png'),
  );

  final saved = GymLocation(lat: 10.77, lng: 106.69, savedAt: tue);

  for (final v in GoldenVariant.all) {
    testWidgets('S-50 dòng Vị trí phòng gym "Lưu 03/11 · Đang bật" ${v.name}', (
      tester,
    ) async {
      await pump(tester, v, '/me', saved: saved);
      await snap('s50_gym_${v.name}');
    });

    testWidgets('S-77 chưa lưu (mock s77a) ${v.name}', (tester) async {
      await pump(tester, v, gymLocationPath);
      await snap('s77_empty_${v.name}');
    });

    testWidgets('S-77 đang lấy vị trí ${v.name}', (tester) async {
      final gym = await pump(tester, v, gymLocationPath, fetching: true);
      await snap('s77_fetching_${v.name}');
      gym.hold!.complete(null);
      await tester.pumpAndSettle();
    });

    testWidgets('S-77 đã lưu (mock s77b) ${v.name}', (tester) async {
      await pump(tester, v, gymLocationPath, saved: saved);
      await snap('s77_saved_${v.name}');
    });
  }
}
