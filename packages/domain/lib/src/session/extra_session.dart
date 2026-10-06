import '../schedule/month_plan.dart';
import '../schedule/weekly_template.dart';
import '../time/local_date.dart';
import 'session.dart';

/// Lý do không ghi, sửa hoặc xóa được buổi tập thêm (F05-R7 → R11, F05-V2).
enum ExtraError {
  /// F05-R7, F05-E4, F05-E6: không phải ngày nghỉ thứ 2 → thứ 7 trong lịch.
  notRestDay,

  /// F05-R9: ngày tương lai.
  future,

  /// F05-R9, F05-R11: quá 7 ngày kể từ ngày của buổi.
  locked,

  /// F05-V2: chưa chọn nhóm cơ.
  noMuscles,
}

final class ExtraException implements Exception {
  const ExtraException(this.error);

  final ExtraError error;

  @override
  String toString() => 'ExtraException(${error.name})';
}

/// Quy tắc buổi tập thêm (F-05, FA-09). App và server cùng dùng (AP-4).
abstract final class ExtraSessionRules {
  /// Kiểm tra ghi buổi tập thêm ngày [day] với [muscles] lúc [now] (giờ trên
  /// iPhone). [muscles] null = xóa (ED-08). Hạn ghi, sửa, xóa giống hạn đánh
  /// dấu buổi theo lịch: hôm nay hoặc 7 ngày trước (F05-R9, F05-R11).
  static ExtraError? validate(
    PlanDay day,
    List<MuscleGroup>? muscles,
    DateTime now,
  ) {
    if (day.isWorkout || day.date.isSunday) return ExtraError.notRestDay;
    if (day.date.isAfter(LocalDate.fromDateTime(now))) return ExtraError.future;
    if (SessionRules.isLocked(day.date, now)) return ExtraError.locked;
    if (muscles != null && muscles.isEmpty) return ExtraError.noMuscles;
    return null;
  }

  /// Có lựa chọn ghi (hoặc sửa, xóa) buổi tập thêm cho ngày [day] lúc [now].
  static bool canLog(PlanDay day, DateTime now) =>
      validate(day, null, now) == null;

  /// Bản ghi ngày sau khi ghi buổi tập thêm [muscles] (null = xóa). Ném
  /// [ExtraException] khi vi phạm [validate].
  static PlanDay log(
    PlanDay day,
    List<MuscleGroup>? muscles, {
    required DateTime now,
  }) {
    final error = validate(day, muscles, now);
    if (error != null) throw ExtraException(error);
    return muscles == null
        ? day.withExtra(null)
        : day.withExtra(MuscleGroup.ordered(muscles), loggedAt: now);
  }
}
