import 'package:domain/domain.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/time_ticker.dart';
import '../../schedule/application/schedule_providers.dart';
import 'today_view.dart';

/// Tiến độ của một tuần tiến độ (F-06). Tự cập nhật khi bản ghi ngày, lịch
/// tháng hoặc giờ đổi (F06-R6). null khi dữ liệu chưa đọc xong.
final weekProgressProvider = Provider.family<WeeklyProgress?, ProgressWeek>((
  ref,
  week,
) {
  final days = ref.watch(progressWeekDaysProvider(week)).value;
  final plans = ref.watch(monthPlansProvider).value;
  if (days == null || plans == null) return null;
  return WeeklyProgress.compute(
    week,
    days: days,
    planned: {for (final p in plans) p.month},
    template: ref.watch(weeklyTemplateProvider).value,
    now: ref.watch(nowProvider),
  );
});

/// Các tuần xem được ở S-25, cũ → mới: từ tuần thiết lập lịch đến tuần hiện
/// tại (F06-R5, F06-E3). Tháng đầu của lịch bắt đầu từ ngày thiết lập (UA-12).
final progressWeeksProvider = Provider<List<ProgressWeek>>((ref) {
  final plans = ref.watch(monthPlansProvider).value ?? const <MonthPlan>[];
  if (plans.isEmpty) return const [];
  return WeeklyProgress.weeks(
    setupDate: plans.first.startDate,
    today: ref.watch(todayProvider),
  );
});
