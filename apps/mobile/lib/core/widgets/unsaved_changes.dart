import 'package:flutter/material.dart';

import '../../app/strings_vi.dart';
import '../../ui/components/components.dart';

/// Hỏi trước khi bỏ thay đổi chưa lưu (04 §6.13.1, S-22, Q-2). true = bỏ.
/// Bảng ghi tạ dùng câu riêng (04 Bản 3 UA3-03): [title], [keepLabel].
/// Bản 4: hộp `IronlyDialog` (04 Bản 4 §6.1 hộp thoại), câu chữ giữ nguyên.
Future<bool> confirmDiscardChanges(
  BuildContext context, {
  String title = S.discardChangesTitle,
  String keepLabel = S.keepEditing,
}) async =>
    await showIronlyDialog<bool>(
      context,
      builder: (dialogContext) => IronlyDialog(
        key: const ValueKey('discard-changes'),
        title: title,
        secondaryLabel: keepLabel,
        secondaryKey: const ValueKey('discard-keep'),
        onSecondary: () => Navigator.of(dialogContext).pop(false),
        primaryLabel: S.discard,
        primaryKey: const ValueKey('discard-confirm'),
        onPrimary: () => Navigator.of(dialogContext).pop(true),
      ),
    ) ??
    false;

/// Bọc nội dung bảng trượt có ô nhập. Vuốt xuống hoặc chạm vùng mờ khi
/// [dirty] → hỏi [confirmDiscardChanges] trước khi đóng.
///
/// Bảng trượt mở bằng `showIronlySheet(..., enableDrag: false)`: thao tác vuốt
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
