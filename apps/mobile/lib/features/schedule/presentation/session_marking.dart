import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../app/strings_vi.dart';
import '../../../app/time_ticker.dart';
import '../../../core/formatters.dart';
import '../../../ui/components/components.dart';
import '../../../ui/theme.dart';
import '../../today/application/mark_session.dart';

/// Từ mức phóng chữ này trở lên, hai nút xếp dọc (UX-AC18).
const _stackedScale = 1.6;

/// S-65 — Xác nhận chốt buổi (04 Bản 2 S-65, UA2-02, 06 Bản 2 ED2-04). Mọi
/// đường lưu "Đã tập" và buổi tập thêm đi qua hộp này. [title] = "Đã tập
/// {nhóm cơ}?" hoặc "Lưu buổi tập thêm?"; dòng 2 chỉ khi buổi là hôm nay
/// ([today]). Vuốt hay chạm vùng mờ = "Hủy". true = Bạn bấm "Lưu".
Future<bool> confirmLock(
  BuildContext context, {
  required String title,
  required bool today,
}) async =>
    await showIronlyDialog<bool>(
      context,
      builder: (dialogContext) => IronlyDialog(
        key: const ValueKey('lock-confirm'),
        title: title,
        secondaryLabel: S.cancel,
        secondaryKey: const ValueKey('lock-confirm-cancel'),
        onSecondary: () => Navigator.of(dialogContext).pop(false),
        // Không tô đỏ: đây không phải thao tác xóa.
        primaryLabel: S.save,
        primaryKey: const ValueKey('lock-confirm-save'),
        onPrimary: () => Navigator.of(dialogContext).pop(true),
        // Câu chữ nguyên văn Bản 2 (FR4-03); dòng 2 chỉ khi buổi là hôm nay.
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(S.lockConfirmLine1, style: IronlyText.dialogBody),
            if (today) ...[
              const SizedBox(height: TokenSpace.s2),
              Text(
                S.lockConfirmLine2,
                key: const ValueKey('lock-confirm-line2'),
                style: IronlyText.dialogBody,
              ),
            ],
          ],
        ),
      ),
    ) ??
    false;

/// Đánh dấu buổi theo lịch từ Hôm nay và S-21 (04 Bản 2 §6.6.1, S-21).
///
/// - "Đã tập" → S-65 → "Lưu" → thông báo nhanh "Đã ghi: tập {nhóm cơ}"
///   (UR2-04). "Hủy" không đổi gì.
/// - "Không tập" lưu ngay, thông báo nhanh "Đã ghi: không tập" kèm "Đổi sang
///   Đã tập" (mở S-65); không có Hoàn tác (UR2-05, UD2-03).
///
/// Thông báo nhanh, hộp S-65 mở từ thông báo, và provider dùng ngữ cảnh của
/// Navigator gốc: dòng hay bảng nơi Bạn bấm có thể biến mất ngay sau khi lưu
/// (dòng "Buổi chưa đánh dấu", bảng S-21 đóng trước khi lưu).
abstract final class SessionMarking {
  static BuildContext _stable(BuildContext context) =>
      Navigator.of(context, rootNavigator: true).context;

  /// "Đã tập" hoặc "Đổi sang Đã tập" cho buổi [day]. Hộp S-65 mở trên
  /// [context]; [onConfirmed] chạy ngay sau khi Bạn bấm "Lưu" (S-21 đóng bảng).
  static Future<void> done(
    BuildContext context,
    PlanDay day, {
    VoidCallback? onConfirmed,
  }) async {
    final host = _stable(context);
    final container = ProviderScope.containerOf(host, listen: false);
    final today = LocalDate.fromDateTime(container.read(nowProvider));
    final muscles = Fmt.muscles(day.muscles);
    final confirmed = await confirmLock(
      context,
      title: S.doneConfirmTitle(muscles),
      today: day.date == today,
    );
    if (!confirmed) return;
    onConfirmed?.call();
    try {
      await container
          .read(markSessionDoneProvider)
          .call(day.date, confirmed: confirmed);
    } on MarkException catch (e, st) {
      // Nút chỉ hiện khi đánh dấu được; lỗi ở đây là vừa qua hạn khi hộp đang
      // mở.
      await container
          .read(errorReporterProvider)
          .report(e, st, reason: 'mark_done');
      return;
    }
    if (host.mounted) showToast(host, S.markedDone(muscles));
  }

