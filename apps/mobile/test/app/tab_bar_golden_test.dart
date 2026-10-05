@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/app/shell/app_tab.dart';
import 'package:mobile/app/shell/app_tab_bar.dart';

import '../support/golden.dart';

void main() {
  for (final variant in GoldenVariant.all) {
    for (final current in [AppTab.today, AppTab.me]) {
      testWidgets(
        'UX-AC1/UX-AC18: thanh tab ${variant.name}, đang ở ${current.name}',
        (tester) async {
          setPhoneSurface(tester, size: const Size(390, 160));
          await tester.pumpWidget(
            goldenHost(
              variant,
              Scaffold(
                extendBody: true,
                body: const SizedBox.expand(),
                bottomNavigationBar: AppTabBar(
                  current: current,
                  onTap: (_) {},
                  dots: current == AppTab.me
                      ? {AppTab.me, AppTab.schedule}
                      : const {},
                ),
              ),
            ),
          );
          await expectLater(
            find.byType(Scaffold),
            matchesGoldenFile(
              'goldens/tab_bar_${variant.name}_${current.name}.png',
            ),
          );
        },
      );
    }
  }
}
