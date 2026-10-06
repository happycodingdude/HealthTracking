import '../schedule/month_plan.dart';
import '../schedule/weekly_template.dart';
import '../session/session.dart';
import '../time/local_date.dart';
import '../time/week.dart';
import '../time/year_month.dart';

/// Một ngày thứ 2 → thứ 7 trong tuần tiến độ.
final class ProgressDay {
  const ProgressDay(this.date, this.day, this.status);

  final LocalDate date;

  /// Bản ghi ngày; null khi ngày chưa có lịch (trước ngày thiết lập).
  final PlanDay? day;

  /// Trạng thái buổi theo lịch; null với ngày nghỉ hoặc chưa có lịch.
  final SessionStatus? status;

  /// Nhóm cơ của buổi tập thêm (chỉ ngày nghỉ), null khi không có.
  List<MuscleGroup>? get extra => day?.extraMuscles;
}

/// Tiến độ một tuần tiến độ thứ 2 → thứ 7 (F-06): "Đã tập X/Y buổi theo
/// lịch", "+Z buổi thêm".
final class WeeklyProgress {
  const WeeklyProgress._(this.week, this.days);

  final ProgressWeek week;

  /// Thứ 2 → thứ 7.
  final List<ProgressDay> days;

  /// F06-R2: X = số buổi theo lịch "Đã tập".
  int get done => days.where((d) => d.status?.counts ?? false).length;

  /// F06-R1, F06-R4: Y = số buổi theo lịch, kể cả "Sắp tới", "Chờ đánh dấu".
  int get planned => days.where((d) => d.status != null).length;

  /// F06-R3, F05-R12: Z = số buổi tập thêm, không tính vào X, Y.
  int get extra => days.where((d) => d.extra != null).length;

  /// Tiến độ tuần [week] lúc [now] (giờ trên iPhone).
  ///
  /// [days] là các bản ghi ngày đã có. Mỗi ngày lấy từ lịch tháng chứa nó
  /// (F06-E4); ngày thuộc tháng sau chưa có lịch (chưa tới ngày 1, F03-R6)
  /// thì suy ra từ [template], đúng với những gì sẽ được tạo. Ngày trước
  /// ngày thiết lập không có lịch nên không được tính (F06-E2).
  static WeeklyProgress compute(
    ProgressWeek week, {
    required List<PlanDay> days,
    required Set<YearMonth> planned,
    required WeeklyTemplate? template,
    required DateTime now,
  }) {
    final byDate = {for (final d in days) d.date: d};
    final last = planned.isEmpty
        ? null
        : planned.reduce((a, b) => a.compareTo(b) >= 0 ? a : b);
    PlanDay? dayOf(LocalDate date) {
      final d = byDate[date];
      if (d != null) return d;
      if (template == null || last == null) return null;
      if (date.yearMonth.compareTo(last) <= 0) return null;
      return PlanDay.fromTemplate(date, template.day(date.weekday));
    }

    return WeeklyProgress._(week, [
      for (final date in week.days)
        if (dayOf(date) case final d?)
          ProgressDay(date, d, SessionStatus.derive(d, now))
        else
          ProgressDay(date, null, null),
    ]);
  }

  /// F06-R5, F06-E3: các tuần xem được, từ tuần thiết lập lịch ([setupDate])
  /// đến tuần hiện tại, cũ → mới. Chủ nhật thuộc tuần vừa kết thúc; thiết
  /// lập vào chủ nhật thì tuần đầu là tuần sau đó.
  static List<ProgressWeek> weeks({
    required LocalDate setupDate,
    required LocalDate today,
  }) {
    final first = ProgressWeek.containing(
      setupDate.isSunday ? setupDate.addDays(1) : setupDate,
    );
    var last = ProgressWeek.containing(today);
    if (last.start < first.start) last = first;
    return [for (var w = first; w.start <= last.start; w = w.next) w];
  }
}
