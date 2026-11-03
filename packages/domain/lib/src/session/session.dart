import '../day_lock.dart';
import '../schedule/month_plan.dart';
import '../schedule/weekly_template.dart';
import '../time/local_date.dart';
import '../time/year_month.dart';

/// Trạng thái của một buổi tập theo lịch (03 Bản 2 §6.1; 03 Bản 5 §6.8).
enum SessionState {
  /// Chưa đến giờ tập (và chưa tới phòng gym, FD5-01).
  upcoming,

  /// Đã đến giờ tập (hoặc đã tới gym), Bạn chưa đánh dấu.
  awaitingMark,

  /// Bạn đánh dấu "Đã tập". Bản 5: đổi lại được đến hết ngày (F05-R61).
  done,

  /// Bạn đánh dấu "Không tập".
  skipped,

  /// Hết ngày (00:00 ngày sau) mà buổi vẫn "Chờ đánh dấu" (F05-R63, thay
  /// "cuối thứ 7" của Bản 2). App suy ra khi đọc; server ghi `skipped_auto`
  /// (`DayCloser`, TA5-05) — hai cách cho cùng kết quả.
  autoSkipped,
}

/// Trạng thái kèm cờ "Đã khóa": ngày đã qua (hết ngày, FC5-01) — mọi trạng
/// thái khóa vĩnh viễn (F05-R63). Bản 5 không còn hạn 7 ngày; giao diện
/// không vẽ ổ khóa cho ngày đã qua (UR5-05), cờ chỉ để chặn thao tác.
final class SessionStatus {
  const SessionStatus(this.state, {this.locked = false});

  final SessionState state;
  final bool locked;

  /// Tính là đã tập (03 §6.1, F06-R2).
  bool get counts => state == SessionState.done;

  /// Suy ra trạng thái lúc [now] (giờ trên iPhone). null với ngày nghỉ.
  /// Đây là `DayState.effective` của 06 Bản 5 VS52-T02: ngày đã qua chưa
  /// đánh dấu → [SessionState.autoSkipped] ngay, không chờ cuối tuần (TA5-05).
  static SessionStatus? derive(PlanDay day, DateTime now) {
    if (!day.isWorkout) return null;
    final open = DayLock.isOpen(day.date, now);
    final state = switch (day.mark) {
      DayMark.done => SessionState.done,
      DayMark.skipped => SessionState.skipped,
      null when !open => SessionState.autoSkipped,
      null when now.isBefore(SessionRules.opensAt(day)) =>
        SessionState.upcoming,
      null => SessionState.awaitingMark,
    };
    return SessionStatus(state, locked: !open);
  }

  @override
  bool operator ==(Object other) =>
      other is SessionStatus && other.state == state && other.locked == locked;

  @override
  int get hashCode => Object.hash(state, locked);

  @override
  String toString() => 'SessionStatus(${state.name}${locked ? ', khóa' : ''})';
}

/// Dấu hiệu của một bản ghi ngày (05 Bản 2 AP-8). Bản 5 bỏ "đã chốt khi lưu"
/// (CR5-06, CR5-07): buổi "Đã tập" và buổi tập thêm sửa được đến hết ngày
/// ([DayLock]). Không có cờ trong database: suy ra từ bản ghi ngày.
abstract final class SessionLock {
  /// Ngày có buổi "Đã tập" hoặc buổi tập thêm.
  static bool of(PlanDay day) => session(day) || extra(day);

  /// Buổi theo lịch đang "Đã tập": không đổi / bỏ qua / thêm bài (BR5-13).
  static bool session(PlanDay day) => day.mark == DayMark.done;

  /// Ngày nghỉ đã có buổi tập thêm.
  static bool extra(PlanDay day) => day.extraMuscles?.isNotEmpty ?? false;
}

/// Lý do không đánh dấu được (F05-R22, F05-R61 → R63).
enum MarkError {
  /// Ngày nghỉ không có buổi theo lịch.
  notWorkout,

  /// F05-R22, FC5-02: chưa đến giờ tập (và chưa tới gym) — chỉ với "Đã tập".
  tooEarly,

  /// F05-R63: ngày đã qua (hết ngày), khóa vĩnh viễn.
  locked,

  /// Buổi đã "Đã tập".
  alreadyDone,

