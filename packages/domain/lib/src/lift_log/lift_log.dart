import '../exercise/exercise.dart';
import '../schedule/month_plan.dart';
import '../session/session.dart';
import '../session/session_exercise.dart';
import '../time/local_date.dart';
import 'lift_kg.dart';
import 'lift_window.dart';

/// Một bản ghi mức tạ: một bài trong một buổi (F21-R1, FA2-01, 05 Bản 2
/// TD2-06). Buổi là dòng ngày [date]; mỗi bài tối đa một bản ghi mỗi buổi,
/// ghi lại là ghi đè. Độc lập với trạng thái buổi (AP-9).
final class LiftLog {
  const LiftLog({
    required this.date,
    required this.exerciseId,
    required this.startKgX10,
    required this.endKgX10,
  });

  final LocalDate date;
  final String exerciseId;

  /// Mức tạ bắt đầu, kết thúc × 10, theo [LiftUnit] của bài (kg hoặc nấc).
  final int startKgX10;
  final int endKgX10;

  /// Key đồng bộ `{date}:{exerciseId}` (05 Bản 2 §6.6.2).
  String get key => keyOf(date, exerciseId);

  static String keyOf(LocalDate date, String exerciseId) =>
      '${date.toKey()}:$exerciseId';

  /// Ngược lại của [keyOf]; null khi sai dạng.
  static (LocalDate, String)? parseKey(String key) {
    final i = key.indexOf(':');
    if (i <= 0 || i == key.length - 1) return null;
    final date = LocalDate.tryParse(key.substring(0, i));
    return date == null ? null : (date, key.substring(i + 1));
  }

  /// Trường sai theo khoảng và bước của đơn vị [unit] (F21-V43, V44); null =
  /// hợp lệ.
  String? invalidField(LiftUnit unit) {
    if (LiftKg.validate(startKgX10, unit) != null) return 'startKgX10';
    if (LiftKg.validate(endKgX10, unit) != null) return 'endKgX10';
    return null;
  }

  LiftLog copyWith({int? startKgX10, int? endKgX10}) => LiftLog(
    date: date,
    exerciseId: exerciseId,
    startKgX10: startKgX10 ?? this.startKgX10,
    endKgX10: endKgX10 ?? this.endKgX10,
  );

  @override
  bool operator ==(Object other) =>
      other is LiftLog &&
      other.date == date &&
      other.exerciseId == exerciseId &&
      other.startKgX10 == startKgX10 &&
      other.endKgX10 == endKgX10;

  @override
  int get hashCode => Object.hash(date, exerciseId, startKgX10, endKgX10);

  @override
  String toString() =>
      'LiftLog($key, ${LiftKg.format(startKgX10)} → '
      '${LiftKg.format(endKgX10)})';
}

/// Lý do không ghi được mức tạ, theo thứ tự kiểm tra của server (05 Bản 2
/// §6.6.2). Mỗi lý do ứng với một mã lỗi đồng bộ.
enum LiftError {
  /// Ngày không phải buổi tập → `lift_no_session`.
  noSession,

  /// Ngoài cửa sổ ghi tạ (chưa đến giờ, đã qua 00:00, buổi tập thêm cho
  /// ngày đã qua) → `lift_window_closed`.
  windowClosed,

  /// Bài không có, bài bụng, hoặc tạo mới cho bài đã rời thư viện →
  /// `lift_not_allowed_for_exercise`.
  notAllowedForExercise,

  /// Bài không thuộc nhóm cơ của buổi → `lift_exercise_not_in_session`.
  exerciseNotInSession,
}

final class LiftException implements Exception {
  const LiftException(this.error);

  final LiftError error;

  @override
  String toString() => 'LiftException(${error.name})';
}

/// Cảnh báo mức tạ kết thúc so với buổi trước (F21-R8). Chỉ cảnh báo, không
/// chặn; mức tạ bắt đầu không có cảnh báo.
enum EndWarningKind {
  /// Thấp hơn buổi trước (bất kỳ mức nào).
  lower,

  /// Cao hơn buổi trước quá 10 kg; nấc máy: quá 4 nấc ([LiftUnit.maxRise],
  /// F21-R45).
  muchHigher,
}

final class EndWarning {
  const EndWarning(this.kind, this.diffX10);

  final EndWarningKind kind;

  /// Chênh lệch × 10 theo đơn vị của bài, hiển thị bằng [LiftKg.format].
  final int diffX10;

