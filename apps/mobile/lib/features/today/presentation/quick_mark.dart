import 'package:domain/domain.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../app/strings_vi.dart';
import '../../../core/formatters.dart';
import '../../../core/widgets/toast.dart';
import '../../schedule/presentation/mark_session_sheet.dart';
import '../application/mark_session.dart';

/// Đánh dấu 1 chạm từ Hôm nay (04 §6.7.1, §6.7.2).
///
/// - "Đã tập" lưu ngay với nhóm cơ theo lịch, thông báo nhanh kèm "Sửa nhóm
///   cơ" (UA-08).
/// - "Không tập" lưu ngay, thông báo nhanh kèm "Hoàn tác" trong 4 giây (UA-09).
abstract final class QuickMark {
  static Future<void> done(
    BuildContext context,
    WidgetRef ref,
    PlanDay day,
  ) async {
    if (!await _mark(ref, day.date, DayMark.done, day.muscles)) return;
    if (!context.mounted) return;
    showToast(
      context,
      S.markedDone(Fmt.muscles(day.muscles)),
      action: S.editMuscles,
      onAction: () {
        if (context.mounted) showMarkSessionSheet(context, day.date);
      },
    );
  }

  static Future<void> skipped(
    BuildContext context,
    WidgetRef ref,
    PlanDay day,
  ) async {
    if (!await _mark(ref, day.date, DayMark.skipped, null)) return;
    if (!context.mounted) return;
    showToast(
      context,
      S.markedSkipped,
      action: S.undo,
      onAction: () => _mark(ref, day.date, null, null),
    );
  }

  /// false khi không đánh dấu được (đã báo lỗi kỹ thuật).
  static Future<bool> _mark(
    WidgetRef ref,
    LocalDate date,
    DayMark? mark,
    List<MuscleGroup>? actual,
  ) async {
    try {
      await ref.read(markSessionProvider).call(date, mark, actual: actual);
      return true;
    } on MarkException catch (e, st) {
      // Nút chỉ hiện khi đánh dấu được; lỗi ở đây là lệch giờ hiếm gặp.
      await ref
          .read(errorReporterProvider)
          .report(e, st, reason: 'mark_session');
      return false;
    }
  }
}
