import '../lift_log/lift_log.dart';
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
