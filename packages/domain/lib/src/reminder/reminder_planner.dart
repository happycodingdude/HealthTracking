import '../schedule/month_plan.dart';
import '../schedule/weekly_template.dart';
import '../time/local_date.dart';
import '../time/local_time.dart';

/// Một nhắc đi tập cần hẹn (F-04). Nội dung chữ do app ghép từ các trường này
/// (F04-R3, F04-E1).
final class Reminder {
  const Reminder({
    required this.at,
    required this.date,
    required this.time,
    required this.muscles,
  });

  /// Thời điểm nhắc theo giờ trên iPhone = giờ tập − 60 phút (F04-R2).
  final DateTime at;

  /// Ngày của buổi tập.
  final LocalDate date;
  final LocalTime time;
  final List<MuscleGroup> muscles;

  /// F04-E1: buổi trước 01:00 được nhắc từ tối hôm trước ("Ngày mai tập …").
  bool get isTomorrow => LocalDate.fromDateTime(at) != date;

  /// Mã ổn định theo ngày (một ngày tối đa một buổi theo lịch, F03-R3).
  int get id => date.year * 10000 + date.month * 100 + date.day;

  @override
  bool operator ==(Object other) =>
      other is Reminder &&
      other.at.isAtSameMomentAs(at) &&
      other.date == date &&
      other.time == time &&
      _same(other.muscles, muscles);

  @override
  int get hashCode => Object.hash(at.millisecondsSinceEpoch, date, time);

  @override
  String toString() => 'Reminder($at → $date $time)';
}

bool _same<T>(List<T> a, List<T> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

/// Lập danh sách nhắc cần hẹn (05 §6.4.4, TR-10).
abstract final class ReminderPlanner {
  /// F04-R2: nhắc trước giờ tập 60 phút.
  static const lead = Duration(minutes: 60);

  /// TR-10: iOS giới hạn 64 thông báo hẹn trước; app hẹn tối đa 60.
  static const limit = 60;

  /// Các buổi theo lịch từ [now] trở đi, nhắc còn ở tương lai (F04-R6), tối đa
  /// [limit] nhắc, theo thứ tự thời gian.
  ///
  /// - [currentMonth]: các ngày của tháng hiện tại (bảng `days`).
  /// - [nextMonth]: các ngày của tháng sau nếu đã được tạo; null thì suy ra từ
  ///   [template] (đúng với những gì F03-R6 sẽ tạo, TAC-09).
  /// - Chỉ nhắc buổi theo lịch (F04-R4), gồm cả ngày sửa riêng (F04-R7).
  static List<Reminder> plan({
    required List<PlanDay> currentMonth,
    required List<PlanDay>? nextMonth,
    required WeeklyTemplate? template,
    required DateTime now,
  }) {
    final today = LocalDate.fromDateTime(now);
    final next = today.yearMonth.next;
    final following =
        nextMonth ??
        (template == null
            ? const <PlanDay>[]
            : MonthGenerator.month(template, next, now).days);
    final reminders = <Reminder>[];
    for (final d in [...currentMonth, ...following]) {
      if (!d.isWorkout || d.mark != null || d.date.isBefore(today)) continue;
      final at = d.date.atTime(d.time!).subtract(lead);
      if (!at.isAfter(now)) continue;
      reminders.add(
        Reminder(at: at, date: d.date, time: d.time!, muscles: d.muscles),
      );
    }
    reminders.sort((a, b) => a.at.compareTo(b.at));
    return reminders.length > limit ? reminders.sublist(0, limit) : reminders;
  }
}
