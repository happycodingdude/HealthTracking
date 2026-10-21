import '../time/local_date.dart';
import 'lift_kg.dart';

/// Đơn vị mức tạ Bạn chọn cho một bài (entity `exercise_unit`, key =
/// `exerciseId`, TD3-03): gắn ở lần ghi đầu, đổi được bất cứ lúc nào
/// (FA3-04). [changedOn] = ngày đổi gần nhất (ngày gắn lần đầu nếu chưa đổi),
/// dùng cho mốc "Đổi sang …" trên biểu đồ (F22-R42).
final class ExerciseUnit {
  const ExerciseUnit({
    required this.exerciseId,
    required this.unit,
    required this.changedOn,
  });

  final String exerciseId;
  final LiftUnit unit;
  final LocalDate changedOn;

  @override
  bool operator ==(Object other) =>
      other is ExerciseUnit &&
      other.exerciseId == exerciseId &&
      other.unit == unit &&
      other.changedOn == changedOn;

  @override
  int get hashCode => Object.hash(exerciseId, unit, changedOn);

  @override
  String toString() => 'ExerciseUnit($exerciseId, ${unit.wire}, $changedOn)';
}
