import '../day_lock.dart';
import '../schedule/month_plan.dart';
import '../schedule/weekly_template.dart';
import '../time/local_date.dart';
import 'session.dart';

/// Lý do không thêm / sửa / xóa được buổi tập thêm (F05-R31 → R35, F05-V21,
/// F05-R64).
enum ExtraError {
  /// F05-R32, F05-E29: không phải ngày nghỉ thứ 2 → thứ 7 trong lịch.
  notRestDay,

  /// Ngày tương lai.
  future,

  /// F05-R64: ngày đã qua (Bản 5 chỉ thêm, sửa, xóa cho hôm nay).
  locked,

  /// F05-R32: ngày đã có buổi tập thêm (tối đa 1 buổi / ngày).
  alreadyLogged,

  /// Sửa / xóa khi ngày chưa có buổi tập thêm.
  notLogged,

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

/// Quy tắc buổi tập thêm (F-05). Bản 5 (F05-R64, D5-03): chỉ thêm cho
/// **hôm nay**; sửa nhóm cơ, xóa được đến hết ngày; sang ngày khóa. Các quy
/// tắc khác giữ (ngày nghỉ thứ 2 → thứ 7, tối đa 1 buổi / ngày, ≥ 1 nhóm cơ,
/// đã có lịch tuần). App và server cùng dùng (AP-4).
abstract final class ExtraSessionRules {
  /// Kiểm tra thêm buổi tập thêm ngày [day] với [muscles] lúc [now] (giờ trên
  /// iPhone). [muscles] null = chỉ hỏi có lựa chọn "Thêm buổi tập" hay không.
  static ExtraError? validate(
    PlanDay day,
    List<MuscleGroup>? muscles,
    DateTime now, {
    bool hasSchedule = true,
  }) {
    if (!hasSchedule) return ExtraError.noSchedule;
    if (day.isWorkout || day.date.isSunday) return ExtraError.notRestDay;
    final today = LocalDate.fromDateTime(now);
    if (day.date.isAfter(today)) return ExtraError.future;
    if (day.date != today || !DayLock.isOpen(day.date, now)) {
      return ExtraError.locked;
    }
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

  /// Sửa nhóm cơ / xóa buổi tập thêm của [day] lúc [now] (F05-R64): ngày đã có
  /// buổi tập thêm, là hôm nay, chưa hết ngày. [muscles] rỗng = thiếu nhóm cơ
  /// (F05-V21); null = chỉ hỏi sửa / xóa được không.
  static ExtraError? validateEdit(
    PlanDay day,
    List<MuscleGroup>? muscles,
    DateTime now,
  ) {
    if (day.isWorkout || day.date.isSunday) return ExtraError.notRestDay;
    if (!SessionLock.extra(day)) return ExtraError.notLogged;
    final today = LocalDate.fromDateTime(now);
    if (day.date.isAfter(today)) return ExtraError.future;
    if (day.date != today || !DayLock.isOpen(day.date, now)) {
      return ExtraError.locked;
    }
    if (muscles != null && muscles.isEmpty) return ExtraError.noMuscles;
    return null;
  }

  /// Có lựa chọn "Sửa buổi thêm" / "Xóa buổi thêm" cho [day] lúc [now].
  static bool canEdit(PlanDay day, DateTime now) =>
      validateEdit(day, null, now) == null;

  /// Bản ghi ngày sau khi đổi nhóm cơ của buổi tập thêm thành [muscles]. Giữ
  /// thời điểm lưu lần đầu (cửa sổ ghi tạ mở từ lúc đó, FA2-11). Ném
  /// [ExtraException].
  static PlanDay edit(
    PlanDay day,
    List<MuscleGroup> muscles, {
    required DateTime now,
  }) {
    final error = validateEdit(day, muscles, now);
    if (error != null) throw ExtraException(error);
    return day.withExtra(
      MuscleGroup.ordered(muscles),
      loggedAt: day.extraLoggedAt,
    );
  }

  /// Bản ghi ngày sau khi xóa buổi tập thêm. Ném [ExtraException].
  static PlanDay delete(PlanDay day, {required DateTime now}) {
    final error = validateEdit(day, null, now);
    if (error != null) throw ExtraException(error);
    return day.withExtra(null);
  }
}
