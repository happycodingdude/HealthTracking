@Tags(['e2e'])
library;

import 'dart:io';

import 'package:api_contract/api_contract.dart';
import 'package:domain/domain.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/data/sync/sync_engine.dart';
import 'package:mobile/features/onboarding/data/onboarding_draft_repository.dart';

import 'sync_e2e_harness.dart';

void main() {
  late E2eServer server;
  final devices = <E2eDevice>[];

  setUpAll(() => HttpOverrides.global = null);
  setUp(() async => server = await E2eServer.start());
  tearDown(() async {
    for (final d in devices) {
      await d.close();
    }
    devices.clear();
    await server.stop();
  });

  E2eDevice device() {
    final d = E2eDevice(server);
    devices.add(d);
    return d;
  }

  test(
    'OB-6, UX-AC3: thiết lập dở ở bước 2 trên máy A → máy B đăng nhập lấy đủ '
    'hồ sơ và cân ban đầu, làm tiếp bước 3 → máy A thấy kết quả',
    () async {
      final a = device();
      await a.register();
      await a.onboarding.acceptDisclaimer();
      final errors = await a.onboarding.saveProfile(
        const ProfileDraft(
          height: '175',
          birthYear: 1996,
          sex: Sex.male,
          activityLevel: ActivityLevel.moderate,
          weight: '80',
        ),
      );
      expect(errors, isEmpty);
      expect(await a.sync(), SyncOutcome.synced);

      final b = device();
      final me = await b.login();
      expect(
        (me.onboardingState, me.onboardingStep),
        (OnboardingState.inProgress, 3),
      );
      expect(await b.sync(), SyncOutcome.synced);
      final p = (await b.profiles.get())!;
      expect(
        (p.onboardingStep, p.heightCm, p.birthYear, p.sex, p.activityLevel),
        (3, 175, 1996, Sex.male, ActivityLevel.moderate),
      );
      expect(p.disclaimerAcceptedAt, isNotNull);
      expect(await b.weights.all(), [
        (week: WeightRules.weekKey(b.clock.today()), kgX10: 800),
      ]);

      expect(await b.onboarding.saveCalorie(), isTrue);
      expect(await b.sync(), SyncOutcome.synced);
      expect(await a.sync(), SyncOutcome.synced);
      final onA = (await a.profiles.get())!;
      final estimate = CalorieRules.forProfile(
        onA,
        weightKgX10: 800,
        currentYear: a.clock.now().year,
      )!;
      expect(
        (onA.onboardingStep, onA.calorieMode, onA.calorieKcal),
        (4, CalorieMode.auto, estimate.kcal),
      );
      expect(
        (await b.login()).onboardingStep,
        4,
        reason: '/v1/me theo hồ sơ trên server',
      );
    },
  );
}
