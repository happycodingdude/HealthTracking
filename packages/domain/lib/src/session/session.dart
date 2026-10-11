import '../schedule/month_plan.dart';
import '../schedule/weekly_template.dart';
import '../time/local_date.dart';
import '../time/week.dart';
import '../time/year_month.dart';

/// Trạng thái của một buổi tập theo lịch (03 Bản 2 §6.1).
enum SessionState {
  /// Chưa đến giờ tập.
  upcoming,

  /// Đã đến giờ tập, Bạn chưa đánh dấu.
  awaitingMark,

  /// Bạn đánh dấu "Đã tập". Chốt khi lưu, không thay đổi nữa (F05-R24).
  done,

  /// Bạn đánh dấu "Không tập".
  skipped,

  /// Hết thứ 7 mà buổi vẫn "Chờ đánh dấu" (F05-R26). Không lưu (AP-2).
  autoSkipped,
}

/// Trạng thái kèm cờ "Đã khóa": buổi "Không tập" / "Không tập (tự động)" quá
/// 7 ngày (F05-R27). Buổi "Đã tập" không bao giờ "Đã khóa": nó đã chốt từ lúc
/// lưu ([SessionLock]), không mang biểu tượng khóa (04 Bản 2 UA2-06).
final class SessionStatus {
  const SessionStatus(this.state, {this.locked = false});

  final SessionState state;
  final bool locked;

  /// Tính là đã tập (03 §6.1, F06-R2).
  bool get counts => state == SessionState.done;