  /// null khi chưa có buổi trước ([previousEndX10] null, F21-AC6), bằng,
  /// hoặc cao hơn không quá [LiftUnit.maxRise] (10 kg; 4 nấc). [edited] =
  /// false (Lưu với số điền sẵn không sửa) → không cảnh báo (FA3-07, ED3-12).
  static EndWarning? of(
    int? previousEndX10,
    int endX10,
    LiftUnit unit, {
    bool edited = true,
  }) {
    if (previousEndX10 == null || !edited) return null;
    final diff = endX10 - previousEndX10;
    if (diff < 0) return EndWarning(EndWarningKind.lower, -diff);
    if (diff > unit.maxRise) {
      return EndWarning(EndWarningKind.muchHigher, diff);
    }
    return null;
  }

  @override
  bool operator ==(Object other) =>
      other is EndWarning && other.kind == kind && other.diffX10 == diffX10;

  @override
  int get hashCode => Object.hash(kind, diffX10);

  @override
  String toString() => 'EndWarning(${kind.name}, $diffX10)';
}

/// Quy tắc ghi mức tạ (F-21). App và server cùng dùng (AP-4, AP-10).
abstract final class LiftLogRules {
  /// Có phải buổi tập: ngày tập có giờ, hoặc ngày có buổi tập thêm.
  static bool isSession(PlanDay? day) =>
      day != null && (day.isWorkout || SessionLock.extra(day));

  /// Kiểm tra ghi (thêm, sửa, xóa) mức tạ của [exercise] trong buổi [day]
  /// lúc [now] (giờ trên iPhone), theo thứ tự 05 Bản 2 §6.6.2 bước 1 → 4.
  /// [exists] = buổi đã có bản ghi của bài này (sửa, xóa): bài đã rời thư
  /// viện vẫn sửa, xóa được (F21-E7).
  ///
  /// Bước 4 (bài thuộc buổi) theo danh sách bài của buổi (05 Bản 5 TD5-09):
  /// [sessionRows] = các dòng `session_exercise` còn hiệu lực của ngày (bài
  /// thay / thêm / bỏ qua). [removing] = xóa bản ghi (tombstone): không xét
  /// bước 4 — xóa bản ghi của bài vừa bị đổi / bỏ qua / xóa khỏi buổi luôn
  /// được, dù outbox gửi dòng `session_exercise` trước (FC5-14, TD5-10).
  static LiftError? check({
    required PlanDay? day,
    required Exercise? exercise,
    required DateTime now,
    bool exists = false,
    Iterable<SessionExerciseRow> sessionRows = const [],
    bool removing = false,
  }) {
    if (!isSession(day)) return LiftError.noSession;
    if (!LiftWindow.of(day, now).isOpen) return LiftError.windowClosed;
    if (exercise == null ||
        !exercise.logsWeight ||
        (!exists && !exercise.active)) {
      return LiftError.notAllowedForExercise;
    }
    if (!removing && !inSession(day!, exercise, sessionRows)) {
      return LiftError.exerciseNotInSession;
    }
    return null;
  }

  /// Bài [exercise] thuộc buổi [day] (TD5-09): buổi theo lịch xét cả các
  /// dòng [sessionRows]; buổi tập thêm chỉ xét nhóm cơ (F28-R9).
  static bool inSession(
    PlanDay day,
    Exercise exercise,
    Iterable<SessionExerciseRow> sessionRows,
  ) => SessionExerciseRules.inSession(
    exercise: exercise,
    groups: day.sessionMuscles,
    rows: day.isWorkout ? sessionRows : const [],
  );

  static bool canLog({
    required PlanDay? day,
    required Exercise? exercise,
    required DateTime now,
    bool exists = false,
    Iterable<SessionExerciseRow> sessionRows = const [],
  }) =>
      check(
        day: day,
        exercise: exercise,
        now: now,
        exists: exists,
        sessionRows: sessionRows,
      ) ==
      null;

  /// Buổi trước của bài (FR2-06, F21-E5): bản ghi gần nhất của [exerciseId]
  /// có ngày trước [date], bất kể trạng thái buổi đó.
  static LiftLog? previousSession(
    Iterable<LiftLog> logs,
    String exerciseId,
    LocalDate date,
  ) {
    LiftLog? best;
    for (final l in logs) {
      if (l.exerciseId != exerciseId || !l.date.isBefore(date)) continue;
      if (best == null || l.date.isAfter(best.date)) best = l;
    }
    return best;
  }
}
