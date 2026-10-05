import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/application/auth_controller.dart';
import '../features/auth/presentation/login_screen.dart';
import '../features/auth/presentation/register_screen.dart';
import '../features/auth/presentation/welcome_screen.dart';
import '../features/me/presentation/me_screen.dart';
import '../features/menu/presentation/menu_screen.dart';
import '../features/onboarding/presentation/onboarding_placeholder_screen.dart';
import '../features/schedule/presentation/schedule_screen.dart';
import '../features/today/presentation/today_screen.dart';
import '../features/weight/presentation/weight_screen.dart';
import 'shell/app_shell.dart';
import 'shell/app_tab.dart';

/// Quy tắc chuyển hướng theo trạng thái đăng nhập (VS01-T10, OB-6, NAV-1).
///
/// - Chưa đăng nhập → S-01 (`/welcome`).
/// - Phiên hết hạn → S-01b (`/welcome/login`), dữ liệu trên máy được giữ.
/// - Vừa đăng nhập/đăng ký → [AuthState.landing] (S-02 hoặc Hôm nay).
@visibleForTesting
String? authRedirect(AuthState auth, String location) {
  final inWelcome = location == '/welcome' || location.startsWith('/welcome/');
  return switch (auth.status) {
    AuthStatus.signedOut => inWelcome ? null : '/welcome',
    AuthStatus.expired => inWelcome ? null : '/welcome/login',
    AuthStatus.signedIn =>
      inWelcome ? (auth.landing ?? AppTab.today.path) : null,
  };
}

/// Router của app (TD-03). Mở app vào Hôm nay (NAV-1).
final routerProvider = Provider<GoRouter>((ref) {
  final auth = ValueNotifier<AuthState>(ref.read(authControllerProvider));
  ref
    ..listen(authControllerProvider, (_, next) => auth.value = next)
    ..onDispose(auth.dispose);

  final router = GoRouter(
    initialLocation: AppTab.today.path,
    refreshListenable: auth,
    redirect: (context, state) =>
        authRedirect(auth.value, state.matchedLocation),
    routes: [
      GoRoute(
        path: '/welcome',
        builder: (_, _) => const WelcomeScreen(),
        routes: [
          GoRoute(path: 'register', builder: (_, _) => const RegisterScreen()),
          GoRoute(path: 'login', builder: (_, _) => const LoginScreen()),
        ],
      ),
      GoRoute(
        path: '/onboarding',
        builder: (_, _) => const OnboardingPlaceholderScreen(),
      ),
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
