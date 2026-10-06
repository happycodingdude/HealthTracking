import '../time/local_date.dart';
import 'weight_rules.dart';

/// Một số cân: tuần (thứ 2) và cân nặng × 10.
typedef WeightPoint = ({LocalDate week, int kgX10});

/// Lịch sử cân nặng theo tuần (F-07). [points] sắp theo tuần, cũ → mới.
final class WeightLog {
  WeightLog(Iterable<WeightPoint> points)
    : points = List.unmodifiable(
        <WeightPoint>[...points]..sort((a, b) => a.week.compareTo(b.week)),
      );

  final List<WeightPoint> points;

  /// F07-AC2, V2: chênh hơn 5 kg so với lần trước thì hỏi xác nhận.
  static const bigChangeKgX10 = 50;

  /// F07-R4: số cân mới nhất = tuần gần đây nhất có ghi.
  WeightPoint? get latest => points.isEmpty ? null : points.last;

  /// Số cân ban đầu: tuần cũ nhất có ghi (cân nặng lúc thiết lập, F01-AC4).
  WeightPoint? get initial => points.isEmpty ? null : points.first;

  /// F07-R7: số cân mới nhất trừ lần ghi trước đó; null khi mới có 1 số cân
  /// (F07-E1).
  int? get changeFromPrevious => points.length < 2
      ? null
      : points.last.kgX10 - points[points.length - 2].kgX10;

  /// F07-R7: số cân mới nhất trừ số cân ban đầu.
  int? get changeFromInitial =>
      points.isEmpty ? null : points.last.kgX10 - points.first.kgX10;

  WeightPoint? at(LocalDate week) {
    for (final p in points) {
      if (p.week == week) return p;
    }
    return null;
  }

  /// "Lần trước" khi ghi tuần [week] (F07-V2): số đang có của tuần đó, nếu
  /// không thì tuần gần nhất trước nó, nếu không thì tuần gần nhất sau nó.
  WeightPoint? baseFor(LocalDate week) {
    final same = at(week);
    if (same != null) return same;
    WeightPoint? before;
    for (final p in points) {
      if (p.week < week) before = p;
    }
    if (before != null) return before;
    for (final p in points) {
      if (p.week > week) return p;
    }
    return null;
  }

  /// F07-V2: mức chênh (× 10, luôn dương) khi ghi [kgX10] cho tuần [week]
  /// hơn 5 kg so với lần trước; null khi không cần hỏi.
  int? bigChange(LocalDate week, int kgX10) {
    final base = baseFor(week);
    if (base == null) return null;
    final diff = (kgX10 - base.kgX10).abs();
    return diff > bigChangeKgX10 ? diff : null;
  }

  /// F07-R3: không xóa được số cân duy nhất còn lại.
  bool canDelete(LocalDate week) => at(week) != null && points.length > 1;

  /// F07-R5: ghi, sửa hoặc xóa số cân tuần [week] có làm đổi số cân mới
  /// nhất không (tuần đó là tuần mới nhất, hoặc mới hơn tuần mới nhất).
  bool affectsLatest(LocalDate week) {
    final l = latest;
    return l == null || week >= l.week;
  }

  /// F07-R2: các tuần ghi được, mới → cũ: từ tuần hiện tại về tuần thiết lập.
  static List<LocalDate> weeks({
    required LocalDate setupDate,
    required LocalDate today,
  }) {
    final first = WeightRules.weekKey(setupDate);
    return [
      for (var w = WeightRules.weekKey(today); w >= first; w = w.addDays(-7)) w,
    ];
  }

  /// F07-R2: ghi được cho tuần [week]: không trước tuần thiết lập, không
  /// tuần tương lai.
  static bool canLog(
    LocalDate week, {
    required LocalDate setupDate,
    required LocalDate today,
  }) =>
      WeightRules.isWeekKey(week) &&
      week >= WeightRules.weekKey(setupDate) &&
      !WeightRules.isFutureWeek(week, today);
}

/// Lý do không ghi, sửa hoặc xóa được số cân (F07-R2, R3, V1).
enum WeightError {
  /// F07-R2: tuần trước tuần thiết lập hoặc tuần tương lai.
  invalidWeek,

  /// F07-V1: ngoài 30–250 kg.
  outOfRange,

  /// F07-R3: số cân duy nhất còn lại.
  onlyOne,
}

final class WeightException implements Exception {
  const WeightException(this.error);

  final WeightError error;

  @override
  String toString() => 'WeightException(${error.name})';
}
