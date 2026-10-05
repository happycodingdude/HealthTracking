import 'package:flutter/material.dart';

import '../../../app/shell/app_tab.dart';
import '../../../app/strings_vi.dart';
import '../../../core/widgets/tab_page.dart';

/// Màn hình giữ chỗ của tab (VS-00). Nội dung thật được thêm ở các slice sau.
class ScheduleScreen extends StatelessWidget {
  const ScheduleScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const TabPage(tab: AppTab.schedule, title: S.tabSchedule);
  }
}
