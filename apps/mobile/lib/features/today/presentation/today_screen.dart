import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../app/shell/app_tab.dart';
import '../../../app/strings_vi.dart';
import '../../../core/formatters.dart';
import '../../../core/widgets/sync_indicator.dart';
import '../../../core/widgets/tab_page.dart';
import '../../../data/sync/sync_providers.dart';
import '../../me/application/update_display_name.dart';

/// S-10 — Hôm nay. VS-02 có đầu trang: "Chào {tên hiển thị} · Thứ 4, 07/10",
/// tiêu đề và chỉ báo "Chưa đồng bộ" (04 §6.7). Các thẻ thêm ở VS-06 → VS-12.
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
    final today = ref.watch(clockProvider).today();
    final pending = ref.watch(syncStatusProvider).value?.hasPending ?? false;
    return TabPage(
      tab: AppTab.today,
      title: S.tabToday,
      subtitle: header(name, today),
      trailing: pending ? const SyncIndicator() : null,
    );
  }
}
