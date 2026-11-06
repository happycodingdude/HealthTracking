import 'package:flutter/material.dart';

import '../../app/strings_vi.dart';
import '../../ui/components/components.dart';

/// Hỏi trước khi bỏ thay đổi chưa lưu ở màn toàn trang (04 §6.13.1, S-22,
/// Q-2). true = bỏ. Bảng trượt không hỏi: chạm ngoài / vuốt xuống là bỏ
/// (Bạn yêu cầu 06/11/2026).
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
