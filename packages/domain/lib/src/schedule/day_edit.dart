import '../session/session.dart';
import '../time/local_date.dart';
import '../time/local_time.dart';
import 'month_plan.dart';
import 'weekly_template.dart';

/// Tình huống của một ngày ở S-21 (04 S-21, bảng 8 tình huống).
enum DaySituation {
  /// Ngày tập, từ hôm nay trở đi trong tháng, chưa đến giờ, chưa đánh dấu:
  /// đổi giờ, đổi nhóm cơ, cho nghỉ, trả về theo lịch tuần (nếu đã sửa riêng).
  editableWorkout,

  /// Ngày nghỉ thứ 2 → thứ 7, từ ngày mai trở đi trong tháng: lên lịch tập,
  /// trả về theo lịch tuần (nếu đã sửa riêng).
  futureRest,

  /// Hôm nay là ngày nghỉ, chưa có buổi tập thêm: lên lịch tập hôm nay, ghi
  /// buổi tập thêm.
  todayRest,

  /// Hôm nay đã có buổi tập thêm: sửa buổi tập thêm (F03-E4).
  todayExtra,

  /// Ngày tập đã đến giờ hoặc đã qua, trong 7 ngày: đánh dấu (S-23).
  markable,

  /// Ngày nghỉ đã qua, trong 7 ngày: thêm, sửa, xóa buổi tập thêm (S-24).
  pastRest,

  /// Quá 7 ngày: chỉ xem (F05-E3).
  locked,

  /// Chủ nhật: chỉ xem.
  sunday,
}

/// Lý do không sửa riêng được (F03-R9, F03-V4, F03-E4).
enum OverrideError {
  /// F03-R9, F03-R11, F03-E6: ngày đã qua, chủ nhật, ngày ngoài tháng hiện
  /// tại, hoặc buổi hôm nay đã đến giờ hay đã đánh dấu.
  notEditable,

  /// F03-E4: hôm nay đã có buổi tập thêm nên không thành ngày tập được.
  hasExtra,

  /// F03-V4: ngày tập phải có giờ tập và ít nhất 1 nhóm cơ.
  missingTimeOrMuscles,
}

final class OverrideException implements Exception {
  const OverrideException(this.error);

  final OverrideError error;

  @override
  String toString() => 'OverrideException(${error.name})';
}

/// Sửa riêng một ngày, trả về theo lịch tuần (F03-R9 → R11, F03-E4, E6).
abstract final class OverrideRules {
  /// Tình huống của ngày [date] ([day] null = không có bản ghi, ví dụ chủ
  /// nhật) lúc [now].
  static DaySituation situation(LocalDate date, PlanDay? day, DateTime now) {
    final today = LocalDate.fromDateTime(now);
    if (date.isSunday || day == null) return DaySituation.sunday;
    if (canEdit(day, now)) {
      if (day.isWorkout) return DaySituation.editableWorkout;
      if (date != today) return DaySituation.futureRest;
      return day.extraMuscles == null
          ? DaySituation.todayRest
          : DaySituation.todayExtra;
    }
    if (SessionRules.isLocked(date, now)) return DaySituation.locked;
    // Ngày nghỉ hôm nay luôn sửa riêng được nên ở đây là ngày nghỉ đã qua.
    return day.isWorkout ? DaySituation.markable : DaySituation.pastRest;
  }

  /// F03-R9, F03-R11, F03-E6: sửa riêng được (đổi giờ, nhóm cơ, cho nghỉ,
  /// lên lịch, trả về) — từ hôm nay đến cuối tháng hiện tại, không chủ nhật;
  /// với hôm nay chỉ khi buổi chưa đến giờ và chưa được đánh dấu.
  static bool canEdit(PlanDay day, DateTime now) {
    final today = LocalDate.fromDateTime(now);
    if (day.date.isSunday || day.date < today) return false;
    if (day.date.yearMonth != today.yearMonth) return false;
    if (day.date == today) {
      if (day.mark != null) return false;
      if (day.isWorkout && !now.isBefore(SessionRules.startsAt(day))) {
        return false;
      }
    }
    return true;
  }

