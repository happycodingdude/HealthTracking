import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/shell/app_tab.dart';
import '../../../app/strings_vi.dart';
import '../../../core/widgets/settings_card.dart';
import '../../../core/widgets/tab_page.dart';
import '../../../data/sync/sync_providers.dart';
import 'dev_server_status.dart';

/// S-50 — Tôi. VS-02 có dòng "Tài khoản và dữ liệu"; các dòng hồ sơ, mức calo,
/// nhắc, ngân sách được thêm ở VS-05, VS-11, VS-13.
class MeScreen extends ConsumerWidget {
  const MeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pending = ref.watch(syncStatusProvider).value?.hasPending;
    return TabPage(
      tab: AppTab.me,
      title: S.tabMe,
      children: [
        SettingsCard(
          children: [
            SettingsRow(
              key: const ValueKey('row-account-data'),
              label: S.accountAndData,
              value: pending == null
                  ? null
                  : (pending ? S.syncPending : S.syncDone),
              onTap: () => context.go('/me/account'),
            ),
          ],
        ),
        const SizedBox(height: 24),
        const DevServerStatus(),
      ],
    );
  }
}
