import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/strings_vi.dart';
import '../../../app/theme.dart';
import '../../../core/formatters.dart';
import '../../../core/widgets/heading.dart';
import '../../../core/widgets/phone_input_formatter.dart';
import '../../../core/widgets/settings_card.dart';
import '../../../data/sync/sync_providers.dart';
import '../../../data/sync/sync_status.dart';
import '../../auth/application/auth_controller.dart';
import '../application/update_display_name.dart';
import 'edit_display_name_sheet.dart';

/// S-56 — Tài khoản và dữ liệu (F09). Không có mục xóa tài khoản ở Bản 1 (IA-02).
class AccountDataScreen extends ConsumerWidget {
  const AccountDataScreen({super.key});

  /// Câu trạng thái đồng bộ ở S-56 (F09-E1).
  static String statusText(SyncStatus status) {
    final last = status.lastSyncedAt;
    if (!status.hasPending && last != null) return S.syncedAt(Fmt.clock(last));
    return S.syncPendingDetail;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final name = ref.watch(displayNameProvider).value;
    final phone = ref.watch(authControllerProvider).phone;
    final status = ref.watch(syncStatusProvider).value;
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: EdgeInsets.fromLTRB(
            16,
            8,
            16,
            MediaQuery.paddingOf(context).bottom + 24,
          ),
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.only(right: 12),
                ),
                onPressed: () => context.pop(),
                icon: const Icon(Icons.chevron_left),
                label: const Text(S.tabMe),
              ),
            ),
            const SizedBox(height: 16),
            Heading(
              S.accountAndData,
              style: context.text.headlineMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 20),
            SettingsCard(
              children: [
                SettingsRow(
                  key: const ValueKey('row-display-name'),
                  label: S.fieldDisplayName,
                  value: name ?? '',
                  onTap: () => showEditDisplayNameSheet(context, name ?? ''),
                ),
                SettingsRow(
                  label: S.fieldPhone,
                  value: phone == null ? '' : PhoneInputFormatter.format(phone),
                ),
                SettingsRow(
                  key: const ValueKey('row-sync'),
                  label: S.syncLabel,
                  value: status == null ? '' : statusText(status),
                ),
              ],
            ),
            if (status?.hasPending ?? false)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Text(
                  S.syncLossWarning,
                  style: context.text.bodyMedium?.copyWith(
                    color: context.palette.textSecondary,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
