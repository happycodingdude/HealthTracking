import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/me/presentation/me_screen.dart';
import '../features/menu/presentation/menu_screen.dart';
import '../features/schedule/presentation/schedule_screen.dart';
import '../features/today/presentation/today_screen.dart';
import '../features/weight/presentation/weight_screen.dart';
import 'shell/app_shell.dart';
import 'shell/app_tab.dart';

/// Router của app (TD-03). Mở app vào Hôm nay (NAV-1).
final routerProvider = Provider<GoRouter>((ref) {
  final router = GoRouter(
    initialLocation: AppTab.today.path,
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => AppShell(navigationShell: shell),
        branches: [
          for (final tab in AppTab.values)
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: tab.path,
                  builder: (context, state) => _tabScreen(tab),
                ),
              ],
            ),
        ],
      ),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});

Widget _tabScreen(AppTab tab) => switch (tab) {
  AppTab.schedule => const ScheduleScreen(),
  AppTab.menu => const MenuScreen(),
  AppTab.today => const TodayScreen(),
  AppTab.weight => const WeightScreen(),
  AppTab.me => const MeScreen(),
};
