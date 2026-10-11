import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/me/application/budget_view.dart';
import '../../features/me/application/calorie_view.dart';
import '../../features/me/presentation/budget_screen.dart';
import '../../features/today/application/today_view.dart';
import '../../features/training/application/training_section.dart';
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
    // Riverpod 3 tạm dừng provider khi mọi widget dùng nó đang ẩn (tab khác).
    // Provider tính toán có provider khác phụ thuộc phải luôn cập nhật ở khung
    // luôn hiện: không thì tab mở lần đầu sau khi dữ liệu đổi (sang ngày mới,
    // ghi cân, sửa hồ sơ) làm nó tính lại ngay lúc dựng giao diện và báo các
    // provider phụ thuộc giữa chừng ("setState() during build").
    ref
      ..listen(todayProvider, (_, _) {})
      ..listen(calorieViewProvider, (_, _) {})
      // F11-R4: hộp báo 80% ngay sau lần tạo thực đơn, dù đang ở tab nào.
      ..listen(budgetWarningProvider, (_, show) {
        if (!show) return;
        ref.read(budgetWarningProvider.notifier).shown();
        showBudgetWarning(context);
      });
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
                  section: ref.read(trainingTabProvider),
                );
          } else {
            navigationShell.goBranch(tab.index);
          }
        },
      ),
    );
  }
}
