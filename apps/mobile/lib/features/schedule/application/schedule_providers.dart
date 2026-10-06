import 'package:domain/domain.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/time_ticker.dart';
import '../../../data/sync/sync_providers.dart';

/// Các tháng đã có lịch, cũ → mới.
final monthPlansProvider = StreamProvider<List<MonthPlan>>(
  (ref) => ref.watch(scheduleRepositoryProvider).watchPlans(),
);

/// Các ngày (thứ 2 → thứ 7) của một tháng.
final monthDaysProvider = StreamProvider.family<List<PlanDay>, YearMonth>(
  (ref, month) => ref.watch(scheduleRepositoryProvider).watchMonth(month),
);

/// Một ngày trong lịch tháng; null với chủ nhật hoặc ngày chưa có lịch.
final dayProvider = StreamProvider.family<PlanDay?, LocalDate>(
  (ref, date) => ref.watch(scheduleRepositoryProvider).watchDay(date),
);

/// Các ngày thứ 2 → thứ 7 của một tuần tiến độ; mỗi ngày lấy từ lịch của tháng
/// chứa nó (F06-E4).
final progressWeekDaysProvider =
    StreamProvider.family<List<PlanDay>, ProgressWeek>(
      (ref, week) => ref
          .watch(scheduleRepositoryProvider)
          .watchRange(week.start, week.end),
    );

final weeklyTemplateProvider = StreamProvider<WeeklyTemplate?>(
  (ref) => ref.watch(scheduleRepositoryProvider).watchTemplate(),
);

/// "Lịch tuần đã đổi" (F03-R7, UX-AC9): lịch tháng hiện tại được chia từ
/// lịch tuần khác lịch tuần đang lưu. Hiện banner Chia lại và chấm ở tab Lịch
/// tập cho đến khi chia lại hoặc sang tháng mới (F03-E5).
final templateChangedProvider = Provider<bool>((ref) {
  final template = ref.watch(weeklyTemplateProvider).value;
  final plans = ref.watch(monthPlansProvider).value;
  if (template == null || plans == null) return false;
  final month = LocalDate.fromDateTime(ref.watch(nowProvider)).yearMonth;
  for (final p in plans) {
    if (p.month == month) return p.templateHash != template.contentHash;
  }
  return false;
});
