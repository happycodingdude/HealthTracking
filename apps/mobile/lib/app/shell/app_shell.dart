import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'app_tab.dart';
import 'app_tab_bar.dart';
import 'tab_scroll.dart';

/// Khung 5 tab. `StatefulShellRoute.indexedStack` giữ trạng thái từng tab
/// (NAV-8). Chạm lại tab đang mở → cuộn về đầu (NAV-3).
class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = AppTab.values[navigationShell.currentIndex];
    return Scaffold(
      extendBody: true,
      body: navigationShell,
      bottomNavigationBar: AppTabBar(
        current: current,
        dots: ref.watch(tabDotsProvider),
        onTap: (tab) {
          if (tab == current) {
            ref
                .read(tabScrollControllersProvider)
                .scrollToTop(
                  tab,
                  animate: !MediaQuery.disableAnimationsOf(context),
                );
          } else {
            navigationShell.goBranch(tab.index);
          }
        },
      ),
    );
  }
}
