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
import 'package:mobile/features/me/data/account_repository.dart';
import 'package:mobile/features/me/data/profile_repository.dart';
import 'package:mobile/features/weight/data/weight_repository.dart';
import 'package:mobile/ui/components/ironly_tab_bar.dart';

import '../../support/app_harness.dart';
import '../../support/fake_server.dart';
import '../../support/golden.dart';
import '../../support/schedule_fixture.dart';

void main() {
  /// Mock S-40: thiết lập 17/08, 8 tuần, tuần 21/09 không ghi (F07-AC4).
  Future<AppDatabase> seed() async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await AccountRepository(db).put('Minh');
    await ProfileRepository(
      db,
    ).put(completedProfile().copyWith(setupDate: LocalDate(2026, 8, 17)));
    final weights = WeightRepository(db);
    for (final (m, d, kg) in [
      (8, 17, 750),
      (8, 24, 746),
      (8, 31, 744),
      (9, 7, 740),
      (9, 14, 736),
      (9, 28, 729),
      (10, 5, 725),
    ]) {
      await weights.put(LocalDate(2026, m, d), kg);
    }
    return db;
  }

  Future<void> pump(
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
      overrides: appOverrides(
        db: db,
        clock: FixedClock(DateTime(2026, 10, 8, 9)),
        server: FakeServer(),
      ),
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const IronlyApp()),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(IronlyTabBar),
        matching: find.text(S.tabWeight),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> snap(String name) => expectLater(
    find.byType(MaterialApp),
    matchesGoldenFile('goldens/$name.png'),
  );

  for (final v in GoldenVariant.all) {
    testWidgets(
      'S-40 cân nặng, biểu đồ có tuần trống (mock S-40-1) ${v.name}',
      (tester) async {
        await pump(tester, v, await seed());
        await snap('s40_${v.name}');
      },
    );

    testWidgets('S-41 ghi cân, tuần đã có số (mock S-41-1) ${v.name}', (
      tester,
    ) async {
      await pump(tester, v, await seed());
      final button = find.widgetWithText(FilledButton, S.logThisWeek);
      await tester.scrollUntilVisible(
        button,
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(button);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.descendant(
          of: find.byKey(const ValueKey('weight-input')),
          matching: find.byType(TextField),
        ),
        '72,3',
      );
      await tester.pumpAndSettle();
      await snap('s41_${v.name}');
    });

    testWidgets('S-41 sửa số cân, nút xóa chữ đỏ (UX-AC17) ${v.name}', (
      tester,
    ) async {
      await pump(tester, v, await seed());
      final row = find.byKey(const ValueKey('weight-week-2026-10-05'));
      await tester.scrollUntilVisible(
        row,
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(row);
      await tester.pumpAndSettle();
      await snap('s41_edit_${v.name}');
    });
  }
}
