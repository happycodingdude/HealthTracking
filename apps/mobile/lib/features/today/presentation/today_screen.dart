import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/shell/app_tab.dart';
import '../../../app/strings_vi.dart';
import '../../../core/formatters.dart';
import '../../../core/widgets/sync_indicator.dart';
import '../../../core/widgets/tab_page.dart';
import '../../../data/sync/sync_providers.dart';
import '../../me/application/update_display_name.dart';
import '../application/today_view.dart';
import 'today_cards.dart';

/// S-10 — Hôm nay (04 §6.7): đầu trang "Chào {tên hiển thị} · Thứ 4, 07/10" kèm
/// chỉ báo "Chưa đồng bộ"; thẻ buổi tập hôm nay; buổi chưa đánh dấu; thẻ tiến
/// độ tuần; thẻ thực đơn hôm nay.
class TodayScreen extends ConsumerWidget {
  const TodayScreen({super.key});

  /// Dòng đầu trang (UR-14). Chưa có tên thì chỉ hiện ngày.
  static String header(String? displayName, LocalDate today) {
    final date = Fmt.weekdayDate(today);
    return displayName == null || displayName.isEmpty
        ? date
        : '${S.greeting(displayName)} · $date';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final name = ref.watch(displayNameProvider).value;
    final today = ref.watch(todayProvider);
    final pending = ref.watch(syncStatusProvider).value?.hasPending ?? false;
    return TabPage(
      tab: AppTab.today,
      title: S.tabToday,
      subtitle: header(name, today),
      trailing: pending ? const SyncIndicator() : null,
      children: const [
        SessionCard(),
        UnmarkedCard(),
        ProgressCard(),
        MenuCard(),
      ],
    );
  }
}