  /// "Không tập" cho buổi [day]. Buổi đã có mức tạ: hộp "Buổi này đã có mức
  /// tạ của {N} bài." với "Tiếp tục" · "Hủy" trên [context] trước khi lưu
  /// (F05-R28); mức tạ giữ nguyên (FD2-02). [onConfirmed] chạy ngay trước khi
  /// lưu (S-21 đóng bảng).
  static Future<void> skipped(
    BuildContext context,
    PlanDay day, {
    VoidCallback? onConfirmed,
  }) async {
    final host = _stable(context);
    final container = ProviderScope.containerOf(host, listen: false);
    final skip = container.read(markSessionSkippedProvider);
    final lifts = await skip.liftLogCount(day.date);
    if (lifts > 0) {
      if (!context.mounted) return;
      if (!await _confirmLiftsKept(context, lifts)) return;
    }
    onConfirmed?.call();
    final PlanDay updated;
    try {
      updated = await skip.call(day.date);
    } on MarkException catch (e, st) {
      await container
          .read(errorReporterProvider)
          .report(e, st, reason: 'mark_skipped');
      return;
    }
    if (!host.mounted) return;
    showToast(
      host,
      S.markedSkipped,
      action: S.changeToDone,
      onAction: () {
        if (host.mounted) done(host, updated);
      },
    );
  }
}

/// F05-R28: "Buổi này đã có mức tạ của {N} bài." · "Tiếp tục" · "Hủy". true =
/// tiếp tục lưu "Không tập".
Future<bool> _confirmLiftsKept(BuildContext context, int n) async =>
    await showIronlyDialog<bool>(
      context,
      builder: (dialogContext) => IronlyDialog(
        key: const ValueKey('lifts-kept-confirm'),
        title: S.liftLogsExist(n),
        secondaryLabel: S.cancel,
        secondaryKey: const ValueKey('lifts-kept-cancel'),
        onSecondary: () => Navigator.of(dialogContext).pop(false),
        primaryLabel: S.continueLabel,
        primaryKey: const ValueKey('lifts-kept-continue'),
        onPrimary: () => Navigator.of(dialogContext).pop(true),
      ),
    ) ??
    false;

/// "Đã tập" (nút chính) · "Không tập" (nút phụ cùng kích thước, 04 §6.7.1).
class MarkButtons extends StatelessWidget {
  const MarkButtons({
    super.key,
    required this.day,
    required this.onDone,
    required this.onSkipped,
    this.compact = false,
  });

  final PlanDay day;
  final VoidCallback onDone;
  final VoidCallback onSkipped;

  /// Nút nhỏ trong danh sách buổi chưa đánh dấu (04 §6.7.2).
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final key = day.date.toKey();
    final padding = compact ? const EdgeInsets.symmetric(horizontal: 16) : null;
    final done = FilledButton(
      key: ValueKey('mark-done-$key'),
      style: FilledButton.styleFrom(padding: padding),
      onPressed: onDone,
      child: const Text(S.sessionDone, textAlign: TextAlign.center),
    );
    final skipped = OutlinedButton(
      key: ValueKey('mark-skipped-$key'),
      style: OutlinedButton.styleFrom(padding: padding),
      onPressed: onSkipped,
      child: const Text(S.sessionSkipped, textAlign: TextAlign.center),
    );
    if (MediaQuery.textScalerOf(context).scale(1) >= _stackedScale) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [done, const SizedBox(height: 8), skipped],
      );
    }
    if (compact) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [done, const SizedBox(width: 8), skipped],
      );
    }
    return Row(
      children: [
        Expanded(child: done),
        const SizedBox(width: 12),
        Expanded(child: skipped),
      ],
    );
  }
}

/// Nút "Đổi sang Đã tập" (nút phụ, cả chiều ngang; mock S-10-4, S-21-3).
class ChangeToDoneButton extends StatelessWidget {
  const ChangeToDoneButton({super.key, required this.day, required this.onTap});

  final PlanDay day;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => OutlinedButton(
    key: ValueKey('change-to-done-${day.date.toKey()}'),
    onPressed: onTap,
    child: const Text(S.changeToDone, textAlign: TextAlign.center),
  );
}

/// Dòng "Đã chốt khi lưu" thay nút Sửa ở Hôm nay và S-21 (04 Bản 2 UA2-06,
/// mock S-10-3).
class LockedOnSaveLine extends StatelessWidget {
  const LockedOnSaveLine({super.key});

  @override
  Widget build(BuildContext context) {
    final color = context.tokens.textSecondary;
    return Row(
      key: const ValueKey('locked-on-save'),
      children: [
        ExcludeSemantics(
          child: Icon(Icons.lock_outline, size: 18, color: color),
        ),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            S.lockedOnSave,
            style: context.text.bodyLarge?.copyWith(color: color),
          ),
        ),
      ],
    );
  }
}
