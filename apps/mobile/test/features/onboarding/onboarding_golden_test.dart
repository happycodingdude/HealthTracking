@Tags(['golden'])
library;

import 'package:domain/domain.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/app/app.dart';
import 'package:mobile/app/strings_vi.dart';
import 'package:mobile/data/db/app_database.dart';
import 'package:mobile/features/me/data/profile_repository.dart';
import 'package:mobile/features/onboarding/application/setup_state.dart';
import 'package:mobile/features/onboarding/data/onboarding_draft_repository.dart';
import 'package:mobile/features/weight/data/weight_repository.dart';

import '../../support/app_harness.dart';
import '../../support/golden.dart';

void main() {
  final accepted = DateTime(2026, 10, 7, 18, 40);
  const body = Profile(
    onboardingStep: 3,
    heightCm: 175,
    birthYear: 1996,
    sex: Sex.male,
    activityLevel: ActivityLevel.moderate,
  );

  Future<void> pump(
    WidgetTester tester,
    GoldenVariant variant,
    Future<void> Function(AppDatabase db) seed,
  ) async {
    setPhoneSurface(tester);
    tester.platformDispatcher
      ..platformBrightnessTestValue = variant.brightness
      ..textScaleFactorTestValue = variant.textScale;
    addTearDown(tester.platformDispatcher.clearAllTestValues);
    final db = AppDatabase(NativeDatabase.memory());
    await seed(db);
    final container = ProviderContainer(
      retry: (_, _) => null,
      overrides: appOverrides(
        db: db,
        onboarded: false,
        initialSetup: SetupState.of(await ProfileRepository(db).get()),
      ),
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const HealthApp()),
    );
    await tester.pumpAndSettle();
  }

  Future<void> snap(String name) => expectLater(
    find.byType(MaterialApp),
    matchesGoldenFile('goldens/$name.png'),
  );

  for (final v in GoldenVariant.all) {
    testWidgets('S-02 Thông báo tham khảo ${v.name}', (tester) async {
      await pump(tester, v, (_) async {});
      await snap('s02_${v.name}');
    });

    testWidgets('S-03 Hồ sơ cơ thể, lỗi mẫu F01-V5 ${v.name}', (tester) async {
      await pump(tester, v, (db) async {
        await ProfileRepository(
          db,
        ).put(Profile(onboardingStep: 2, disclaimerAcceptedAt: accepted));
        await OnboardingDraftRepository(db).save(
          const ProfileDraft(
            height: '175',
            birthYear: 1996,
            sex: Sex.male,
            activityLevel: ActivityLevel.moderate,
            weight: '7,5',
          ),
        );
      });
      await tester.tap(find.text(S.continueLabel));
      await tester.pumpAndSettle();
      await snap('s03_error_${v.name}');
    });

    testWidgets('S-04 Mức calo (F02-AC1) ${v.name}', (tester) async {
      await pump(tester, v, (db) async {
        await ProfileRepository(
          db,
        ).put(body.copyWith(disclaimerAcceptedAt: accepted));
        await WeightRepository(db).put(LocalDate(2026, 10, 5), 800);
      });
      await snap('s04_${v.name}');
    });
  }
}
