import 'package:domain/domain.dart';

/// Đơn vị mức tạ của bài trên máy này. Bản 3 bỏ đơn vị theo loại dụng cụ
/// (TD3-20); đơn vị theo từng bài từ bảng `exercise_units` có từ VS-35, tới
/// lúc đó mọi bài ghi bằng kg như Bản 2 (F21-R6).
extension ExerciseLiftUnit on Exercise {
  LiftUnit get liftUnit => LiftUnit.kg;
}
