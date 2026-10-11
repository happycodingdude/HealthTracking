import '../schedule/month_plan.dart';
import '../session/session.dart';

/// Vì sao cửa sổ ghi tạ đóng (05 Bản 2 §6.4.3).
enum LiftClosedReason {
  /// Ngày không có buổi (ngày nghỉ không có buổi tập thêm, chủ nhật).
  noSession,

  /// Đã qua 00:00 ngày sau ngày của buổi (F21-R5, F21-R12).
  ended,

  /// Buổi tập thêm ghi cho ngày đã qua: không bao giờ mở (FR2-07, F21-AC10).
  pastExtra,
}

/// Cửa sổ ghi tạ của một buổi (03 Bản 2 §6.1, 05 Bản 2 §6.4.3, 06 Bản 2
/// ED2-05). Cùng một hàm cho app (giờ iPhone) và server (`clientUpdatedAt`
/// quy về múi giờ trong hồ sơ, AP-10).
sealed class LiftWindow {
  const LiftWindow();

  /// Cửa sổ của buổi ngày [day] lúc [now] (giờ trên iPhone). `extraLoggedAt`
  /// của [day] là giờ trên iPhone; thời điểm UTC được đổi sang giờ máy (app).
  /// Server quy về múi giờ trong hồ sơ trước khi gọi.
  ///
  /// - Buổi theo lịch: từ giờ tập đến 00:00 ngày sau (FD2-01).
  /// - Buổi tập thêm lưu trong chính ngày của buổi: từ lúc lưu đến 00:00
  ///   ngày sau (FA2-11). Lưu cho ngày đã qua: không bao giờ mở.
  static LiftWindow of(PlanDay? day, DateTime now) {
    if (day == null || day.date.isSunday) {
      return const LiftWindowClosed(LiftClosedReason.noSession);
    }
    final DateTime opensAt;
    if (day.isWorkout) {
      opensAt = SessionRules.startsAt(day);
    } else if (SessionLock.extra(day) && day.extraLoggedAt != null) {
      final at = day.extraLoggedAt!;
      final logged = at.isUtc ? at.toLocal() : at;
      if (logged.year != day.date.year ||
          logged.month != day.date.month ||
          logged.day != day.date.day) {
        return const LiftWindowClosed(LiftClosedReason.pastExtra);
      }
      opensAt = logged;
    } else {
      return const LiftWindowClosed(LiftClosedReason.noSession);
    }
    final closesAt = day.date.addDays(1).startOfDay;
    if (!now.isBefore(closesAt)) {
      return const LiftWindowClosed(LiftClosedReason.ended);
    }
    if (now.isBefore(opensAt)) return LiftWindowNotOpen(opensAt);
    return LiftWindowOpen(closesAt);
  }

  bool get isOpen => this is LiftWindowOpen;
}

/// Chưa đến giờ tập: "Ghi mức tạ được từ {giờ}" (F21-AC1).
final class LiftWindowNotOpen extends LiftWindow {
  const LiftWindowNotOpen(this.opensAt);

  final DateTime opensAt;

  @override
  bool operator ==(Object other) =>
      other is LiftWindowNotOpen && other.opensAt == opensAt;

  @override
  int get hashCode => opensAt.hashCode;

  @override
  String toString() => 'LiftWindowNotOpen($opensAt)';
}

/// Đang mở đến [closesAt] (00:00 ngày sau).
final class LiftWindowOpen extends LiftWindow {
  const LiftWindowOpen(this.closesAt);

  final DateTime closesAt;

  @override
  bool operator ==(Object other) =>
      other is LiftWindowOpen && other.closesAt == closesAt;

  @override
  int get hashCode => closesAt.hashCode;

  @override
  String toString() => 'LiftWindowOpen($closesAt)';
}

final class LiftWindowClosed extends LiftWindow {
  const LiftWindowClosed(this.reason);

  final LiftClosedReason reason;

  @override
  bool operator ==(Object other) =>
      other is LiftWindowClosed && other.reason == reason;

  @override
  int get hashCode => reason.hashCode;

  @override
  String toString() => 'LiftWindowClosed(${reason.name})';
}
