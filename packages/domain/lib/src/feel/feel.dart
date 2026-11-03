import '../exercise/exercise.dart';
import '../exercise_note/exercise_note.dart';
import '../lift_log/lift_log.dart';
import '../schedule/month_plan.dart';
import '../session/session_exercise.dart';
import '../time/local_date.dart';

/// Mức thoải mái của set cuối, ở mức tạ kết thúc (03 Bản 5 §6.1, F-33):
/// Thoải mái / Vừa / Mệt. App chỉ lưu và hiện lại, không diễn giải, không gợi
/// ý (F33-R2, C5-06).
enum Feel {
  easy('easy'),
  medium('medium'),
  hard('hard');

  const Feel(this.wire);

  /// Giá trị trong API và database (05 Bản 5 TD5-04).
  final String wire;

  static Feel? tryParse(String? wire) {
    for (final f in values) {
      if (f.wire == wire) return f;
    }
    return null;
  }
}

/// Mức thoải mái của một bài trong một buổi (entity `exercise_feel`, key
/// `{date}:{exerciseId}`, 05 Bản 5 TD5-04): độc lập với mức tạ và ghi chú
/// (F33-R3). Bỏ chọn = tombstone.
final class ExerciseFeel {
  const ExerciseFeel({
    required this.date,
    required this.exerciseId,
    required this.feel,
  });

  final LocalDate date;
  final String exerciseId;
  final Feel feel;

  String get key => keyOf(date, exerciseId);

  /// Cùng dạng key với `lift_log`.
  static String keyOf(LocalDate date, String exerciseId) =>
      LiftLog.keyOf(date, exerciseId);

  static (LocalDate, String)? parseKey(String key) => LiftLog.parseKey(key);

  @override
  bool operator ==(Object other) =>
      other is ExerciseFeel &&
      other.date == date &&
      other.exerciseId == exerciseId &&
      other.feel == feel;

  @override
  int get hashCode => Object.hash(date, exerciseId, feel);

  @override
  String toString() => 'ExerciseFeel($key, ${feel.wire})';
}

/// Quy tắc mức thoải mái (F-33, 05 Bản 5 §6.6.2). App và server cùng dùng
/// (AP-10).
abstract final class FeelRules {
  /// Bước kiểm tra như ghi chú (F33-R3, R4; 05 Bản 5 §6.6.2): buổi, cửa sổ
  /// ghi tạ ([LiftWindow], gồm mở sớm khi tới gym — FD5-01), bài, bài thuộc
  /// buổi theo TD5-09. Không xét `logsWeight` (bài bụng chọn được, FC5-05).
  /// [removing] = bỏ chọn: không xét bài thuộc buổi (TD5-10).
  static LiftError? check({
    required PlanDay? day,
    required Exercise? exercise,
    required DateTime now,
    bool exists = false,
    Iterable<SessionExerciseRow> sessionRows = const [],
    bool removing = false,
  }) => ExerciseNoteRules.check(
    day: day,
    exercise: exercise,
    now: now,
    exists: exists,
    sessionRows: sessionRows,
    removing: removing,
  );

  /// Mức thoải mái buổi trước (FC5-07, F33-R5): bài có ghi mức tạ → mức
  /// thoải mái của đúng "buổi trước" theo mức tạ (FA3-01, buổi gần nhất có
  /// bản ghi mức tạ trước [date]), có thể không có (F33-E2: không lấy buổi
  /// xa hơn); bài bụng → mức thoải mái gần nhất trước [date]. Cùng cách lấy
  /// với ghi chú mờ ([ExerciseNoteRules.previous]).
  static ExerciseFeel? previous({
    required Iterable<ExerciseFeel> feels,
    required Iterable<LiftLog> logs,
    required Exercise exercise,
    required LocalDate date,
  }) {
    if (exercise.logsWeight) {
      final previous = LiftLogRules.previousSession(logs, exercise.id, date);
      if (previous == null) return null;
      for (final f in feels) {
        if (f.exerciseId == exercise.id && f.date == previous.date) return f;
      }
      return null;
    }
    ExerciseFeel? best;
    for (final f in feels) {
      if (f.exerciseId != exercise.id || !f.date.isBefore(date)) continue;
      if (best == null || f.date.isAfter(best.date)) best = f;
    }
    return best;
  }
}
