import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/strings_vi.dart';
import '../../../core/formatters.dart';
import '../../../core/widgets/phone_input_formatter.dart';
import '../../../data/sync/sync_providers.dart';
import '../../../data/sync/sync_status.dart';
import '../../../ui/components/components.dart';
import '../../../ui/theme.dart';
import '../../account/presentation/logout_dialogs.dart';
import '../../auth/application/auth_controller.dart';
import '../application/update_display_name.dart';
import 'edit_display_name_sheet.dart';

/// S-56 — Tài khoản và dữ liệu (04 Bản 4 S-56, F09, F-27): thẻ "Tên hiển
/// thị · Anton ›" · "Số điện thoại"; thẻ đồng bộ: icon tròn viền cam + "Chưa
/// đồng bộ" cam + "Sẽ tự đồng bộ khi có mạng" chữ phụ (đã đồng bộ: icon chữ
/// phụ + "Đã đồng bộ lúc …"); thẻ "Đăng xuất" đỏ với icon. Không câu giải
/// thích, không nhóm "Thiết bị này" (FR4-04).
class AccountDataScreen extends ConsumerWidget {
  const AccountDataScreen({super.key});

  /// Câu trạng thái đồng bộ ở S-56 (F09-E1).
  static String statusText(SyncStatus status) {
    final last = status.lastSyncedAt;
    if (!status.hasPending && last != null) return S.syncedAt(Fmt.clock(last));
    return S.syncPending;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final name = ref.watch(displayNameProvider).value;
    final phone = ref.watch(authControllerProvider).phone;
    final status = ref.watch(syncStatusProvider).value;
    final pending = status?.hasPending ?? false;
    return IronlySubPage(
      title: S.accountAndData,
      children: [
        IronlyListCard(
          children: [
            IronlyRow(
              key: const ValueKey('row-display-name'),
              title: S.fieldDisplayName,
              value: name ?? '',
              chevron: true,
              onTap: () => showEditDisplayNameSheet(context, name ?? ''),
            ),
            IronlyRow(
              key: const ValueKey('row-phone'),
              title: S.fieldPhone,
              value: phone == null ? '' : PhoneInputFormatter.format(phone),
            ),
          ],
        ),
        const CardGap(),
        IronlyListCard(
          children: [
            IronlyRow(
              key: const ValueKey('row-sync'),
              leading: CircleIcon(
                pending ? Icons.sync_problem : Icons.cloud_done_outlined,
                color: pending ? t.accent : t.textSecondary,
                ring: pending ? t.accent : null,
              ),
              title: status == null ? '' : statusText(status),
              titleStyle: pending
                  ? IronlyText.body.copyWith(
                      color: t.accent,
                      fontWeight: FontWeight.w600,
                    )
                  : null,
              subtitle: pending ? S.syncAutoWhenOnline : null,
              semanticsLabel: status == null
                  ? null
                  : pending
                  ? '${S.syncPending}, ${S.syncAutoWhenOnline}'
                  : statusText(status),
            ),
          ],
        ),
        const CardGap(),
        // Đăng xuất (F-27): chữ đỏ với icon; hộp xác nhận mới có nút đỏ.
        IronlyListCard(
          children: [
            IronlyRow(
              key: const ValueKey('row-logout'),
              leading: CircleIcon(Icons.logout, color: t.danger),
              title: S.logout,
              titleStyle: IronlyText.body.copyWith(color: t.danger),
              onTap: () => confirmLogout(context, ref),
            ),
          ],
        ),
      ],
    );
  }
}
