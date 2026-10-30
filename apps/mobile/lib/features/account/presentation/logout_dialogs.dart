import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/strings_vi.dart';
import '../../../ui/components/components.dart';
import '../../../ui/theme.dart';
import '../application/logout.dart';

/// S-73 (04 Bản 4 S-73, UA3-04, NAV-19): hộp "Đăng xuất?" + câu nguyên văn
/// Bản 3, nút xám Hủy + đỏ Đăng xuất → không có mạng: hộp lỗi; có mạng: hộp
/// "Đang đồng bộ…" (vòng xoay cam, không nút) → thành công: gốc app dựng lại
/// ở màn Đăng nhập; lỗi: hộp câu nguyên văn + "Thử lại" / "Hủy", ở lại S-56.
Future<void> confirmLogout(BuildContext context, WidgetRef ref) async {
  final confirmed =
      await showIronlyDialog<bool>(
        context,
        builder: (dialogContext) => IronlyDialog(
          key: const ValueKey('logout-dialog'),
          title: S.logoutConfirmTitle,
          body: S.logoutConfirmBody,
          secondaryLabel: S.cancel,
          secondaryKey: const ValueKey('logout-cancel'),
          onSecondary: () => Navigator.of(dialogContext).pop(false),
          // Nút đỏ: bước này xóa dữ liệu trên máy (UA3-16, NAV-6).
          primaryLabel: S.logout,
          primaryKey: const ValueKey('logout-confirm'),
          destructive: true,
          onPrimary: () => Navigator.of(dialogContext).pop(true),
        ),
      ) ??
      false;
  if (!confirmed || !context.mounted) return;
  await _attempt(context, ref);
}

Future<void> _attempt(BuildContext context, WidgetRef ref) async {
  var syncing = false;
  final outcome = await ref
      .read(logoutProvider)
      .call(
        onSyncing: () {
          syncing = true;
          unawaited(
            showIronlyDialog<void>(
              context,
              barrierDismissible: false,
              builder: (_) => const _SyncingDialog(),
            ),
          );
        },
      );
  if (outcome == LogoutOutcome.done || !context.mounted) return;
  if (syncing) Navigator.of(context, rootNavigator: true).pop();
  final retry =
      await showIronlyDialog<bool>(
        context,
        builder: (dialogContext) => IronlyDialog(
          key: const ValueKey('logout-failed'),
          title: S.logoutFailedTitle,
          body: outcome == LogoutOutcome.offline
              ? S.logoutOffline
              : S.logoutSyncFailed,
          secondaryLabel: S.cancel,
          secondaryKey: const ValueKey('logout-failed-ok'),
          onSecondary: () => Navigator.of(dialogContext).pop(false),
          primaryLabel: S.retry,
          primaryKey: const ValueKey('logout-failed-retry'),
          onPrimary: () => Navigator.of(dialogContext).pop(true),
        ),
      ) ??
      false;
  if (retry && context.mounted) await _attempt(context, ref);
}

/// "Đang đồng bộ…" không có nút, không đóng được (UA3-04): đăng xuất không hủy
/// giữa chừng.
class _SyncingDialog extends StatelessWidget {
  const _SyncingDialog();

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return PopScope(
      canPop: false,
      child: IronlyDialog(
        key: const ValueKey('logout-syncing'),
        title: S.logoutSyncing,
        child: Center(
          child: SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(color: t.accent, strokeWidth: 3),
          ),
        ),
      ),
    );
  }
}
