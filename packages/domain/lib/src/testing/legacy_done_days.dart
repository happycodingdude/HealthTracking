import '../schedule/month_plan.dart';
import '../schedule/weekly_template.dart';
import '../time/local_date.dart';
import '../time/local_time.dart';

/// Hôm nay của [legacyDoneDays]: 10:00 thứ 6 16/10/2026, ngày đầu mở app Bản 2.
final legacyToday = DateTime(2026, 10, 16, 10);

/// Fixture `legacyDoneDays` (06 Bản 2 §6.9): bản ghi ngày như app Bản 1 đã ghi
/// (đánh dấu tự chọn nhóm cơ thực tế, buổi tập thêm sửa được trong 7 ngày),
/// tất cả còn trong "hạn 7 ngày" của Bản 1 lúc [legacyToday]:
///
/// - `doneOtherMuscles`: thứ 7 10/10, lịch Ngực, Bản 1 ghi "Đã tập" Vai
///   (F05-AC30, F05-R38).
/// - `doneMonday`: thứ 2 12/10 cùng tuần, "Đã tập" (F05-E30).
/// - `extra`: thứ 3 13/10, buổi tập thêm Bụng 3 ngày trước (F05-R36).
/// - `skipped`: thứ 4 14/10, "Không tập" 2 ngày trước (F05-R37).
/// - `doneYesterday`: thứ 5 15/10, "Đã tập" hôm qua (F05-AC29).
abstract final class LegacyDoneDays {
  static final _t1800 = LocalTime(18, 0);

  static final doneOtherMuscles =
      PlanDay(
        date: LocalDate(2026, 10, 10),
        kind: DayKind.workout,
        time: _t1800,
        muscles: const [MuscleGroup.chest],
        source: DaySource.override,
      ).withMark(
        DayMark.done,
        actual: const [MuscleGroup.shoulders],
        markedAt: DateTime(2026, 10, 10, 19),
      );

  static final doneMonday =
      PlanDay(
        date: LocalDate(2026, 10, 12),
        kind: DayKind.workout,
        time: _t1800,
        muscles: const [MuscleGroup.chest, MuscleGroup.triceps],
      ).withMark(
        DayMark.done,
        actual: const [MuscleGroup.chest, MuscleGroup.triceps],
        markedAt: DateTime(2026, 10, 12, 19),
      );

  static final extra = PlanDay(
    date: LocalDate(2026, 10, 13),
    kind: DayKind.rest,
  ).withExtra(const [MuscleGroup.abs], loggedAt: DateTime(2026, 10, 13, 20));

  static final skipped = PlanDay(
    date: LocalDate(2026, 10, 14),
    kind: DayKind.workout,
    time: _t1800,
    muscles: const [MuscleGroup.back],
  ).withMark(DayMark.skipped, markedAt: DateTime(2026, 10, 14, 19));

  static final doneYesterday =
      PlanDay(
        date: LocalDate(2026, 10, 15),
        kind: DayKind.workout,
        time: _t1800,
        muscles: const [MuscleGroup.back],
        source: DaySource.override,
      ).withMark(
        DayMark.done,
        actual: const [MuscleGroup.back],
        markedAt: DateTime(2026, 10, 15, 19),
      );

  static final all = [
    doneOtherMuscles,
    doneMonday,
    extra,
    skipped,
    doneYesterday,
  ];
}
