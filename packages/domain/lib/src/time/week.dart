import 'local_date.dart';

/// Tuần: 00:00 thứ 2 → 23:59 chủ nhật (FR-08). Dùng cho cân nặng.
final class Week {
  Week.containing(LocalDate date) : start = date.weekStart;

  /// Thứ 2 của tuần.
  final LocalDate start;

  /// Chủ nhật của tuần.
  LocalDate get end => start.addDays(6);

  List<LocalDate> get days => [for (var i = 0; i < 7; i++) start.addDays(i)];

  bool contains(LocalDate date) => date >= start && date <= end;

  Week get next => Week.containing(start.addDays(7));

  Week get previous => Week.containing(start.addDays(-7));

  @override
  bool operator ==(Object other) => other is Week && other.start == start;

  @override
  int get hashCode => start.hashCode;

  @override
  String toString() => 'Week($start)';
}

/// Tuần tiến độ: 00:00 thứ 2 → 23:59 thứ 7 (FR-20). Chủ nhật không thuộc
/// tuần tiến độ nào.
final class ProgressWeek {
  ProgressWeek.containing(LocalDate date) : start = date.weekStart;

  /// Thứ 2 của tuần tiến độ.
  final LocalDate start;

  /// Thứ 7 của tuần tiến độ.
  LocalDate get end => start.addDays(5);

  /// 6 ngày từ thứ 2 đến thứ 7.
  List<LocalDate> get days => [for (var i = 0; i < 6; i++) start.addDays(i)];

  bool contains(LocalDate date) => date >= start && date <= end;

  /// Thời điểm kết thúc (00:00 chủ nhật, giờ thiết bị): sau mốc này các buổi
  /// chưa đánh dấu thành "Không tập (tự động)" (F05-R3).
  DateTime get endsAt => start.addDays(6).startOfDay;

  ProgressWeek get next => ProgressWeek.containing(start.addDays(7));

  ProgressWeek get previous => ProgressWeek.containing(start.addDays(-7));

  @override
  bool operator ==(Object other) =>
      other is ProgressWeek && other.start == start;

  @override
  int get hashCode => start.hashCode;

  @override
  String toString() => 'ProgressWeek($start)';
}
