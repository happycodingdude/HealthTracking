import '../schedule/month_plan.dart';
import '../schedule/weekly_template.dart';
import '../time/local_date.dart';
import '../time/week.dart';
import '../time/year_month.dart';

/// Trạng thái của một buổi tập theo lịch (03 §6.1).
enum SessionState {
  /// Chưa đến giờ tập.
  upcoming,

  /// Đã đến giờ tập, Bạn chưa đánh dấu.
  awaitingMark,

  /// Bạn đánh dấu "Đã tập".
  done,

  /// Bạn đánh dấu "Không tập".
  skipped,

  /// Hết thứ 7 mà buổi vẫn "Chờ đánh dấu" (F05-R3). Không lưu (AP-2).
  autoSkipped,
}

/// Trạng thái kèm cờ "Đã khóa": quá 7 ngày, trạng thái cuối được giữ nguyên.
final class SessionStatus {
  const SessionStatus(this.state, {this.locked = false});

  final SessionState state;
  final bool locked;

  /// Tính là đã tập (03 §6.1, F06-R2).
  bool get counts => state == SessionState.done;

  /// Suy ra trạng thái lúc [now] (giờ trên iPhone). null với ngày nghỉ.
  static SessionStatus? derive(PlanDay day, DateTime now) {
    if (!day.isWorkout) return null;
    final locked = SessionRules.isLocked(day.date, now);
    final state = switch (day.mark) {
      DayMark.done => SessionState.done,
      DayMark.skipped => SessionState.skipped,
      null when now.isBefore(SessionRules.startsAt(day)) =>
        SessionState.upcoming,
      null when !now.isBefore(ProgressWeek.containing(day.date).endsAt) =>
        SessionState.autoSkipped,
      null => SessionState.awaitingMark,
    };
    return SessionStatus(state, locked: locked);
  }

  @override
  bool operator ==(Object other) =>
      other is SessionStatus && other.state == state && other.locked == locked;

  @override
  int get hashCode => Object.hash(state, locked);

  @override
  String toString() => 'SessionStatus(${state.name}${locked ? ', khóa' : ''})';
}

/// Lý do không đánh dấu được (F05-R1, F05-R2, F05-V1).
enum MarkError {
  /// Ngày nghỉ không có buổi theo lịch.
  notWorkout,

  /// F05-R1, F05-E1: chưa đến giờ tập.
  tooEarly,

  /// F05-R2, F05-E3: quá 7 ngày.
  locked,

  /// F05-V1: "Đã tập" chưa có nhóm cơ.
  noMuscles,
}

final class MarkException implements Exception {
  const MarkException(this.error);

  final MarkError error;

  @override
  String toString() => 'MarkException(${error.name})';
}

/// Quy tắc đánh dấu buổi tập theo lịch (F-05). App và server cùng dùng (AP-4).
abstract final class SessionRules {
  /// F05-R2: sửa được trong 7 ngày kể từ ngày của buổi tập.
  static const editDays = 7;

  /// Giờ bắt đầu buổi tập (giờ trên iPhone).
  static DateTime startsAt(PlanDay day) => day.date.atTime(day.time!);

  /// F05-R2: hết ngày thứ 7 sau ngày của buổi, tức 00:00 ngày thứ 8.
  static DateTime lockedFrom(LocalDate date) =>
      date.addDays(editDays + 1).startOfDay;

  static bool isLocked(LocalDate date, DateTime now) =>
      !now.isBefore(lockedFrom(date));

  /// F05-R1, F05-R2: từ giờ tập đến hết hạn sửa.
  static bool canMark(PlanDay day, DateTime now) =>
      day.isWorkout && !now.isBefore(startsAt(day)) && !isLocked(day.date, now);

  /// Kiểm tra đánh dấu [mark] (null = bỏ đánh dấu, "Hoàn tác") lúc [now].
  static MarkError? validateMark(
    PlanDay day,
    DayMark? mark,
    List<MuscleGroup>? actual,
    DateTime now,
  ) {
    if (!day.isWorkout) return MarkError.notWorkout;
    if (now.isBefore(startsAt(day))) return MarkError.tooEarly;
    if (isLocked(day.date, now)) return MarkError.locked;
    if (mark == DayMark.done && (actual == null || actual.isEmpty)) {
      return MarkError.noMuscles;
    }
    return null;
  }

  /// Bản ghi ngày sau khi đánh dấu. Nhóm cơ thực tế chỉ có khi "Đã tập"
  /// (F05-R4, F05-R5). Ném [MarkException] khi vi phạm [validateMark].
  static PlanDay mark(
    PlanDay day,
    DayMark? mark, {
    List<MuscleGroup>? actual,
    required DateTime now,
  }) {
    final error = validateMark(day, mark, actual, now);
    if (error != null) throw MarkException(error);
    return day.withMark(
      mark,
      actual: mark == DayMark.done ? MuscleGroup.ordered(actual!) : null,
      markedAt: mark == null ? null : now,
    );
  }

  /// Buổi theo lịch gần nhất sau ngày [after] (dòng "Buổi tới" ở S-10).
  ///
  /// [days] là các ngày đã có trong lịch tháng của các tháng [planned]; tháng
  /// chưa có lịch thì suy ra từ [template] (đúng với những gì F03-R6 sẽ tạo).
  static PlanDay? nextSession({
    required LocalDate after,
    required List<PlanDay> days,
    required Set<YearMonth> planned,
    required WeeklyTemplate? template,
  }) {
    final byDate = {for (final d in days) d.date: d};
    for (var i = 1; i <= 62; i++) {
      final date = after.addDays(i);
      if (date.isSunday) continue;
      if (planned.contains(date.yearMonth)) {
        final d = byDate[date];
        if (d != null && d.isWorkout) return d;
      } else if (template != null) {
        final d = PlanDay.fromTemplate(date, template.day(date.weekday));
        if (d.isWorkout) return d;
      }
    }
    return null;
  }
}
