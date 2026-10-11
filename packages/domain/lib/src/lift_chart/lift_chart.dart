import '../exercise/exercise.dart';
import '../lift_log/lift_log.dart';
import '../time/local_date.dart';
import '../time/year_month.dart';

/// Dữ liệu biểu đồ mức tạ của một bài trong một tháng dương lịch (F-22,
/// 06 Bản 2 VS28-T01). Mỗi ngày có bản ghi là một điểm trên mỗi chuỗi (bắt
/// đầu, kết thúc), không phụ thuộc trạng thái buổi (F22-R6).
final class MonthlyLiftChart {
  const MonthlyLiftChart._(this.month, this.logs);

  /// Bản ghi của [exerciseId] trong [month], cũ → mới.
  factory MonthlyLiftChart.of(
    Iterable<LiftLog> logs,
    String exerciseId,
    YearMonth month,
  ) => MonthlyLiftChart._(month, [
    for (final l in _sorted(logs, exerciseId))
      if (month.contains(l.date)) l,
  ]);

  final YearMonth month;

  /// Bản ghi của tháng, cũ → mới (danh sách dưới biểu đồ đảo ngược lại).
  final List<LiftLog> logs;

  /// F22-E1: tháng không có bản ghi.
  bool get isEmpty => logs.isEmpty;

  /// Các đoạn nối được của một chuỗi (F22-R9): chỉ nối hai điểm ở hai ngày
  /// liền nhau; ngày không có bản ghi thì đường không kéo qua.
  List<List<LiftLog>> get segments {
    final result = <List<LiftLog>>[];
    for (final l in logs) {
      if (result.isNotEmpty && result.last.last.date.addDays(1) == l.date) {
        result.last.add(l);
      } else {
        result.add([l]);
      }
    }
    return result;
  }

  /// Mức tạ nhỏ nhất và lớn nhất (kg × 10) của cả hai chuỗi; null khi trống.
  (int, int)? get range {
    if (logs.isEmpty) return null;
    var low = logs.first.startKgX10;
    var high = low;
    for (final l in logs) {
      for (final v in [l.startKgX10, l.endKgX10]) {
        if (v < low) low = v;
        if (v > high) high = v;
      }
    }
    return (low, high);
  }

  /// Tháng có bản ghi đầu tiên của bài: lùi xem không quá tháng này (F22-R2,
  /// F22-AC3). null khi bài chưa có bản ghi.
  static YearMonth? earliestMonth(Iterable<LiftLog> logs, String exerciseId) {
    LocalDate? first;
    for (final l in logs) {
      if (l.exerciseId != exerciseId) continue;
      if (first == null || l.date.isBefore(first)) first = l.date;
    }
    return first?.yearMonth;
  }

  static List<LiftLog> _sorted(Iterable<LiftLog> logs, String exerciseId) => [
    for (final l in logs)
      if (l.exerciseId == exerciseId) l,
  ]..sort((a, b) => a.date.compareTo(b.date));
}

/// Một dòng của Tiến bộ mức tạ (F-23): bài và bản ghi gần nhất của bài.
typedef ProgressItem = ({Exercise exercise, LiftLog latest});

/// Danh sách Tiến bộ mức tạ (F23-R1, R2, R5, R8).
abstract final class ProgressList {
  /// Bài có ít nhất 1 bản ghi (trừ bài bụng), mỗi bài kèm bản ghi có ngày
  /// muộn nhất; mới nhất lên đầu, cùng ngày thì theo thứ tự thư viện (F18-R9,
  /// `sortOrder`). Bài đã rời thư viện vẫn có. Bản ghi của bài không có trong
  /// [exercises] (chưa đồng bộ thư viện) bị bỏ qua.
  static List<ProgressItem> of(
    Iterable<LiftLog> logs,
    Iterable<Exercise> exercises,
  ) {
    final byId = {for (final e in exercises) e.id: e};
    final latest = <String, LiftLog>{};
    for (final l in logs) {
      final current = latest[l.exerciseId];
      if (current == null || l.date.isAfter(current.date)) {
        latest[l.exerciseId] = l;
      }
    }
    final items = <ProgressItem>[
      for (final MapEntry(key: id, value: log) in latest.entries)
        if (byId[id] case final e? when e.logsWeight)
          (exercise: e, latest: log),
    ];
    items.sort((a, b) {
      final byDate = b.latest.date.compareTo(a.latest.date);
      if (byDate != 0) return byDate;
      return a.exercise.sortOrder.compareTo(b.exercise.sortOrder);
    });
    return items;
  }
}
