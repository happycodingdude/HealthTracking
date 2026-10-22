import 'package:flutter/material.dart';

import '../../app/strings_vi.dart';
import 'app_sheet.dart';

/// Hỏi trước khi bỏ thay đổi chưa lưu (04 §6.13.1, S-22, Q-2). true = bỏ.
/// Bảng ghi tạ dùng câu riêng (04 Bản 3 UA3-03): [title], [keepLabel].
Future<bool> confirmDiscardChanges(
  BuildContext context, {
  String title = S.discardChangesTitle,
  String keepLabel = S.keepEditing,
}) async =>
    await showAppDialog<bool>(
      context,
      builder: (dialogContext) => AlertDialog(
        key: const ValueKey('discard-changes'),
        title: Text(title),
        actions: [
          OutlinedButton(
            key: const ValueKey('discard-keep'),
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(keepLabel),
          ),
          FilledButton(
            key: const ValueKey('discard-confirm'),
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
    this.title = S.discardChangesTitle,
    this.keepLabel = S.keepEditing,
  });

  final bool dirty;
  final Widget child;
  final String title;
  final String keepLabel;

  @override
  Widget build(BuildContext context) {
    return PopScope<Object?>(
      canPop: !dirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final navigator = Navigator.of(context);
        if (await confirmDiscardChanges(
          context,
          title: title,
          keepLabel: keepLabel,
        )) {
          navigator.pop();
        }
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
