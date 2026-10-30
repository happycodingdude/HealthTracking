// Chụp màn hình cho bộ ảnh so sánh (06 Bản 4 ED4-04, VS43-T11). Chạy bằng
// tool/capture_screens.sh <M17…M21> qua `flutter drive` trên simulator; ảnh
// vào build/review/<id>.png. Dữ liệu là fixture trong bộ nhớ (như golden),
// không cần server.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mobile/app/app.dart';
import 'package:mobile/dev/review_matrix.dart';
import 'package:mobile/ui/gallery.dart';
import 'package:mobile/ui/theme.dart';

import '../test/support/app_harness.dart';

const _milestone = String.fromEnvironment(
  'CAPTURE_MILESTONE',
  defaultValue: 'M17',
);

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  final milestone = Milestone.values.firstWhere(
    (m) => m.name.toUpperCase() == _milestone.toUpperCase(),
  );

  Future<void> shot(WidgetTester tester, String id) async {
    // Vòng xoay vô hạn (nút loading) → không pumpAndSettle.
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await binding.takeScreenshot(id);
  }

  Future<void> pumpApp(WidgetTester tester, Widget child) async {
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: IronlyTheme.dark(),
        darkTheme: IronlyTheme.dark(),
        themeMode: ThemeMode.dark,
        home: child,
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));
  }

  group(_milestone, () {
    if (milestone == Milestone.m17) {
      testWidgets('M17: trang thành phần', (tester) async {
        await pumpApp(tester, const ComponentGallery(showBack: false));
        await tester.pump(const Duration(seconds: 1));
        await shot(tester, 'm17_components_1');
        await tester.drag(
          find.byKey(const ValueKey('gallery-list')),
          const Offset(0, -700),
        );
        await shot(tester, 'm17_components_2');
        await tester.drag(
          find.byKey(const ValueKey('gallery-list')),
          const Offset(0, -700),
        );
        await shot(tester, 'm17_glyphs');
        await tester.scrollUntilVisible(
          find.text('Open dialog'),
          300,
          scrollable: find.descendant(
            of: find.byKey(const ValueKey('gallery-list')),
            matching: find.byType(Scrollable),
          ),
        );
        await tester.pump(const Duration(milliseconds: 300));
        await tester.tap(find.text('Open dialog'));
        await shot(tester, 'm17_dialog');
        await tester.tapAt(const Offset(10, 10));
        await tester.pump(const Duration(milliseconds: 500));
        await tester.tap(find.text('Open sheet'));
        await shot(tester, 'm17_sheet');
      });
    }
    if (milestone != Milestone.m17) {
      testWidgets('$_milestone: chưa có màn', (tester) async {
        // Các mốc sau thêm kịch bản chụp cùng slice của chúng.
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
        await shot(tester, '${milestone.name}_home');
      });
    }
  });
}
