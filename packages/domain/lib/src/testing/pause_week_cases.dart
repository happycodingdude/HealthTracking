import '../pause/schedule_pause.dart';
import '../schedule/month_plan.dart';
import '../schedule/weekly_template.dart';
import '../time/local_date.dart';
import '../time/local_time.dart';
import '../time/week.dart';
import '../time/year_month.dart';

/// Bộ tuần tạm dừng dùng chung (06 Bản 5 §6.10.2 `pauseWeekCases`): tuần
/// 02/11 → 07/11/2026, 5 buổi theo lịch (T2 Ngực, T3 Ngực, T4 Lưng, T6 Vai,
/// T7 Chân; T5 nghỉ), đã tập T2, T3; tạm dừng T4 → CN 08/11. Lúc [now] (thứ 5
/// 05/11 09:40) tiến độ "2 / 2" (F06-AC61, F31-E1).
abstract final class PauseWeekCases {
  static final week = ProgressWeek.containing(LocalDate(2026, 11, 2));
  static final month = YearMonth(2026, 11);
  static final now = DateTime(2026, 11, 5, 9, 40);
  static final pauseStart = LocalDate(2026, 11, 4);
  static final pauseEnd = LocalDate(2026, 11, 8);

  static PlanDay _workout(int day, MuscleGroup m, {DayMark? mark}) => PlanDay(
    date: LocalDate(2026, 11, day),
    kind: DayKind.workout,
    time: LocalTime(18, 0),
    muscles: [m],
    mark: mark,
    actualMuscles: mark == DayMark.done ? [m] : null,
    markedAt: mark == null ? null : DateTime(2026, 11, day, 19),
  );

  /// Bản ghi ngày thứ 2 → thứ 7 của tuần; [marks] đè đánh dấu theo ngày.
  static List<PlanDay> days({Map<int, DayMark> marks = const {}}) => [
    _workout(2, MuscleGroup.chest, mark: marks[2] ?? DayMark.done),
    _workout(3, MuscleGroup.chest, mark: marks[3] ?? DayMark.done),
    _workout(4, MuscleGroup.back, mark: marks[4]),
    PlanDay(date: LocalDate(2026, 11, 5), kind: DayKind.rest),
    _workout(6, MuscleGroup.shoulders, mark: marks[6]),
    _workout(7, MuscleGroup.legs, mark: marks[7]),
  ];

  /// Khoảng T4 → CN (đã qua ngày A khi [now]).
  static final pause = SchedulePause(
    id: '6f1d2c3b-0000-4000-8000-000000000056',
    startDate: pauseStart,
    endDate: pauseEnd,
  );

  /// Cả tuần tạm dừng (F31-E2, F06-R62).
  static final wholeWeek = SchedulePause(
    id: '6f1d2c3b-0000-4000-8000-000000000057',
    startDate: LocalDate(2026, 11, 2),
    endDate: pauseEnd,
  );
}
