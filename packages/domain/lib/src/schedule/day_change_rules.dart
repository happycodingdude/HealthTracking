import '../session/extra_session.dart';
import '../session/session.dart';
import 'day_edit.dart';
import 'month_plan.dart';
import 'weekly_template.dart';

/// Kiểm tra một lần ghi bản ghi `day` ở server (05 §6.6.2, §6.10): so với bản
/// đang có trên server, phần nào đổi thì áp quy tắc của phần đó theo giờ trên
/// iPhone lúc ghi.
///
/// - Đánh dấu (VS06-T03): chỉ ngày tập, từ giờ tập, trong hạn 7 ngày.
/// - Buổi tập thêm (VS07-T02): ghi, sửa, xóa chỉ ở ngày nghỉ thứ 2 → thứ 7,
///   không phải ngày tương lai, trong hạn 7 ngày (xóa = `extraMuscles: null`,
///   ED-08).
/// - Lịch của ngày (VS09-T04: sửa riêng, trả về, chia lại): chỉ từ hôm nay
///   đến cuối tháng hiện tại; hôm nay chỉ khi buổi chưa đến giờ, chưa đánh
///   dấu, và không thành ngày tập khi đã có buổi tập thêm (F03-R8, R9, E4).
abstract final class DayChangeRules {
  /// [before] = bản trên server (null = chưa có). [localNow] = giờ trên iPhone
  /// lúc ghi, tính từ `clientUpdatedAt` và múi giờ trong hồ sơ; null khi chưa
  /// biết múi giờ thì bỏ qua các quy tắc theo thời gian.
  ///
  /// Trả tên trường sai, null = hợp lệ. Cấu trúc bản ghi kiểm ở
  /// [PlanDay.invalidField].
  static String? check(PlanDay? before, PlanDay after, DateTime? localNow) {
    if (before != null && localNow != null && _planChanged(before, after)) {
      if (OverrideRules.validate(before, after, localNow) != null) return 'key';
    }
    if (_markChanged(before, after)) {
      if (!after.isWorkout) return 'mark';
      if (localNow != null && !SessionRules.canMark(after, localNow)) {
        return 'mark';
      }
    }
    if (_extraChanged(before, after)) {
      if (after.isWorkout) return 'extraMuscles';
      if (localNow != null && !ExtraSessionRules.canLog(after, localNow)) {
        return 'extraMuscles';
      }
    }
    return null;
  }

  static bool _markChanged(PlanDay? before, PlanDay after) {
    if (before == null) return after.mark != null;
    return before.mark != after.mark ||
        !_sameMuscles(before.actualMuscles, after.actualMuscles) ||
        !_sameInstant(before.markedAt, after.markedAt);
  }

  static bool _planChanged(PlanDay before, PlanDay after) =>
      before.kind != after.kind ||
      before.time != after.time ||
      !_sameMuscles(before.muscles, after.muscles) ||
      before.source != after.source;

  static bool _extraChanged(PlanDay? before, PlanDay after) {
    if (before == null) return after.extraMuscles != null;
    return !_sameMuscles(before.extraMuscles, after.extraMuscles) ||
        !_sameInstant(before.extraLoggedAt, after.extraLoggedAt);
  }
}

bool _sameInstant(DateTime? a, DateTime? b) =>
    a == null || b == null ? a == b : a.isAtSameMomentAs(b);

bool _sameMuscles(List<MuscleGroup>? a, List<MuscleGroup>? b) {
  if (a == null || b == null) return a == b;
  final x = MuscleGroup.ordered(a), y = MuscleGroup.ordered(b);
  if (x.length != y.length) return false;
  for (var i = 0; i < x.length; i++) {
    if (x[i] != y[i]) return false;
  }
  return true;
}
