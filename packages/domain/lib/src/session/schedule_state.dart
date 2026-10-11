import '../profile/profile.dart';
import '../schedule/weekly_template.dart';
import '../time/local_date.dart';

/// Trạng thái lịch của tài khoản (05 Bản 2 TD2-09, 03 Bản 2 §6.2): "Chưa có
/// lịch" = chưa có dòng lịch tuần nào (Bạn "Để sau" ở bước lịch tuần và chưa
/// lưu lần nào). Không có cờ riêng; lưu lịch tuần rồi thì không quay lại
/// (F03-R24).
final class ScheduleState {
  const ScheduleState({required this.hasSchedule, this.startDate});

  factory ScheduleState.of({
    required WeeklyTemplate? template,
    required Profile? profile,
  }) => ScheduleState(
    hasSchedule: template != null,
    startDate: template == null ? null : profile?.scheduleStart,
  );

  /// Chưa có lịch: không lịch tháng, không buổi tập, không buổi tập thêm,
  /// không nhắc (F03-R22, F04-R22, F05-R31).
  static const none = ScheduleState(hasSchedule: false);

  final bool hasSchedule;

  /// Ngày lưu lịch tuần lần đầu (tài khoản Bản 1: ngày thiết lập): mốc của
  /// tiến độ tuần và lịch tháng (F06-R22, UA-12). null khi chưa có lịch.
  final LocalDate? startDate;

  @override
  bool operator ==(Object other) =>
      other is ScheduleState &&
      other.hasSchedule == hasSchedule &&
      other.startDate == startDate;

  @override
  int get hashCode => Object.hash(hasSchedule, startDate);

  @override
  String toString() => 'ScheduleState($hasSchedule, $startDate)';
}
