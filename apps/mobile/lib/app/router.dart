import 'package:domain/domain.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/widgets/reference_tag.dart';
import '../features/auth/application/auth_controller.dart';
import '../features/auth/presentation/login_screen.dart';
import '../features/auth/presentation/register_screen.dart';
import '../features/auth/presentation/welcome_screen.dart';
import '../features/me/presentation/about_reference_screen.dart';
import '../features/me/presentation/account_data_screen.dart';
import '../features/me/presentation/budget_screen.dart';
import '../features/me/presentation/calorie_screen.dart';
import '../features/me/presentation/me_screen.dart';
import '../features/me/presentation/profile_screen.dart';
import '../features/menu/presentation/menu_screen.dart';
import '../features/onboarding/application/setup_state.dart';
import '../features/onboarding/presentation/calorie_step_screen.dart';
import '../features/onboarding/presentation/disclaimer_screen.dart';
import '../features/onboarding/presentation/profile_step_screen.dart';
import '../features/onboarding/presentation/reminder_step_screen.dart';
import '../features/onboarding/presentation/schedule_step_screen.dart';
import '../features/schedule/presentation/schedule_screen.dart';
import '../features/schedule/presentation/weekly_schedule_screen.dart';
import '../features/today/presentation/today_screen.dart';
import '../features/today/presentation/week_progress_screen.dart';
import '../features/weight/presentation/weight_screen.dart';
import 'shell/app_shell.dart';
import 'shell/app_tab.dart';

/// Quy tắc chuyển hướng theo trạng thái đăng nhập và thiết lập lần đầu
/// (VS01-T10, VS03-T07, VS03-T11, OB-3, OB-6, NAV-1, NAV-7).
///
/// - Chưa đăng nhập → S-01 (`/welcome`).
/// - Phiên hết hạn → S-01b (`/welcome/login`), dữ liệu trên máy được giữ.
/// - Vừa đăng nhập/đăng ký → bước thiết lập đang dở, hoặc [AuthState.landing]
///   khi đã thiết lập xong.
/// - Chưa hoàn tất thiết lập → chỉ ở trong luồng thiết lập (F01-R1); mở app
///   lại thì vào đúng bước đang dở. Trang "Về gợi ý tham khảo" xem được mọi
///   lúc (F10-R4).
@visibleForTesting
String? appRedirect(AuthState auth, SetupState setup, String location) {
  final inWelcome = location == '/welcome' || location.startsWith('/welcome/');
  switch (auth.status) {
    case AuthStatus.signedOut:
      return inWelcome ? null : '/welcome';
    case AuthStatus.expired:
      return inWelcome ? null : '/welcome/login';
    case AuthStatus.signedIn:
      break;
  }
  final completed = setup.isCompleted || auth.serverSetupCompleted;
  // Trả thẳng đích cuối cùng: go_router không chạy lại redirect cho đích của
  // một lần redirect do trạng thái đổi.
  if (inWelcome) {
    final landing = auth.landing;
    if (!completed) {
      // [AuthState.landing] đã tính từ hồ sơ vừa lấy về (OB-6), không chờ
      // trạng thái trên máy cập nhật.
      return onboardingSteps.contains(landing) ? landing : setup.path;
    }
    return landing == null || landing.startsWith('/onboarding')
        ? AppTab.today.path
        : landing;
  }
  if (location == aboutReferencePath) return null;
  final inOnboarding =
      location == '/onboarding' || location.startsWith('/onboarding/');
  if (completed) {
    return inOnboarding ? AppTab.today.path : null;
  }
  if (!inOnboarding) return setup.path;
  // Các bước chuyển tiếp ngay sau khi lưu, không chờ trạng thái trên máy cập
  // nhật; giao diện không có lối nhảy cóc bước.
  return onboardingSteps.contains(location) ? null : setup.path;
}

/// Các bước thiết lập lần đầu (04 §6.5).
@visibleForTesting
const onboardingSteps = {
  '/onboarding/1',
  '/onboarding/2',
  '/onboarding/3',
  '/onboarding/4',
  '/onboarding/5',
};

/// Router của app (TD-03). Mở app vào Hôm nay (NAV-1).
final routerProvider = Provider<GoRouter>((ref) {
  final auth = ValueNotifier<AuthState>(ref.read(authControllerProvider));
  final setup = ValueNotifier<SetupState>(ref.read(initialSetupProvider));
  ref
    ..listen(authControllerProvider, (_, next) => auth.value = next)
    ..listen(setupStateProvider, (_, next) {
      final value = next.value;
      if (value != null) setup.value = value;
    })
    ..onDispose(auth.dispose)
    ..onDispose(setup.dispose);

  final router = GoRouter(
    initialLocation: AppTab.today.path,
    refreshListenable: Listenable.merge([auth, setup]),
    redirect: (context, state) =>
        appRedirect(auth.value, setup.value, state.matchedLocation),
    routes: [
      GoRoute(
        path: '/welcome',
        builder: (_, _) => const WelcomeScreen(),
        routes: [
          GoRoute(path: 'register', builder: (_, _) => const RegisterScreen()),
          GoRoute(path: 'login', builder: (_, _) => const LoginScreen()),
        ],
      ),
      // Thiết lập lần đầu (04 §6.5): ngoài khung tab nên thanh tab bị ẩn (NAV-7).
      // `/onboarding` luôn được chuyển tới bước đang dở.
      GoRoute(path: '/onboarding', builder: (_, _) => const SizedBox.shrink()),
      GoRoute(
        path: '/onboarding/1',
        builder: (_, _) => const DisclaimerScreen(),
      ),
      GoRoute(
        path: '/onboarding/2',
        builder: (_, _) => const ProfileStepScreen(),
      ),
      GoRoute(
        path: '/onboarding/3',
        builder: (_, _) => const CalorieStepScreen(),
      ),
      GoRoute(
        path: '/onboarding/4',
        builder: (_, _) => const ScheduleStepScreen(),
      ),
      GoRoute(
        path: '/onboarding/5',
        builder: (_, _) => const ReminderStepScreen(),
      ),
      GoRoute(
        path: aboutReferencePath,
        builder: (_, _) => const AboutReferenceScreen(),
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
                  routes: [
                    // S-25 mở từ Hôm nay (thẻ tiến độ) hoặc Lịch tập (tiêu
                    // đề tuần), nằm trong tab đó.
                    if (tab == AppTab.today || tab == AppTab.schedule)
                      GoRoute(
                        path: 'progress/:week',
                        builder: (_, state) => WeekProgressScreen(
                          week: ProgressWeek.containing(
                            LocalDate.parse(state.pathParameters['week']!),
                          ),
                          tab: tab,
                        ),
                      ),
                    // S-22 (chế độ sửa) mở từ nút "Lịch tuần" ở S-20.
                    if (tab == AppTab.schedule)
                      GoRoute(
                        path: 'weekly',
                        builder: (_, _) => const WeeklyScheduleScreen(),
                      ),
                    // S-56 nằm trong tab Tôi, thanh tab vẫn hiện.
                    if (tab == AppTab.me) ...[
                      GoRoute(
                        path: 'account',
                        builder: (_, _) => const AccountDataScreen(),
                      ),
                      GoRoute(
                        path: 'profile',
                        builder: (_, _) => const ProfileScreen(),
                      ),
                      GoRoute(
                        path: 'calorie',
                        builder: (_, _) => const CalorieScreen(),
                      ),
                      GoRoute(
                        path: 'budget',
                        builder: (_, _) => const BudgetScreen(),
                      ),
                    ],
                  ],
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
