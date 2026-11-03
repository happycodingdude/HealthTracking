import '../schedule/month_plan.dart';
import '../schedule/weekly_template.dart';
import '../time/local_date.dart';
import '../time/local_time.dart';

/// Bộ mốc thời gian chung cho test cửa sổ Bản 5 (06 Bản 5 IA5-08, §6.10.2
/// `clockV5`): lịch Lưng thứ 4 04/11/2026 18:00; tới gym 17:20; múi giờ
/// Asia/Ho_Chi_Minh. App, server, domain dùng cùng một bộ.
abstract final class ClockV5 {
  static const timezone = 'Asia/Ho_Chi_Minh';

  /// Thứ 4 04/11/2026.
  static final wed = LocalDate(2026, 11, 4);
  static final time = LocalTime(18, 0);

  /// Buổi Lưng 18:00 ngày [wed].
  static final backDay = PlanDay(
    date: wed,
    kind: DayKind.workout,
    time: time,
    muscles: const [MuscleGroup.back],
  );

  static final gymArrival = DateTime(2026, 11, 4, 17, 20);
  static final start = DateTime(2026, 11, 4, 18);
  static final t1805 = DateTime(2026, 11, 4, 18, 5);
  static final t1900 = DateTime(2026, 11, 4, 19);
  static final t2359 = DateTime(2026, 11, 4, 23, 59);
  static final midnight = DateTime(2026, 11, 5);
  static final t0001 = DateTime(2026, 11, 5, 0, 1);
  static final t0030 = DateTime(2026, 11, 5, 0, 30);
}
