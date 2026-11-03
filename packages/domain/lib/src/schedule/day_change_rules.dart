import '../day_lock.dart';
import '../session/extra_session.dart';
import '../session/session.dart';
import '../time/local_date.dart';
import 'day_edit.dart';
import 'month_plan.dart';
import 'weekly_template.dart';

/// Loại vi phạm của một lần ghi `day` (05 Bản 5 §6.6.2, TD5-08).
enum DayViolationCode {
  /// Dữ liệu sai (`validation_failed`).
  invalid,

  /// Ngày đã khóa (hết ngày, FC5-01): `day_locked`. Thay `session_locked`,
  /// `extra_session_locked`, hạn 7 ngày, đánh dấu lùi của Bản 2.
  dayLocked,

  /// "Đã tập" trước giờ mở buổi (F05-R22, FD5-01): `lift_window_closed`.
  windowClosed,
}

/// Lần ghi `day` không hợp lệ: [field] sai, [code] là loại vi phạm.
final class DayViolation {
  const DayViolation(this.field, [this.code = DayViolationCode.invalid]);

  final String field;
  final DayViolationCode code;

  @override
  bool operator ==(Object other) =>
      other is DayViolation && other.field == field && other.code == code;

  @override
  int get hashCode => Object.hash(field, code);

  @override
  String toString() => 'DayViolation($field, ${code.name})';
}

/// Kiểm tra một lần ghi bản ghi `day` ở server (05 §6.6.2; 05 Bản 5 §6.6.2,
/// TD5-08): so với bản đang có trên server, phần nào đổi thì áp quy tắc của
/// phần đó theo giờ trên iPhone lúc ghi. Áp dụng cho mọi phiên bản app (TR5-07).
///
/// - Khóa trong ngày ([DayLock]): mọi thay đổi `mark`, nhóm cơ thực tế, lịch
///   của ngày, buổi tập thêm của ngày đã qua → `day_locked`.
/// - Đánh dấu: chỉ ngày tập; "Đã tập" từ giờ mở buổi (giờ tập hoặc lúc tới
///   gym — `lift_window_closed` nếu sớm hơn); "Không tập", bỏ đánh dấu từ đầu
///   ngày; đổi qua lại trong ngày (F05-R61, F05-R62, FC5-13). App Bản 2 trở đi
///   ghi "Đã tập" phải có nhóm cơ thực tế bằng nhóm cơ của lịch (TD2-08).
/// - Buổi tập thêm: chỉ ngày nghỉ thứ 2 → thứ 7, chỉ hôm nay; thêm, sửa nhóm
///   cơ, xóa đến hết ngày (F05-R64).
/// - Lịch của ngày (sửa riêng, trả về, chia lại): chỉ từ hôm nay đến cuối
///   tháng hiện tại; hôm nay chỉ khi buổi chưa mở, chưa đánh dấu, và không
///   thành ngày tập khi đã có buổi tập thêm (F03-R8, R9, E4, F05-R68).
/// - `openedAt` (TD5-07): chỉ ngày tập, không muộn hơn giờ tập của ngày; bỏ
///   đi thì không tính là đổi (server giữ mốc sớm hơn, [mergeOpenedAt]).
abstract final class DayChangeRules {
  /// [before] = bản trên server (null = chưa có). [localNow] = giờ trên iPhone
  /// lúc ghi, tính từ `clientUpdatedAt` và múi giờ trong hồ sơ; null khi chưa
  /// biết múi giờ thì bỏ qua các quy tắc theo thời gian. [fromV2App] = request
  /// có `X-App-Version`. [after] đã qua [mergeOpenedAt].
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
    final planChanged = before != null && _planChanged(before, after);
    final openedChanged = !_sameInstant(before?.openedAt, after.openedAt);
    if (after.openedAt != null) {
      if (!after.isWorkout) return const DayViolation('openedAt');
      final opened = after.openedAt!;
      final local = opened.isUtc ? opened.toLocal() : opened;
      if (LocalDate.fromDateTime(local) != after.date ||
          local.isAfter(SessionRules.startsAt(after))) {
        // Server quy openedAt về giờ iPhone trước khi gọi; app dùng giờ máy.
        if (localNow != null) return const DayViolation('openedAt');
      }
    }
    final changed = markChanged || extraChanged || planChanged || openedChanged;
    if (changed && localNow != null && !DayLock.isOpen(after.date, localNow)) {
      return DayViolation(
        markChanged
            ? 'mark'
            : extraChanged
            ? 'extraMuscles'
            : planChanged
            ? 'key'
            : 'openedAt',
        DayViolationCode.dayLocked,
      );
    }
    if (planChanged &&
        localNow != null &&
        OverrideRules.validate(before, after, localNow) != null) {
      return const DayViolation('key');
    }
    if (markChanged) {
      if (!after.isWorkout) return const DayViolation('mark');
      if (localNow != null &&
          after.mark == DayMark.done &&
          before?.mark != DayMark.done &&
          localNow.isBefore(SessionRules.opensAt(after))) {
        return const DayViolation('mark', DayViolationCode.windowClosed);
      }
      if (fromV2App &&
          after.mark == DayMark.done &&
          !_sameMuscles(after.actualMuscles, after.muscles)) {
        return const DayViolation('actualMuscles');
      }
    }
    if (extraChanged) {
      if (after.isWorkout) return const DayViolation('extraMuscles');
      if (localNow != null) {
        final today = LocalDate.fromDateTime(localNow);
        if (after.date != today) {
          return DayViolation(
            'extraMuscles',
            after.date < today
                ? DayViolationCode.dayLocked
                : DayViolationCode.invalid,
          );
        }
        final adding = before?.extraMuscles == null;
        if (adding &&
            after.extraMuscles != null &&
            !ExtraSessionRules.canAdd(after.withExtra(null), localNow)) {
          return const DayViolation('extraMuscles');
        }
      }
    }
    return null;
  }

  /// `openedAt` sau khi gộp bản trên server [before] và bản gửi lên [after]:
  /// mốc **sớm hơn** thắng (TA5-02, 05 Bản 5 §6.6.1); bản gửi lên không có
  /// mốc (app chưa biết, app Bản 4) thì giữ mốc của server.
  static DateTime? mergeOpenedAt(PlanDay? before, PlanDay after) {
    final a = before?.openedAt, b = after.openedAt;
    if (a == null) return b;
    if (b == null) return a;
    return b.isBefore(a) ? b : a;
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
