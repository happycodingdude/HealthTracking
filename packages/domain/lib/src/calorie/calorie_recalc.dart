import '../profile/profile.dart';
import 'calorie.dart';

/// Kết quả tính lại mức calo sau một sự kiện F02-R7.
sealed class CalorieOutcome {
  const CalorieOutcome();
}

/// Không thông báo, không đề xuất (F02-R10, hoặc chưa đủ thông tin).
final class CalorieUnchanged extends CalorieOutcome {
  const CalorieUnchanged();
}

/// F02-R8: chế độ Tự động, mức calo đã cập nhật từ [from] thành [to].
final class CalorieAutoUpdated extends CalorieOutcome {
  const CalorieAutoUpdated(this.from, this.to);

  final int from;
  final int to;
}

/// F02-R9: chế độ Bạn tự đặt, đề xuất mức ước tính [kcal]; Bạn đang dùng
/// [current].
final class CalorieProposed extends CalorieOutcome {
  const CalorieProposed(this.kcal, this.current, this.reason);

  final int kcal;
  final int current;
  final CaloriePendingReason reason;
}

/// Tính lại mức calo khi số cân mới nhất, hồ sơ hoặc năm đổi (F02-R7 → R10,
/// F01-R5, F01-E2).
abstract final class CalorieRecalc {
  /// F02-R10: chênh dưới mức này thì không thông báo, không đề xuất.
  static const minChange = 10;

  /// [profile] là hồ sơ sau sự kiện; [before], [after] là mức ước tính
  /// trước và sau sự kiện (null khi không tính được). Trả hồ sơ cần lưu (null
  /// = không cần ghi) và kết quả để hiện cho Bạn.
  static ({Profile? profile, CalorieOutcome outcome}) apply({
    required Profile profile,
    required int? before,
    required int? after,
    required CaloriePendingReason reason,
  }) {
    const none = (profile: null, outcome: CalorieUnchanged());
    if (after == null || profile.calorieMode == null) return none;
    if (profile.calorieMode == CalorieMode.auto) {
      final from = profile.calorieKcal;
      if (from == after) return none;
      // Tự động: mức calo luôn bằng mức ước tính; chỉ báo khi chênh từ 10 kcal.
      final next = profile.copyWith(calorieKcal: after);
      if (from != null && (after - from).abs() < minChange) {
        return (profile: next, outcome: const CalorieUnchanged());
      }
      return (profile: next, outcome: CalorieAutoUpdated(from ?? after, after));
    }
    if (before != null && (after - before).abs() < minChange) return none;
    return (
      profile: profile.withPending(after, reason),
      outcome: CalorieProposed(after, profile.calorieKcal!, reason),
    );
  }

  /// "Dùng {Y} kcal" ở S-53/S-52 (F02-R9 đồng ý) hoặc "Dùng lại ước tính của
  /// app" (F02-AC6): về Tự động với mức [kcal], bỏ đề xuất.
  static Profile useEstimate(Profile p, int kcal) => p
      .copyWith(calorieMode: CalorieMode.auto, calorieKcal: kcal)
      .withPending(null, null);

  /// "Giữ nguyên" (F02-R9): vẫn Bạn tự đặt, bỏ đề xuất cho đến sự kiện sau.
  static Profile keepManual(Profile p) => p.withPending(null, null);

  /// "Đặt mức khác" (F02-R4): Bạn tự đặt [kcal], bỏ đề xuất đang chờ.
  static Profile setManual(Profile p, int kcal) => p
      .copyWith(calorieMode: CalorieMode.manual, calorieKcal: kcal)
      .withPending(null, null);
}
