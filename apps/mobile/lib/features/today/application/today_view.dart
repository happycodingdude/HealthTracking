import 'package:domain/domain.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/time_ticker.dart';
import '../../schedule/application/schedule_providers.dart';

/// Hôm nay theo đồng hồ giao diện (đổi lúc 00:00 khi app đang mở).
final todayProvider = Provider<LocalDate>(
  (ref) => LocalDate.fromDateTime(ref.watch(nowProvider)),
);

/// Các ngày thứ 2 → thứ 7 của tuần tiến độ chứa hôm nay (chủ nhật: tuần vừa
/// kết thúc), theo thứ tự ngày.
final currentWeekDaysProvider = Provider<List<PlanDay>>(
  (ref) =>
      ref
          .watch(
            progressWeekDaysProvider(
              ProgressWeek.containing(ref.watch(todayProvider)),
            ),
          )
          .value ??
      const [],
);

/// Buổi "Chờ đánh dấu" khác buổi hôm nay trong tuần tiến độ hiện tại (UA-11,
/// 04 §6.7.2). Buổi đã thành "Không tập (tự động)" không hiện.
final unmarkedSessionsProvider = Provider<List<PlanDay>>((ref) {
  final now = ref.watch(nowProvider);
  final today = LocalDate.fromDateTime(now);
  return [
    for (final d in ref.watch(currentWeekDaysProvider))
      if (d.date != today &&
          SessionStatus.derive(d, now)?.state == SessionState.awaitingMark)
        d,
  ];
});

/// Buổi theo lịch gần nhất sau hôm nay ("Buổi tới", 04 §6.7.1).
final nextSessionProvider = Provider<PlanDay?>((ref) {
  final today = ref.watch(todayProvider);
  final planned = {
    for (final p in ref.watch(monthPlansProvider).value ?? const <MonthPlan>[])
      p.month,
  };
  final month = today.yearMonth;
  final days = [
    ...?ref.watch(monthDaysProvider(month)).value,
    if (planned.contains(month.next))
      ...?ref.watch(monthDaysProvider(month.next)).value,
  ];
  return SessionRules.nextSession(
    after: today,
    days: days,
    planned: planned,
    template: ref.watch(weeklyTemplateProvider).value,
  );
});
