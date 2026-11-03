import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../app/strings_vi.dart';
import '../../../core/formatters.dart';
import '../../../ui/components/components.dart';
import '../../../ui/theme.dart';
import '../../today/application/mark_session.dart';
import '../../workout/application/session_item_edits.dart';

/// Từ mức phóng chữ này trở lên, hai nút xếp dọc (UX-AC18).
const _stackedScale = 1.6;

/// S-65 — Xác nhận "Đã tập" (04 Bản 5 S-65; khung dùng chung cho S-79): tiêu
/// đề [title] ("Đã tập {nhóm cơ}?"), một câu [body], nút xám "Hủy", cam
/// "Lưu". Vuốt hay chạm vùng mờ = "Hủy". true = Bạn bấm "Lưu".
Future<bool> confirmDone(
  BuildContext context, {
  required String title,
  String body = S.doneConfirmBody,
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
        child: Text(
          body,
          key: const ValueKey('lock-confirm-body'),
          style: IronlyText.dialogBody,
        ),
      ),
    ) ??
    false;

/// Đánh dấu buổi theo lịch từ Hôm nay, S-21, S-23 (04 Bản 5 S-23, S-65).
///
/// - "Đã tập" → S-65 → "Lưu" → thông báo nhanh "Đã ghi: tập {nhóm cơ}"
///   (UR2-04). "Hủy" không đổi gì. Đổi lại được đến hết ngày (F05-R61).
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
    final muscles = Fmt.muscles(day.muscles);
    // FC5-03 (S-79): mọi bài đã bỏ qua → cùng khung S-65, câu "Mọi bài đã bỏ
    // qua. Buổi sẽ ghi là Không tập."; Lưu → buổi "Không tập".
    final allSkipped = SessionList.allSkipped(
      await container.read(sessionItemsReaderProvider)(day.date),
    );
    if (!context.mounted) return;
    final confirmed = await confirmDone(
      context,
      title: S.doneConfirmTitle(muscles),
      body: allSkipped ? S.allSkippedBody : S.doneConfirmBody,
    );
    if (!confirmed) return;
    onConfirmed?.call();
    try {
      await container
          .read(markSessionDoneProvider)
          .call(day.date, confirmed: confirmed);
    } on MarkException catch (e, st) {
      // Nút chỉ hiện khi đánh dấu được; lỗi ở đây là vừa qua 00:00 khi hộp
      // đang mở.
      await container
          .read(errorReporterProvider)
          .report(e, st, reason: 'mark_done');
      return;
    }
    if (!host.mounted) return;
    // S-79: không có "Đổi sang Đã tập" (sẽ lại về "Không tập" khi mọi bài
    // vẫn bỏ qua).
    showToast(host, allSkipped ? S.markedSkipped : S.markedDone(muscles));
  }

  /// "Không tập" cho buổi [day] (từ đầu ngày, kể cả đổi từ "Đã tập" —
  /// F05-R62). Buổi đã có mức tạ: hộp "Buổi này đã có mức tạ của {N} bài."
  /// với "Tiếp tục" · "Hủy" trên [context] trước khi lưu (F05-R28); mức tạ
  /// giữ nguyên (FD2-02, A5-12). [onConfirmed] chạy ngay trước khi lưu (S-21
  /// đóng bảng).
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

  /// Bỏ đánh dấu buổi [day] (FC5-13): về "Chờ đánh dấu", không hộp, không
  /// thông báo nhanh (04 Bản 5 S-23).
  static Future<void> unmark(BuildContext context, PlanDay day) async {
    final host = _stable(context);
    final container = ProviderScope.containerOf(host, listen: false);
    try {
      await container.read(unmarkSessionProvider).call(day.date);
    } on MarkException catch (e, st) {
      await container
          .read(errorReporterProvider)
          .report(e, st, reason: 'unmark');
    }
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
