import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/strings_vi.dart';
import '../../../app/theme.dart';
import '../../../core/widgets/app_sheet.dart';
import '../application/logout.dart';

/// S-73 (04 Bản 3 §6.9, UA3-04, NAV-19): hộp xác nhận → không có mạng: hộp
/// "Chưa đăng xuất được"; có mạng: hộp "Đang đồng bộ…" không nút → thành công:
/// gốc app dựng lại ở màn Đăng nhập, không thông báo nhanh; lỗi: hộp "Chưa đăng
/// xuất được" với câu F27-R3, ở lại S-56.
Future<void> confirmLogout(BuildContext context, WidgetRef ref) async {
  final confirmed =
      await showAppDialog<bool>(
        context,
        builder: (dialogContext) => AlertDialog(
          key: const ValueKey('logout-dialog'),
          title: const Text(S.logoutConfirmTitle, textAlign: TextAlign.center),
          content: const Text(S.logoutConfirmBody, textAlign: TextAlign.center),
          actions: [
            OutlinedButton(
              key: const ValueKey('logout-cancel'),
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text(S.cancel),
            ),
            // Nút đỏ: bước này xóa dữ liệu trên máy (UA3-16, NAV-6).
            FilledButton(
              key: const ValueKey('logout-confirm'),
              style: FilledButton.styleFrom(
                backgroundColor: dialogContext.colors.error,
                foregroundColor: dialogContext.colors.onError,
              ),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text(S.logout),
            ),
          ],
        ),
      ) ??
      false;
  if (!confirmed || !context.mounted) return;
  var syncing = false;
  final outcome = await ref
      .read(logoutProvider)
      .call(
        onSyncing: () {
          syncing = true;
          unawaited(
            showAppDialog<void>(
              context,
              barrierDismissible: false,
              builder: (_) => const _SyncingDialog(),
            ),
          );
        },
      );
  if (outcome == LogoutOutcome.done || !context.mounted) return;
  if (syncing) Navigator.of(context, rootNavigator: true).pop();
  await showAppDialog<void>(
    context,
    builder: (dialogContext) => AlertDialog(
      key: const ValueKey('logout-failed'),
      title: const Text(S.logoutFailedTitle, textAlign: TextAlign.center),
      content: Text(
        outcome == LogoutOutcome.offline ? S.logoutOffline : S.logoutSyncFailed,
        textAlign: TextAlign.center,
      ),
      actions: [
        FilledButton(
          key: const ValueKey('logout-failed-ok'),
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: const Text(S.understood),
        ),
      ],
    ),
  );
}

/// "Đang đồng bộ…" không có nút, không đóng được (UA3-04): đăng xuất không hủy
/// giữa chừng.
class _SyncingDialog extends StatelessWidget {
  const _SyncingDialog();

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: AlertDialog(
        key: const ValueKey('logout-syncing'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(
              S.logoutSyncing,
              textAlign: TextAlign.center,
              style: context.text.titleLarge,
            ),
            const SizedBox(height: 8),
            const Text(S.logoutSyncingBody, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
