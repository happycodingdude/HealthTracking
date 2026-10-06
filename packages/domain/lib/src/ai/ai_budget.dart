import '../time/local_date.dart';
import '../time/year_month.dart';

/// Ngân sách AI dùng chung toàn app (F-11, TR-07).
abstract final class AiBudgetRules {
  /// F11-R1: mức trần mỗi tháng dương lịch.
  static const capVnd = 50000;

  /// F11-R4: báo một lần khi chi phí đã dùng đạt 80% mức trần.
  static const warnPercent = 80;

  /// TA-17: tháng ngân sách theo giờ Việt Nam (UTC+7, không đổi giờ mùa hè).
  static const vietnamOffset = Duration(hours: 7);

  /// Tháng ngân sách chứa thời điểm [instant].
  static YearMonth monthOf(DateTime instant) {
    final vn = instant.toUtc().add(vietnamOffset);
    return YearMonth(vn.year, vn.month);
  }

  /// Ngày đặt lại mức đã dùng: 01 tháng sau (F11-E2, 04 S-54).
  static LocalDate resetDate(YearMonth month) => month.next.firstDay;

  /// Phần trăm đã dùng, làm tròn xuống, tối đa 100 (F11-R6).
  static int percent(num usedVnd, int capVnd) {
    if (capVnd <= 0) return 100;
    final p = (usedVnd * 100 / capVnd).floor();
    return p.clamp(0, 100);
  }

  /// Đã đạt mức báo 80% (F11-R4).
  static bool reachedWarning(num usedVnd, int capVnd) =>
      usedVnd * 100 >= capVnd * warnPercent;
}
