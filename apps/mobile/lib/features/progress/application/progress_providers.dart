import 'package:domain/domain.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../workout/application/lift_unit.dart';
import '../../workout/application/session_providers.dart';

/// Danh sách Tiến bộ mức tạ (05 Bản 2 §6.4.2 `progressListProvider`, F-23):
/// đọc Drift nên dùng được khi không có mạng và tính cả bản ghi chưa đồng bộ
/// (F23-R6). null khi chưa đọc xong.
final progressListProvider = Provider<List<ProgressItem>?>((ref) {
  final logs = ref.watch(allLiftLogsProvider).value;
  final exercises = ref.watch(allExercisesProvider).value;
  if (logs == null || exercises == null) return null;
  return ProgressList.of(logs, exercises);
});

/// Biểu đồ của một bài trong một tháng, giới hạn chuyển tháng (F22-R2) và
/// mốc đổi đơn vị gần nhất (F22-R42, 05 Bản 3 §6.4.2).
typedef LiftChartView = ({
  MonthlyLiftChart chart,
  YearMonth? earliest,
  LiftUnitChange? unitChange,
});

/// Biểu đồ mức tạ của bài trong tháng (05 Bản 2 §6.4.2 `liftChartProvider`):
/// điểm bắt đầu/kết thúc theo ngày và tháng sớm nhất có bản ghi. Đọc Drift
/// (F22-R7).
final liftChartProvider =
    Provider.family<LiftChartView?, ({String exerciseId, YearMonth month})>((
      ref,
      args,
    ) {
      final logs = ref.watch(allLiftLogsProvider).value;
      final units = ref.watch(exerciseUnitsProvider).value;
      if (logs == null || units == null) return null;
      return (
        chart: MonthlyLiftChart.of(logs, args.exerciseId, args.month),
        earliest: MonthlyLiftChart.earliestMonth(logs, args.exerciseId),
        unitChange: MonthlyLiftChart.unitChange(logs, units[args.exerciseId]),
      );
    });
