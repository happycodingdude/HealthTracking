import 'package:flutter/material.dart';

import '../../../app/shell/app_tab.dart';
import '../../../app/strings_vi.dart';
import '../../../core/widgets/tab_page.dart';
import 'dev_server_status.dart';

/// Màn hình giữ chỗ của tab Tôi (VS-00). Nội dung S-50 thêm ở các slice sau.
class MeScreen extends StatelessWidget {
  const MeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const TabPage(
      tab: AppTab.me,
      title: S.tabMe,
      children: [DevServerStatus()],
    );
  }
}