  /// Kiểm tra đổi lịch của ngày [before] thành [after] lúc [now].
  static OverrideError? validate(PlanDay before, PlanDay after, DateTime now) {
    if (!canEdit(before, now)) return OverrideError.notEditable;
    if (after.isWorkout) {
      if (before.extraMuscles != null) return OverrideError.hasExtra;
      if (after.time == null || after.muscles.isEmpty) {
        return OverrideError.missingTimeOrMuscles;
      }
    }
    return null;
  }

  /// Ngày [day] sau khi sửa riêng thành ngày tập ([time], [muscles]) hoặc
  /// ngày nghỉ ([time] null). Nhãn "Đã sửa riêng". Ném [OverrideException].
  static PlanDay override(
    PlanDay day, {
    LocalTime? time,
    List<MuscleGroup> muscles = const [],
    required DateTime now,
  }) {
    final after = time == null
        ? PlanDay(
            date: day.date,
            kind: DayKind.rest,
            source: DaySource.override,
            extraMuscles: day.extraMuscles,
            extraLoggedAt: day.extraLoggedAt,
          )
        : PlanDay(
            date: day.date,
            kind: DayKind.workout,
            time: time,
            muscles: MuscleGroup.ordered(muscles),
            source: DaySource.override,
          );
    final error = validate(day, after, now);
    if (error != null) throw OverrideException(error);
    return after;
  }

  /// F03-R10: lấy lại thông tin theo lịch tuần [template], bỏ nhãn "Đã sửa
  /// riêng". Ném [OverrideException].
  static PlanDay revert(
    PlanDay day,
    WeeklyTemplate template, {
    required DateTime now,
  }) {
    final t = PlanDay.fromTemplate(day.date, template.day(day.date.weekday));
    final after = t.isWorkout
        ? t
        : t.withExtra(day.extraMuscles, loggedAt: day.extraLoggedAt);
    final error = validate(day, after, now);
    if (error != null) throw OverrideException(error);
    return after;
  }
}

/// Kết quả chia lại (F03-R8).
typedef Redistribution = ({
  /// Các ngày đổi theo lịch tuần mới.
  List<PlanDay> changed,

  /// Số ngày đã sửa riêng được giữ nguyên.
  int keptOverrides,

  /// Khoảng ngày áp dụng: hôm nay → cuối tháng.
  LocalDate from,
  LocalDate to,
});

/// Chia lại lịch tháng hiện tại theo lịch tuần mới (F03-R8, F03-E1).
abstract final class Redistributor {
  /// [days] là các ngày của tháng hiện tại. Chỉ đổi các ngày từ hôm nay đến
  /// cuối tháng; giữ nguyên ngày đã qua, buổi hôm nay đã đến giờ hoặc đã đánh
  /// dấu, ngày đã sửa riêng, và hôm nay khi đã có buổi tập thêm mà lịch mới
  /// là ngày tập (F03-E4). Buổi hôm nay theo lịch mới mà giờ đã qua thì hôm
  /// nay là ngày nghỉ (giống F03-R5).
  static Redistribution apply({
    required List<PlanDay> days,
    required WeeklyTemplate template,
    required DateTime now,
  }) {
    final today = LocalDate.fromDateTime(now);
    final changed = <PlanDay>[];
    var kept = 0;
    for (final d in days) {
      if (d.date < today || d.date.yearMonth != today.yearMonth) continue;
      if (d.source == DaySource.override) {
        kept++;
        continue;
      }
      if (!OverrideRules.canEdit(d, now)) continue;
      var next = PlanDay.fromTemplate(d.date, template.day(d.date.weekday));
      if (next.isWorkout &&
          d.date == today &&
          !now.isBefore(SessionRules.startsAt(next))) {
        next = PlanDay(date: d.date, kind: DayKind.rest);
      }
      if (next.isWorkout && d.extraMuscles != null) continue;
      if (!next.isWorkout) {
        next = next.withExtra(d.extraMuscles, loggedAt: d.extraLoggedAt);
      }
      if (next != d) changed.add(next);
    }
    return (
      changed: changed,
      keptOverrides: kept,
      from: today,
      to: today.yearMonth.lastDay,
    );
  }
}
