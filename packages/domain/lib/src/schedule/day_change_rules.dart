import '../session/extra_session.dart';
import '../session/session.dart';
import 'day_edit.dart';
import 'month_plan.dart';
import 'weekly_template.dart';

/// Buổi đã chốt mà một lần ghi `day` định thay đổi (05 Bản 2 §6.6.3).
enum DayLock {
  /// Buổi theo lịch "Đã tập" → `session_locked`.
  session,

  /// Buổi tập thêm đã lưu → `extra_session_locked`.
  extra,
}

/// Lần ghi `day` không hợp lệ: [field] sai, [lock] khi chạm buổi đã chốt.
final class DayViolation {
  const DayViolation(this.field, [this.lock]);

  final String field;
  final DayLock? lock;

  @override
  bool operator ==(Object other) =>
      other is DayViolation && other.field == field && other.lock == lock;

  @override
  int get hashCode => Object.hash(field, lock);

  @override
  String toString() => 'DayViolation($field${lock == null ? '' : ', $lock'})';
}

/// Kiểm tra một lần ghi bản ghi `day` ở server (05 §6.6.2, §6.10; 05 Bản 2
/// §6.6.3): so với bản đang có trên server, phần nào đổi thì áp quy tắc của
/// phần đó theo giờ trên iPhone lúc ghi. Áp dụng cho mọi phiên bản app.
///
/// - Buổi đã chốt ([SessionLock]): buổi "Đã tập" không đổi `mark`, nhóm cơ
///   thực tế, lịch của ngày; buổi tập thêm không đổi, không bỏ.
/// - Đánh dấu: chỉ ngày tập, từ giờ tập, trong hạn 7 ngày (gồm `skipped` →
///   `done`, F05-R25). App Bản 2 ghi "Đã tập" phải có nhóm cơ thực tế bằng
///   nhóm cơ của lịch (TD2-08); app Bản 1 tự chọn được.
/// - Buổi tập thêm: chỉ thêm, ở ngày nghỉ thứ 2 → thứ 7, không phải ngày
///   tương lai, trong hạn 7 ngày.
/// - Lịch của ngày (sửa riêng, trả về, chia lại): chỉ từ hôm nay đến cuối
///   tháng hiện tại; hôm nay chỉ khi buổi chưa đến giờ, chưa đánh dấu, và
///   không thành ngày tập khi đã có buổi tập thêm (F03-R8, R9, E4).
abstract final class DayChangeRules {
  /// [before] = bản trên server (null = chưa có). [localNow] = giờ trên iPhone
  /// lúc ghi, tính từ `clientUpdatedAt` và múi giờ trong hồ sơ; null khi chưa
  /// biết múi giờ thì bỏ qua các quy tắc theo thời gian. [fromV2App] = request
  /// có `X-App-Version`.
  ///
  /// Trả null khi hợp lệ. Cấu trúc bản ghi kiểm ở [PlanDay.invalidField].
  static DayViolation? check(
    PlanDay? before,
    PlanDay after,
    DateTime? localNow, {
    bool fromV2App = false,
  }) {
    final markChanged = _markChanged(before, after);
    final extraChanged = _extraChanged(before, after);
    if (before != null) {
      if (SessionLock.session(before) &&
          (markChanged || _planChanged(before, after))) {
        return const DayViolation('mark', DayLock.session);
      }
      if (SessionLock.extra(before) && extraChanged) {
        return const DayViolation('extraMuscles', DayLock.extra);
      }
      if (localNow != null &&
          _planChanged(before, after) &&
          OverrideRules.validate(before, after, localNow) != null) {
        return const DayViolation('key');
      }
    }
    if (markChanged) {
      if (!after.isWorkout) return const DayViolation('mark');
      if (localNow != null && !SessionRules.canMark(after, localNow)) {
        return const DayViolation('mark');
      }
      if (fromV2App &&
          after.mark == DayMark.done &&
          !_sameMuscles(after.actualMuscles, after.muscles)) {
        return const DayViolation('actualMuscles');
      }
    }
    if (extraChanged) {
      if (after.isWorkout) return const DayViolation('extraMuscles');
      if (after.extraMuscles != null &&
          localNow != null &&
          !ExtraSessionRules.canAdd(after.withExtra(null), localNow)) {
        return const DayViolation('extraMuscles');
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
