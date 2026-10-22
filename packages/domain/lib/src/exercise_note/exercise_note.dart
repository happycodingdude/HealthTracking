import 'package:characters/characters.dart';

import '../exercise/exercise.dart';
import '../lift_log/lift_log.dart';
import '../lift_log/lift_window.dart';
import '../schedule/month_plan.dart';
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

/// Quy tắc ghi chú bài theo buổi (F-26, 05 Bản 3 §6.6.4). App và server cùng
/// dùng (AP-10).
abstract final class ExerciseNoteRules {
  /// F26-R2: tối đa 200 ký tự, đếm theo ký tự người đọc thấy (grapheme), kể
  /// cả khoảng trắng, dấu xuống dòng.
  static const maxLength = 200;

  static int length(String text) => text.characters.length;

  /// F26-E1: dán đoạn dài hơn 200 ký tự → giữ 200 ký tự đầu.
  static String clip(String text) => length(text) <= maxLength
      ? text
      : text.characters.take(maxLength).toString();

  /// Nội dung lưu (F26-V2): bỏ khoảng trắng hai đầu; chuỗi rỗng = xóa ghi
  /// chú.
  static String normalize(String text) => text.trim();

  /// Nội dung đã [normalize] hợp lệ để lưu: 1–200 ký tự (server bước 5).
  static bool isValid(String text) {
    final n = length(text);
    return n >= 1 && n <= maxLength && text == text.trim();
  }

  /// Bước 1 → 4 của 05 Bản 3 §6.6.4: buổi, cửa sổ ghi tạ (F26-R3), bài (bài
  /// đã rời thư viện chỉ sửa, xóa được ghi chú đã có), nhóm cơ của buổi.
  /// Không xét `logsWeight`: bài bụng có ghi chú (F26-R4, TD3-06).
  static LiftError? check({
    required PlanDay? day,
    required Exercise? exercise,
    required DateTime now,
    bool exists = false,
  }) {
    if (!LiftLogRules.isSession(day)) return LiftError.noSession;
    if (!LiftWindow.of(day, now).isOpen) return LiftError.windowClosed;
    if (exercise == null || (!exists && !exercise.active)) {
      return LiftError.notAllowedForExercise;
    }
    if (!day!.sessionMuscles.contains(exercise.group)) {
      return LiftError.exerciseNotInSession;
    }
    return null;
  }

  /// Ghi chú buổi trước để hiện mờ (FA3-02, F26-R6, F26-E2): bài có ghi mức
  /// tạ → ghi chú của đúng buổi trước theo mức tạ (FA3-01), có thể không có;
  /// bài bụng → ghi chú gần nhất trước [date].
  static ExerciseNote? previous({
    required Iterable<ExerciseNote> notes,
    required Iterable<LiftLog> logs,
    required Exercise exercise,
    required LocalDate date,
  }) {
    if (exercise.logsWeight) {
      final previous = LiftLogRules.previousSession(logs, exercise.id, date);
      if (previous == null) return null;
      for (final n in notes) {
        if (n.exerciseId == exercise.id && n.date == previous.date) return n;
      }
      return null;
    }
    ExerciseNote? best;
    for (final n in notes) {
      if (n.exerciseId != exercise.id || !n.date.isBefore(date)) continue;
      if (best == null || n.date.isAfter(best.date)) best = n;
    }
    return best;
  }
}
