import 'package:domain/domain.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/time_ticker.dart';
import '../../../data/sync/sync_providers.dart';
import '../../me/application/calorie_view.dart';

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

/// Có lịch hay Chưa có lịch (05 Bản 2 §6.4.2, TD2-09): S-10, S-20, S-50,
/// S-24. null khi chưa đọc xong lịch tuần (không vẽ trạng thái nào).
final scheduleStateProvider = Provider<ScheduleState?>((ref) {
  final template = ref.watch(weeklyTemplateProvider);
  if (!template.hasValue) return null;
  return ScheduleState.of(
    template: template.value,
    profile: ref.watch(profileProvider).value,
  );
});

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

/// Các khoảng tạm dừng trên máy (05 Bản 5 TD5-05, §6.4.3).
final pausesProvider = StreamProvider<List<SchedulePause>>(
  (ref) => ref.watch(schedulePauseRepositoryProvider).watchAll(),
);

/// Khoảng còn hiệu lực hôm nay: đang tạm dừng hoặc đặt trước (F31-R1, 05
/// Bản 5 §6.4.3 `activePauseProvider`); null = chưa có. S-10, S-20, S-76.
final activePauseProvider = Provider<SchedulePause?>(
  (ref) => PauseRules.active(
    ref.watch(pausesProvider).value ?? const [],
    LocalDate.fromDateTime(ref.watch(nowProvider)),
  ),
);

/// Ngày [date] nằm trong khoảng tạm dừng (lớp phủ lên lịch, FC5-09).
final pausedProvider = Provider.family<bool, LocalDate>(
  (ref, date) =>
      PauseRules.isPaused(date, ref.watch(pausesProvider).value ?? const []),
);
