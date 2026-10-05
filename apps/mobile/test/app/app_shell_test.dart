import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/app/app.dart';
import 'package:mobile/app/router.dart';
import 'package:mobile/app/shell/app_shell.dart';
import 'package:mobile/app/shell/app_tab.dart';
import 'package:mobile/app/shell/app_tab_bar.dart';
import 'package:mobile/app/shell/tab_scroll.dart';
import 'package:mobile/app/strings_vi.dart';
import 'package:mobile/core/widgets/tab_page.dart';

void main() {
  Future<ProviderContainer> pumpApp(
    WidgetTester tester, {
    List<Override> overrides = const [],
  }) async {
    final container = ProviderContainer(
      retry: (_, _) => null,
      overrides: overrides,
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const HealthApp()),
    );
    await tester.pumpAndSettle();
    return container;
  }

  Finder tabLabel(String label) =>
      find.descendant(of: find.byType(AppTabBar), matching: find.text(label));

  testWidgets(
    'UX-AC1: đúng 5 tab theo thứ tự, Hôm nay là nút tròn ở giữa, luôn có chữ',
    (tester) async {
      await pumpApp(tester);
      final labels = [
        S.tabSchedule,
        S.tabMenu,
        S.tabToday,
        S.tabWeight,
        S.tabMe,
      ];
      final xs = [for (final l in labels) tester.getCenter(tabLabel(l)).dx];
      expect(xs, orderedEquals([...xs]..sort()));
      final width =
          tester.view.physicalSize.width / tester.view.devicePixelRatio;
      expect(xs[2], closeTo(width / 2, 1));
      final circle = find.byKey(const ValueKey('tab-today-button'));
      expect(circle, findsOneWidget);
      // Nút tròn nhô lên trên mép thanh tab (04 §6.3.2).
      final barTop =
          tester.getTopLeft(find.byType(AppTabBar)).dy + AppTabBar.protrusion;
      expect(tester.getTopLeft(circle).dy, lessThan(barTop));
      expect(find.bySemanticsLabel(S.tabToday), findsWidgets);
    },
  );

  testWidgets('NAV-1: mở app vào Hôm nay; chạm tab để chuyển', (tester) async {
    await pumpApp(tester);
    // Tiêu đề lớn của trang + nhãn tab.
    expect(find.text(S.tabToday), findsNWidgets(2));
    await tester.tap(tabLabel(S.tabWeight));
    await tester.pumpAndSettle();
    expect(find.text(S.tabWeight), findsNWidgets(2));
    await tester.tap(find.byKey(const ValueKey('tab-today-button')));
    await tester.pumpAndSettle();
    expect(find.text(S.tabToday), findsNWidgets(2));
  });

  testWidgets(
    'NAV-8: giữ vị trí cuộn khi đổi tab; NAV-3: chạm tab đang mở cuộn về đầu',
    (tester) async {
      final longRouter = GoRouter(
        initialLocation: AppTab.today.path,
        routes: [
          StatefulShellRoute.indexedStack(
            builder: (context, state, shell) =>
                AppShell(navigationShell: shell),
            branches: [
              for (final tab in AppTab.values)
                StatefulShellBranch(
                  routes: [
                    GoRoute(
                      path: tab.path,
                      builder: (_, _) => TabPage(
                        tab: tab,
                        title: tab.label,
                        children: [
                          for (var i = 0; i < 40; i++)
                            SizedBox(height: 60, child: Text('$i')),
                        ],
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ],
      );
      addTearDown(longRouter.dispose);
      final container = await pumpApp(
        tester,
        overrides: [routerProvider.overrideWithValue(longRouter)],
      );
      final controller = container
          .read(tabScrollControllersProvider)
          .of(AppTab.today);

      controller.jumpTo(500);
      await tester.pump();
      await tester.tap(tabLabel(S.tabMe));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('tab-today-button')));
      await tester.pumpAndSettle();
      expect(controller.offset, 500, reason: 'NAV-8');

      await tester.tap(find.byKey(const ValueKey('tab-today-button')));
      await tester.pumpAndSettle();
      expect(controller.offset, 0, reason: 'NAV-3');
    },
  );

  testWidgets('chấm báo hiệu hiện ở tab được đánh dấu (04 §6.3.1)', (
    tester,
  ) async {
    await pumpApp(
      tester,
      overrides: [
        tabDotsProvider.overrideWithValue({AppTab.me}),
      ],
    );
    expect(find.byKey(const ValueKey('tab-dot-me')), findsOneWidget);
    expect(find.byKey(const ValueKey('tab-dot-schedule')), findsNothing);
  });
}
