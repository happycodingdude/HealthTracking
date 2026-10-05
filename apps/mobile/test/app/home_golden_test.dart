@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/app/app.dart';
import 'package:mobile/app/env.dart';
import 'package:mobile/app/providers.dart';
import 'package:mobile/app/theme.dart';

import '../support/golden.dart';

void main() {
  for (final variant in GoldenVariant.all) {
    testWidgets('UX-AC1: khung 5 tab, Hôm nay (giữ chỗ) ${variant.name}', (
      tester,
    ) async {
      setPhoneSurface(tester);
      tester.platformDispatcher
        ..platformBrightnessTestValue = variant.brightness
        ..textScaleFactorTestValue = variant.textScale;
      addTearDown(tester.platformDispatcher.clearAllTestValues);
      await tester.pumpWidget(
        ProviderScope(
          retry: (_, _) => null,
          overrides: [
            envProvider.overrideWithValue(
              const AppEnv(flavor: 'prod', apiBaseUrl: 'http://x'),
            ),
          ],
          child: const HealthApp(),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        Theme.of(
          tester.element(find.byType(Scaffold).first),
        ).extension<AppPalette>(),
        isNotNull,
      );
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/home_${variant.name}.png'),
      );
    });
  }
}
