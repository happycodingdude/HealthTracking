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
import 'package:mobile/app/shell/tab_stacks.dart';
import 'package:mobile/app/strings_vi.dart';
import 'package:mobile/core/widgets/tab_page.dart';

import '../support/app_harness.dart';

void main() {
  Future<ProviderContainer> pumpApp(
    WidgetTester tester, {
    List<Override> overrides = const [],
  }) async {
    final container = ProviderContainer(
      retry: (_, _) => null,
      overrides: [...appOverrides(), ...overrides],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const IronlyApp()),
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
        S.tabTraining,
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

  /// Router thử: 5 tab, mỗi trang đầu dài 40 dòng; mỗi tab có màn con
  /// `child` và màn đang sửa dở `dirty` (`PopScope(canPop: false)`).
  GoRouter testRouter(TabStacks stacks) => GoRouter(
    initialLocation: AppTab.today.path,
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => AppShell(navigationShell: shell),
        branches: [
          for (final tab in AppTab.values)
            StatefulShellBranch(
              observers: [stacks.observer(tab)],
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
                  routes: [
                    GoRoute(
                      path: 'child',
                      builder: (_, _) =>
                          Scaffold(body: Text('Màn con ${tab.name}')),
                    ),
                    GoRoute(
                      path: 'dirty',
                      builder: (_, _) => PopScope<Object?>(
                        canPop: false,
                        child: Scaffold(body: Text('Đang sửa ${tab.name}')),
                      ),
                    ),
                  ],
                ),
              ],
            ),
        ],
      ),
    ],
  );

  Future<(GoRouter, ProviderContainer)> pumpTestRouter(
    WidgetTester tester,
  ) async {
    final stacks = TabStacks();
    final router = testRouter(stacks);
    addTearDown(router.dispose);
    final container = await pumpApp(
      tester,
      overrides: [
        tabStacksProvider.overrideWithValue(stacks),
        routerProvider.overrideWithValue(router),
      ],
    );
    return (router, container);
  }

  final todayButton = find.byKey(const ValueKey('tab-today-button'));

  testWidgets('NAV-16: rời tab thì quay lại thấy đầu trang; NAV-3: chạm tab '
      'đang ở trang đầu cuộn về đầu', (tester) async {
    final (_, container) = await pumpTestRouter(tester);
    final controllers = container.read(tabScrollControllersProvider);
    final today = controllers.of(AppTab.today);

    today.jumpTo(500);
    await tester.pump();
    await tester.tap(tabLabel(S.tabMe));
    await tester.pumpAndSettle();
    await tester.tap(todayButton);
    await tester.pumpAndSettle();
    expect(today.offset, 0, reason: 'NAV-16');

    today.jumpTo(500);
    await tester.pump();
    await tester.tap(todayButton);
    await tester.pumpAndSettle();
    expect(today.offset, 0, reason: 'NAV-3');

    // Rời tab bằng liên kết trong app (không qua thanh tab) cũng về đầu.
    final me = controllers.of(AppTab.me);
    await tester.tap(tabLabel(S.tabMe));
    await tester.pumpAndSettle();
    me.jumpTo(500);
    await tester.pump();
    GoRouter.of(tester.element(find.byType(AppShell))).go(AppTab.weight.path);
    await tester.pumpAndSettle();
    await tester.tap(tabLabel(S.tabMe));
    await tester.pumpAndSettle();
    expect(me.offset, 0, reason: 'NAV-16');
  });

  testWidgets('NAV-15: chạm tab nào cũng về trang đầu của tab, ở đầu trang', (
    tester,
  ) async {
    final (router, container) = await pumpTestRouter(tester);
    final controllers = container.read(tabScrollControllersProvider);

    for (final tab in AppTab.values) {
      final tabButton = tab == AppTab.today ? todayButton : tabLabel(tab.label);
      final child = find.text('Màn con ${tab.name}');

      // Đang ở màn con của tab → chạm chính tab đó.
      await tester.tap(tabButton);
      await tester.pumpAndSettle();
      controllers.of(tab).jumpTo(500);
      router.go('${tab.path}/child');
      await tester.pumpAndSettle();
      expect(child, findsOneWidget);
      await tester.tap(tabButton);
      await tester.pumpAndSettle();
      expect(child, findsNothing, reason: tab.name);
      expect(router.state.uri.path, tab.path);
      expect(controllers.of(tab).offset, 0, reason: tab.name);

      // Để màn con, sang tab khác rồi chạm lại tab.
      router.go('${tab.path}/child');
      await tester.pumpAndSettle();
      final other = tab == AppTab.me ? AppTab.weight : AppTab.me;
      await tester.tap(tabLabel(other.label));
      await tester.pumpAndSettle();
      await tester.tap(tabButton);
      await tester.pumpAndSettle();
      expect(child, findsNothing, reason: tab.name);
      expect(router.state.uri.path, tab.path);
    }
  });

  testWidgets('NAV-6: tab có màn đang sửa dở thì hỏi trước khi về trang đầu', (
    tester,
  ) async {
    final (router, _) = await pumpTestRouter(tester);
    final editing = find.text('Đang sửa me');

    await tester.tap(tabLabel(S.tabMe));
    await tester.pumpAndSettle();
    router.go('${AppTab.me.path}/dirty');
    await tester.pumpAndSettle();

    // Chạm chính tab → hỏi; "Tiếp tục sửa" → ở lại.
    await tester.tap(tabLabel(S.tabMe));
    await tester.pumpAndSettle();
    expect(find.text(S.discardChangesTitle), findsOneWidget);
    await tester.tap(find.text(S.keepEditing));
    await tester.pumpAndSettle();
    expect(editing, findsOneWidget);

    // Sang tab khác không hỏi; quay lại → hỏi; "Tiếp tục sửa" → về đúng màn.
    await tester.tap(todayButton);
    await tester.pumpAndSettle();
    expect(find.text(S.discardChangesTitle), findsNothing);
    await tester.tap(tabLabel(S.tabMe));
    await tester.pumpAndSettle();
    expect(find.text(S.discardChangesTitle), findsOneWidget);
    await tester.tap(find.text(S.keepEditing));
    await tester.pumpAndSettle();
    expect(editing, findsOneWidget);

    // "Bỏ" → về trang đầu.
    await tester.tap(tabLabel(S.tabMe));
    await tester.pumpAndSettle();
    await tester.tap(find.text(S.discard));
    await tester.pumpAndSettle();
    expect(editing, findsNothing);
    expect(router.state.uri.path, AppTab.me.path);
  });

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
