import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/me/application/calorie_view.dart';
import '../../features/me/application/reminders.dart';
import '../../features/schedule/application/schedule_providers.dart';
import 'app_tab.dart';

/// Mỗi tab có một [ScrollController] riêng để chạm lại tab đang mở thì cuộn
/// về đầu (NAV-3). Vị trí cuộn được giữ khi đổi tab (NAV-8).
final class TabScrollControllers {
  final _controllers = {for (final t in AppTab.values) t: ScrollController()};

  ScrollController of(AppTab tab) => _controllers[tab]!;

  void scrollToTop(AppTab tab, {required bool animate}) {
    final c = _controllers[tab]!;
    if (!c.hasClients) return;
    if (animate) {
      c.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
      );
    } else {
      c.jumpTo(0);
    }
  }

  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
  }
}

final tabScrollControllersProvider = Provider<TabScrollControllers>((ref) {
  final controllers = TabScrollControllers();
  ref.onDispose(controllers.dispose);
  return controllers;
});

/// Tab đang có chấm báo hiệu (04 §6.3.1). Lịch tập: lịch tuần đã đổi nhưng
/// chưa chia lại (F03-R7, UX-AC9). Tôi: nhắc đang bật nhưng iPhone chặn
/// thông báo (F04-E2), hoặc có đề xuất mức calo đang chờ (F02-E3, UX-AC13).
final tabDotsProvider = Provider<Set<AppTab>>(
  (ref) => {
    if (ref.watch(templateChangedProvider)) AppTab.schedule,
    if (ref.watch(remindersBlockedProvider) ||
        ref.watch(profileProvider).value?.caloriePendingKcal != null)
      AppTab.me,
  },
);
