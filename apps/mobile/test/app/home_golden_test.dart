@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/app/app.dart';
import 'package:mobile/ui/theme.dart';

import '../support/app_harness.dart';
import '../support/golden.dart';

void main() {
  for (final variant in GoldenVariant.all) {
    testWidgets('UX-AC1: khung 5 tab, Hôm nay (giữ chỗ) ${variant.name}', (
      tester,
    ) async {
      setPhoneSurface(tester);
      applyVariant(tester, variant);
      final container = ProviderContainer(
        retry: (_, _) => null,
        overrides: appOverrides(),
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const IronlyApp(),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        Theme.of(
          tester.element(find.byType(Scaffold).first),
        ).extension<IronlyTokens>(),
        isNotNull,
      );
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/home_${variant.name}.png'),
      );
    });
  }
}
