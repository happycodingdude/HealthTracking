@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/app/app.dart';
import 'package:mobile/app/router.dart';
import 'package:mobile/app/strings_vi.dart';
import 'package:mobile/core/widgets/labeled_field.dart';

import '../../support/app_harness.dart';
import '../../support/fake_server.dart';
import '../../support/golden.dart';

void main() {
  Future<ProviderContainer> pump(
    WidgetTester tester,
    GoldenVariant variant,
    String location,
  ) async {
    setPhoneSurface(tester);
    tester.platformDispatcher
      ..platformBrightnessTestValue = variant.brightness
      ..textScaleFactorTestValue = variant.textScale;
    addTearDown(tester.platformDispatcher.clearAllTestValues);
    final server = FakeServer()
      ..on(
        'POST',
        '/v1/auth/register',
        (_) => (
          409,
          {
            'error': {'code': 'phone_taken', 'field': 'phone'},
          },
        ),
      );
    final container = ProviderContainer(
      retry: (_, _) => null,
      overrides: appOverrides(session: null, server: server),
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const HealthApp()),
    );
    container.read(routerProvider).go(location);
    await tester.pumpAndSettle();
    return container;
  }

  Finder input(String label) => find.descendant(
    of: find.byWidgetPredicate((w) => w is LabeledField && w.label == label),
    matching: find.byType(TextField),
  );

  Future<void> snap(String name) => expectLater(
    find.byType(MaterialApp),
    matchesGoldenFile('goldens/$name.png'),
  );

  for (final v in GoldenVariant.all) {
    testWidgets('S-01 ${v.name}', (tester) async {
      await pump(tester, v, '/welcome');
      await snap('s01_${v.name}');
    });

    testWidgets('S-01a ${v.name}', (tester) async {
      await pump(tester, v, '/welcome/register');
      await snap('s01a_${v.name}');
    });

    testWidgets('S-01a lỗi dưới từng ô (P4) ${v.name}', (tester) async {
      await pump(tester, v, '/welcome/register');
      await tester.tap(find.widgetWithText(FilledButton, S.register));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text(S.fieldDisplayName),
        -200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await snap('s01a_errors_${v.name}');
    });

    if (v.textScale == 1) {
      testWidgets('S-01a số đã có tài khoản (UX-AC21) ${v.name}', (
        tester,
      ) async {
        await pump(tester, v, '/welcome/register');
        await tester.enterText(input(S.fieldDisplayName), 'Minh');
        await tester.enterText(input(S.fieldPhone), '0912345678');
        await tester.enterText(input(S.fieldPassword), '***REMOVED***');
        await tester.enterText(input(S.fieldPasswordConfirm), '***REMOVED***');
        await tester.tap(find.widgetWithText(FilledButton, S.register));
        await tester.pumpAndSettle();
        await snap('s01a_phone_taken_${v.name}');
      });
    }

    testWidgets('S-01b ${v.name}', (tester) async {
      await pump(tester, v, '/welcome/login');
      await tester.enterText(input(S.fieldPhone), '0912345678');
      await tester.pumpAndSettle();
      await snap('s01b_${v.name}');
    });

    testWidgets('S-01c ${v.name}', (tester) async {
      await pump(tester, v, '/welcome/login');
      await tester.scrollUntilVisible(
        find.text(S.forgotPassword),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text(S.forgotPassword));
      await tester.pumpAndSettle();
      await snap('s01c_${v.name}');
    });
  }
}
