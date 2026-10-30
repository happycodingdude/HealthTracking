import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/widgets/unsaved_changes.dart';
import '../../features/me/application/budget_view.dart';
import '../../features/me/application/calorie_view.dart';
import '../../features/me/presentation/budget_screen.dart';
import '../../features/today/application/today_view.dart';
import '../../features/training/application/training_section.dart';
import '../../ui/components/ironly_tab_bar.dart';
import 'app_tab.dart';
import 'tab_scroll.dart';
import 'tab_stacks.dart';

/// Khung 5 tab trên `StatefulShellRoute.indexedStack`. Chạm một tab luôn về
/// trang đầu của tab đó, ở đầu trang (NAV-15); đang ở trang đầu thì cuộn về
/// đầu (NAV-3). Rời tab thì tab đó về đầu trang (NAV-16).
class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  @override
  void didUpdateWidget(AppShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    final left = oldWidget.navigationShell.currentIndex;
    if (left == widget.navigationShell.currentIndex) return;
    // Mọi cách rời tab (chạm tab, liên kết trong app, thông báo) → lần sau
    // mở lại thấy từ đầu trang (NAV-16).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(tabScrollControllersProvider).reset(AppTab.values[left]);
      }
    });
  }

  Future<void> _onTap(AppTab tab) async {
    final shell = widget.navigationShell;
    final current = AppTab.values[shell.currentIndex];
    final scroll = ref.read(tabScrollControllersProvider);
    if (tab == current && GoRouter.of(context).state.uri.path == tab.path) {
      scroll.scrollToTop(
        tab,
        animate: !MediaQuery.disableAnimationsOf(context),
        section: ref.read(trainingTabProvider),
      );
      return;
    }
    // Về trang đầu bỏ các màn con mà không qua PopScope: tab có màn đang sửa
    // dở thì hỏi trước (NAV-6). "Tiếp tục sửa" → ở lại / về đúng màn đó.
    final discard =
        !ref.read(tabStacksProvider).hasUnsavedChanges(tab) ||
        await confirmDiscardChanges(context);
    if (!mounted) return;
    if (tab == current) {
      if (!discard) return;
      scroll.reset(tab);
    }
    shell.goBranch(tab.index, initialLocation: discard);
  }

  @override
  Widget build(BuildContext context) {
    final current = AppTab.values[widget.navigationShell.currentIndex];
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
      body: widget.navigationShell,
      bottomNavigationBar: IronlyTabBar(
        current: current,
        dots: ref.watch(tabDotsProvider),
        onTap: _onTap,
      ),
    );
  }
}