  /// Suy ra trạng thái lúc [now] (giờ trên iPhone). null với ngày nghỉ.
  static SessionStatus? derive(PlanDay day, DateTime now) {
    if (!day.isWorkout) return null;
    final state = switch (day.mark) {
      DayMark.done => SessionState.done,
      DayMark.skipped => SessionState.skipped,
      null when now.isBefore(SessionRules.startsAt(day)) =>
        SessionState.upcoming,
      null when !now.isBefore(ProgressWeek.containing(day.date).endsAt) =>
        SessionState.autoSkipped,
      null => SessionState.awaitingMark,
    };
    final locked =
        (state == SessionState.skipped || state == SessionState.autoSkipped) &&
        SessionRules.isLocked(day.date, now);
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

/// "Đã chốt" (05 Bản 2 AP-8, 06 Bản 2 ED2-03): buổi "Đã tập" và buổi tập thêm
/// đã lưu không đổi trạng thái, nhóm cơ, không xóa được. Không có cờ trong
/// database: suy ra từ bản ghi ngày. App (UI, use case) và server cùng dùng.
abstract final class SessionLock {
  /// Ngày có buổi đã chốt (buổi theo lịch "Đã tập" hoặc buổi tập thêm).
  static bool of(PlanDay day) => session(day) || extra(day);

  /// Buổi theo lịch "Đã tập" (F05-R24, F05-R36).
  static bool session(PlanDay day) => day.mark == DayMark.done;

  /// Buổi tập thêm đã lưu (F05-R34, F05-R36).
  static bool extra(PlanDay day) => day.extraMuscles?.isNotEmpty ?? false;
}

/// Lý do không đánh dấu được (F05-R22 → R27).
enum MarkError {
  /// Ngày nghỉ không có buổi theo lịch.
  notWorkout,

  /// F05-R22: chưa đến giờ tập.
  tooEarly,

  /// F05-R27: buổi "Không tập" quá 7 ngày.
  locked,

  /// F05-R24: buổi đã "Đã tập", đã chốt.
  alreadyDone,

  /// "Không tập" chỉ bấm được khi buổi đang "Chờ đánh dấu".
  notAwaiting,
}

final class MarkException implements Exception {
  const MarkException(this.error);

  final MarkError error;

  @override
  String toString() => 'MarkException(${error.name})';
}

/// Quy tắc đánh dấu buổi tập theo lịch (F-05 Bản 2). App và server cùng dùng
/// (AP-4).
abstract final class SessionRules {
  /// F05-R25: đổi "Không tập" sang "Đã tập" được trong 7 ngày kể từ ngày của
  /// buổi.
  static const editDays = 7;

  /// Giờ bắt đầu buổi tập (giờ trên iPhone).
  static DateTime startsAt(PlanDay day) => day.date.atTime(day.time!);

  /// Ngày cuối còn đổi sang "Đã tập" được: ngày thứ 7 sau ngày của buổi
  /// ("Đổi sang Đã tập được đến hết {dd/mm}").
  static LocalDate lastChangeDate(LocalDate date) => date.addDays(editDays);

  /// Hết ngày thứ 7 sau ngày của buổi, tức 00:00 ngày thứ 8.
  static DateTime lockedFrom(LocalDate date) =>
      lastChangeDate(date).addDays(1).startOfDay;

  static bool isLocked(LocalDate date, DateTime now) =>
      !now.isBefore(lockedFrom(date));

  /// Ghi đánh dấu được về mặt thời gian: ngày tập, từ giờ tập đến hết hạn 7
  /// ngày. Server dùng cho mọi phiên bản app (05 Bản 2 §6.6.3).
  static bool canMark(PlanDay day, DateTime now) =>
      day.isWorkout && !now.isBefore(startsAt(day)) && !isLocked(day.date, now);

  /// "Đã tập": từ "Chờ đánh dấu", hoặc đổi từ "Không tập" / "Không tập (tự
  /// động)" trong 7 ngày (F05-R22, F05-R25, F05-R26). Không bao giờ khi đã
  /// "Đã tập" (F05-R24).
  static MarkError? validateDone(PlanDay day, DateTime now) {
    if (!day.isWorkout) return MarkError.notWorkout;
    if (SessionLock.session(day)) return MarkError.alreadyDone;
    if (now.isBefore(startsAt(day))) return MarkError.tooEarly;
    if (isLocked(day.date, now)) return MarkError.locked;
    return null;
  }

  static bool canMarkDone(PlanDay day, DateTime now) =>
      validateDone(day, now) == null;

  /// "Không tập": chỉ khi buổi đang "Chờ đánh dấu" (bảng 03 Bản 2 §6.1).
  /// Không bao giờ "Đã tập" → "Không tập".
  static MarkError? validateSkipped(PlanDay day, DateTime now) {
    if (!day.isWorkout) return MarkError.notWorkout;
    if (SessionLock.session(day)) return MarkError.alreadyDone;
    if (now.isBefore(startsAt(day))) return MarkError.tooEarly;
    if (SessionStatus.derive(day, now)?.state != SessionState.awaitingMark) {
      return MarkError.notAwaiting;
    }
    return null;
  }

  static bool canMarkSkipped(PlanDay day, DateTime now) =>
      validateSkipped(day, now) == null;

  /// Bản ghi ngày sau khi "Đã tập": nhóm cơ là nhóm cơ của lịch tháng, kể cả
  /// ngày đã sửa riêng (F05-R21, 05 Bản 2 TD2-08). Ném [MarkException].
  static PlanDay markDone(PlanDay day, {required DateTime now}) {
    final error = validateDone(day, now);
    if (error != null) throw MarkException(error);
    return day.withMark(
      DayMark.done,
      actual: MuscleGroup.ordered(day.muscles),
      markedAt: now,
    );
  }

  /// Bản ghi ngày sau khi "Không tập" (F05-R25). Ném [MarkException].
  static PlanDay markSkipped(PlanDay day, {required DateTime now}) {
    final error = validateSkipped(day, now);
    if (error != null) throw MarkException(error);
    return day.withMark(DayMark.skipped, markedAt: now);
  }

  /// Nhóm cơ của buổi theo lịch: nhóm cơ đã ghi lúc "Đã tập" nếu có (buổi
  /// Bản 1 có thể khác lịch, F05-R38), ngược lại nhóm cơ của lịch tháng.
  static List<MuscleGroup> musclesOf(PlanDay day) => day.mark == DayMark.done
      ? (day.actualMuscles ?? day.muscles)
      : day.muscles;

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
