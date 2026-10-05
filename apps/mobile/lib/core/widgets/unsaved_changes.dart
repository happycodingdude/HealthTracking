import 'package:flutter/material.dart';

import '../../app/strings_vi.dart';
import 'app_sheet.dart';

/// Hỏi trước khi bỏ thay đổi chưa lưu (04 §6.13.1, S-22, Q-2). true = bỏ.
Future<bool> confirmDiscardChanges(BuildContext context) async =>
    await showAppDialog<bool>(
      context,
      builder: (dialogContext) => AlertDialog(
        title: const Text(S.discardChangesTitle),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text(S.keepEditing),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text(S.discard),
          ),
        ],
      ),
    ) ??
    false;

/// Bọc nội dung bảng trượt có ô nhập. Vuốt xuống hoặc chạm vùng mờ khi
/// [dirty] → hỏi [confirmDiscardChanges] trước khi đóng.
///
/// Bảng trượt mở bằng `showAppSheet(..., enableDrag: false)`: thao tác vuốt
/// mặc định của Flutter đóng bảng ngay, không qua [PopScope].
class UnsavedChangesGuard extends StatelessWidget {
  const UnsavedChangesGuard({
    super.key,
    required this.dirty,
    required this.child,
  });

  final bool dirty;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return PopScope<Object?>(
      canPop: !dirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final navigator = Navigator.of(context);
        if (await confirmDiscardChanges(context)) navigator.pop();
      },
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onVerticalDragEnd: (details) {
          if ((details.primaryVelocity ?? 0) > 200) {
            Navigator.of(context).maybePop();
          }
        },
        child: child,
      ),
    );
  }
}
