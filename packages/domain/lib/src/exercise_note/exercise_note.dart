import '../lift_log/lift_log.dart';
import '../time/local_date.dart';

/// Ghi chú của một bài trong một buổi (entity `exercise_note`, key
/// `{date}:{exerciseId}`, TD3-06): độc lập với bản ghi mức tạ (FD3-01 = A).
/// Ghi chú trống là xóa (tombstone).
final class ExerciseNote {
  const ExerciseNote({
    required this.date,
    required this.exerciseId,
    required this.text,
  });

  final LocalDate date;
  final String exerciseId;
  final String text;

  /// Cùng dạng key với `lift_log`.
  String get key => keyOf(date, exerciseId);

  static String keyOf(LocalDate date, String exerciseId) =>
      LiftLog.keyOf(date, exerciseId);

  static (LocalDate, String)? parseKey(String key) => LiftLog.parseKey(key);

  @override
  bool operator ==(Object other) =>
      other is ExerciseNote &&
      other.date == date &&
      other.exerciseId == exerciseId &&
      other.text == text;

  @override
  int get hashCode => Object.hash(date, exerciseId, text);

  @override
  String toString() => 'ExerciseNote($key)';
}
