import '../schedule/month_plan.dart';
import '../schedule/weekly_template.dart';
import '../time/local_date.dart';
import 'session.dart';

/// Lý do không thêm được buổi tập thêm (F05-R31 → R35, F05-V21).
enum ExtraError {
  /// F05-R32, F05-E29: không phải ngày nghỉ thứ 2 → thứ 7 trong lịch.
  notRestDay,

  /// F05-R32: ngày tương lai.
  future,

  /// F05-R32: quá 7 ngày kể từ ngày của buổi.
  locked,

  /// F05-R32, F05-R34: ngày đã có buổi tập thêm (tối đa 1, đã chốt).
  alreadyLogged,

  /// F05-R31: tài khoản chưa có lịch tuần.
  noSchedule,

  /// F05-V21: chưa chọn nhóm cơ.
  noMuscles,
}

final class ExtraException implements Exception {
  const ExtraException(this.error);

  final ExtraError error;

  @override
  String toString() => 'ExtraException(${error.name})';
}

/// Quy tắc buổi tập thêm Bản 2 (F-05, FA-09): chỉ thêm, khóa ngay khi lưu,
/// không sửa, không xóa (F05-R34). App và server cùng dùng (AP-4).
abstract final class ExtraSessionRules {
  /// Kiểm tra thêm buổi tập thêm ngày [day] với [muscles] lúc [now] (giờ trên
  /// iPhone): ngày nghỉ thứ 2 → thứ 7, hôm nay hoặc 7 ngày trước, chưa có buổi
  /// tập thêm, đã có lịch tuần (F05-R31, F05-R32, F05-R35). [muscles] null =
  /// chỉ hỏi có lựa chọn "Thêm buổi tập" hay không.
  static ExtraError? validate(
    PlanDay day,
    List<MuscleGroup>? muscles,
    DateTime now, {
    bool hasSchedule = true,
  }) {
    if (!hasSchedule) return ExtraError.noSchedule;
    if (day.isWorkout || day.date.isSunday) return ExtraError.notRestDay;
    if (day.date.isAfter(LocalDate.fromDateTime(now))) return ExtraError.future;
    if (SessionRules.isLocked(day.date, now)) return ExtraError.locked;
    if (SessionLock.extra(day)) return ExtraError.alreadyLogged;
    if (muscles != null && muscles.isEmpty) return ExtraError.noMuscles;
    return null;
  }

  /// Có lựa chọn thêm buổi tập thêm cho ngày [day] lúc [now].
  static bool canAdd(PlanDay day, DateTime now, {bool hasSchedule = true}) =>
      validate(day, null, now, hasSchedule: hasSchedule) == null;

  /// Bản ghi ngày sau khi thêm buổi tập thêm [muscles]. Ném [ExtraException]
  /// khi vi phạm [validate].
  static PlanDay add(
    PlanDay day,
    List<MuscleGroup> muscles, {
    required DateTime now,
    bool hasSchedule = true,
  }) {
    final error = validate(day, muscles, now, hasSchedule: hasSchedule);
    if (error != null) throw ExtraException(error);
    return day.withExtra(MuscleGroup.ordered(muscles), loggedAt: now);
  }
}
