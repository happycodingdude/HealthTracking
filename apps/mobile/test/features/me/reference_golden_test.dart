@Tags(['golden'])
library;

import 'package:domain/domain.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/app/app.dart';
import 'package:mobile/app/shell/app_tab_bar.dart';
import 'package:mobile/app/strings_vi.dart';
import 'package:mobile/data/db/app_database.dart';

import '../../support/app_harness.dart';
import '../../support/fake_server.dart';
import '../../support/golden.dart';
import '../../support/schedule_fixture.dart';

void main() {
  for (final v in GoldenVariant.all) {
    testWidgets('S-55 Về gợi ý tham khảo (F10-R4, từ tab Tôi) ${v.name}', (
      tester,
    ) async {
      setPhoneSurface(tester);
      tester.platformDispatcher
        ..platformBrightnessTestValue = v.brightness
        ..textScaleFactorTestValue = v.textScale;
      addTearDown(tester.platformDispatcher.clearAllTestValues);
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      await seedSetUp(db);
      final container = ProviderContainer(
        retry: (_, _) => null,
        overrides: appOverrides(
          db: db,
          clock: FixedClock(DateTime(2026, 10, 7, 9)),
          server: FakeServer(),
        ),
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const IronlyApp(),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(AppTabBar),
          matching: find.text(S.tabMe),
        ),
      );
      await tester.pumpAndSettle();
      final row = find.byKey(const ValueKey('row-about-reference'));
      await tester.scrollUntilVisible(
        row,
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(row);
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/s55_${v.name}.png'),
      );
    });
  }
}