  /// Buổi đã "Không tập".
  alreadySkipped,

  /// Bỏ đánh dấu khi buổi chưa đánh dấu.
  notMarked,
}

final class MarkException implements Exception {
  const MarkException(this.error);

  final MarkError error;

  @override
  String toString() => 'MarkException(${error.name})';
}

/// Quy tắc đánh dấu buổi tập theo lịch (F-05 Bản 2, Bản 5). App và server
/// cùng dùng (AP-4). Bản 5 (F05-R61 → R63, FC5-02, FC5-13): "Đã tập" từ giờ
/// tập (hoặc lúc tới gym), "Không tập" từ đầu ngày, đổi qua lại và bỏ đánh
/// dấu được đến hết ngày; sang ngày khóa.
abstract final class SessionRules {
  /// Giờ bắt đầu buổi tập theo lịch (giờ trên iPhone).
  static DateTime startsAt(PlanDay day) => day.date.atTime(day.time!);

  /// Giờ mở buổi (FD5-01 = A, TD5-07): giờ tập, hoặc lúc tới phòng gym nếu
  /// sớm hơn. [PlanDay.openedAt] là thời điểm tuyệt đối: app đổi sang giờ
  /// máy; server quy về múi giờ hồ sơ trước khi gọi (giờ đồng hồ, không UTC).
  static DateTime opensAt(PlanDay day) {
    final start = startsAt(day);
    final at = day.openedAt;
    if (at == null) return start;
    final opened = at.isUtc ? at.toLocal() : at;
    return opened.isBefore(start) ? opened : start;
  }

  /// Ngày đã khóa lúc [now] (hết ngày, FC5-01).
  static bool isLocked(LocalDate date, DateTime now) =>
      !DayLock.isOpen(date, now);

  /// "Đã tập" (F05-R22, F05-R61, FC5-02): ngày tập, từ giờ mở buổi đến hết
  /// ngày, chưa "Đã tập". Đổi từ "Không tập" được trong ngày.
  static MarkError? validateDone(PlanDay day, DateTime now) {
    if (!day.isWorkout) return MarkError.notWorkout;
    if (isLocked(day.date, now)) return MarkError.locked;
    if (day.mark == DayMark.done) return MarkError.alreadyDone;
    if (now.isBefore(opensAt(day))) return MarkError.tooEarly;
    return null;
  }

  static bool canMarkDone(PlanDay day, DateTime now) =>
      validateDone(day, now) == null;

  /// "Không tập" (F05-R62, FC5-02): ngày tập, từ đầu ngày đến hết ngày, kể cả
  /// đổi từ "Đã tập" (D5-02 = B).
  static MarkError? validateSkipped(PlanDay day, DateTime now) {
    if (!day.isWorkout) return MarkError.notWorkout;
    if (isLocked(day.date, now)) return MarkError.locked;
    if (day.mark == DayMark.skipped) return MarkError.alreadySkipped;
    return null;
  }

  static bool canMarkSkipped(PlanDay day, DateTime now) =>
      validateSkipped(day, now) == null;

  /// Bỏ đánh dấu (FC5-13): buổi về "Chờ đánh dấu", đến hết ngày.
  static MarkError? validateUnmark(PlanDay day, DateTime now) {
    if (!day.isWorkout) return MarkError.notWorkout;
    if (isLocked(day.date, now)) return MarkError.locked;
    if (day.mark == null) return MarkError.notMarked;
    return null;
  }

  static bool canUnmark(PlanDay day, DateTime now) =>
      validateUnmark(day, now) == null;

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

  /// Bản ghi ngày sau khi "Không tập" (F05-R62). Ném [MarkException].
  static PlanDay markSkipped(PlanDay day, {required DateTime now}) {
    final error = validateSkipped(day, now);
    if (error != null) throw MarkException(error);
    return day.withMark(DayMark.skipped, markedAt: now);
  }

  /// Bản ghi ngày sau khi bỏ đánh dấu (FC5-13): về "Chờ đánh dấu"; mức tạ,
  /// ghi chú, bài trong buổi giữ nguyên (A5-12). Ném [MarkException].
  static PlanDay unmark(PlanDay day, {required DateTime now}) {
    final error = validateUnmark(day, now);
    if (error != null) throw MarkException(error);
    return day.withMark(null);
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
