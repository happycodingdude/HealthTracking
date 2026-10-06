import '../time/local_date.dart';
import '../time/local_time.dart';
import '../time/year_month.dart';
import 'weekly_template.dart';

enum DayKind { workout, rest }

/// "Theo lịch tuần" hoặc "Đã sửa riêng".
enum DaySource { template, override }

/// Đánh dấu của Bạn (F-05). "Không tập (tự động)" không lưu (AP-2).
enum DayMark { done, skipped }

/// Một ngày thứ 2 → thứ 7 trong lịch tháng (entity `day`, 05 §6.7.3).
final class PlanDay {
  const PlanDay({
    required this.date,
    required this.kind,
    this.time,
    this.muscles = const [],
    this.source = DaySource.template,
    this.mark,
    this.actualMuscles,
    this.markedAt,
    this.extraMuscles,
    this.extraLoggedAt,
  });

  /// Ngày theo lịch tuần (F03-R4): thứ không tập là ngày nghỉ.
  factory PlanDay.fromTemplate(LocalDate date, TemplateDay t) => t.enabled
      ? PlanDay(
          date: date,
          kind: DayKind.workout,
          time: t.time,
          muscles: MuscleGroup.ordered(t.muscles),
        )
      : PlanDay(date: date, kind: DayKind.rest);

  final LocalDate date;
  final DayKind kind;

  /// Chỉ với ngày tập.
  final LocalTime? time;
  final List<MuscleGroup> muscles;
  final DaySource source;
  final DayMark? mark;
  final List<MuscleGroup>? actualMuscles;
  final DateTime? markedAt;

  /// Buổi tập thêm (chỉ ngày nghỉ).
  final List<MuscleGroup>? extraMuscles;
  final DateTime? extraLoggedAt;

  bool get isWorkout => kind == DayKind.workout;

  /// Bản ghi với đánh dấu mới; các trường khác giữ nguyên.
  PlanDay withMark(
    DayMark? mark, {
    List<MuscleGroup>? actual,
    DateTime? markedAt,
  }) => PlanDay(
    date: date,
    kind: kind,
    time: time,
    muscles: muscles,
    source: source,
    mark: mark,
    actualMuscles: actual,
    markedAt: markedAt,
    extraMuscles: extraMuscles,
    extraLoggedAt: extraLoggedAt,
  );

  /// Ràng buộc của bản ghi (05 §6.7.3): không có chủ nhật; ngày tập có giờ và
  /// ≥ 1 nhóm cơ, ngày nghỉ không có; buổi tập thêm chỉ ở ngày nghỉ; đánh dấu
  /// chỉ ở ngày tập, "Đã tập" có ≥ 1 nhóm cơ thực tế (F05-R4, F05-R5), có
  /// đánh dấu thì có thời điểm đánh dấu. Trả tên trường sai, null = hợp lệ.
  String? get invalidField {
    if (date.isSunday) return 'key';
    if (isWorkout) {
      if (time == null) return 'time';
      if (muscles.isEmpty) return 'muscles';
      if (extraMuscles != null || extraLoggedAt != null) return 'extraMuscles';
      final actual = actualMuscles;
      if ((mark == DayMark.done) != (actual != null && actual.isNotEmpty) ||
          (mark != DayMark.done && actual != null)) {
        return 'actualMuscles';
      }
      if ((mark == null) != (markedAt == null)) return 'markedAt';
    } else {
      if (time != null) return 'time';
      if (muscles.isNotEmpty) return 'muscles';
      if (mark != null || actualMuscles != null || markedAt != null) {
        return 'mark';
      }
      if (extraMuscles != null && extraMuscles!.isEmpty) return 'extraMuscles';
    }
    return null;
  }

  @override
  bool operator ==(Object other) =>
      other is PlanDay &&
      other.date == date &&
      other.kind == kind &&
      other.time == time &&
      _same(other.muscles, muscles) &&
      other.source == source &&
      other.mark == mark &&
      _same(other.actualMuscles, actualMuscles) &&
      _sameInstant(other.markedAt, markedAt) &&
      _same(other.extraMuscles, extraMuscles) &&
      _sameInstant(other.extraLoggedAt, extraLoggedAt);

  @override
  int get hashCode => Object.hash(
    date,
    kind,
    time,
    Object.hashAll(muscles),
    source,
    mark,
    markedAt?.millisecondsSinceEpoch,
    extraLoggedAt?.millisecondsSinceEpoch,
  );

  @override
  String toString() =>
      'PlanDay($date, ${kind.name}, $time, ${muscles.map((m) => m.name)})';
}

/// Cùng thời điểm, không phân biệt giờ UTC hay giờ máy.
bool _sameInstant(DateTime? a, DateTime? b) =>
    a == null || b == null ? a == b : a.isAtSameMomentAs(b);

bool _same<T>(List<T>? a, List<T>? b) {
  if (a == null || b == null) return a == b;
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

/// Lịch tháng (entity `month_plan`, key `YYYY-MM`).
final class MonthPlan {
  const MonthPlan({
    required this.month,
    required this.startDate,
    required this.templateHash,
    required this.generatedAt,
    this.redistributedAt,
  });

  final YearMonth month;

  /// Ngày đầu tiên của lịch: ngày thiết lập (tháng đầu) hoặc ngày 1.
  final LocalDate startDate;

  /// `contentHash` của lịch tuần đã dùng (F03-R7).
  final String templateHash;
  final DateTime generatedAt;
  final DateTime? redistributedAt;

  @override
  bool operator ==(Object other) =>
      other is MonthPlan &&
      other.month == month &&
      other.startDate == startDate &&
      other.templateHash == templateHash &&
      _sameInstant(other.generatedAt, generatedAt) &&
      _sameInstant(other.redistributedAt, redistributedAt);

  @override
  int get hashCode => Object.hash(
    month,
    startDate,
    templateHash,
    generatedAt.millisecondsSinceEpoch,
    redistributedAt?.millisecondsSinceEpoch,
  );
}

/// Lịch tháng được chia từ lịch tuần.
typedef GeneratedMonth = ({MonthPlan plan, List<PlanDay> days});

/// Chia lịch tuần ra từng ngày của tháng (F03-R5, F03-R6). Không bao giờ có
/// chủ nhật (F03-R1).
abstract final class MonthGenerator {
  /// Lần đầu lưu lịch tuần lúc [now] (F03-R5): từ hôm nay đến cuối tháng. Buổi
  /// của hôm nay chỉ có nếu giờ tập còn sau [now]; nếu đã qua thì hôm nay là
  /// ngày nghỉ (F03-AC3).
  static GeneratedMonth first(WeeklyTemplate template, DateTime now) {
    final today = LocalDate.fromDateTime(now);
    final days = _days(template, today, today.yearMonth.lastDay);
    if (days.isNotEmpty && days.first.date == today) {
      final d = days.first;
      if (d.isWorkout && !today.atTime(d.time!).isAfter(now)) {
        days[0] = PlanDay(date: today, kind: DayKind.rest);
      }
    }
    return (
      plan: MonthPlan(
        month: today.yearMonth,
        startDate: today,
        templateHash: template.contentHash,
        generatedAt: now,
      ),
      days: days,
    );
  }

  /// Tháng mới (F03-R6): cả tháng theo lịch tuần hiện tại.
  static GeneratedMonth month(
    WeeklyTemplate template,
    YearMonth month,
    DateTime now,
  ) => (
    plan: MonthPlan(
      month: month,
      startDate: month.firstDay,
      templateHash: template.contentHash,
      generatedAt: now,
    ),
    days: _days(template, month.firstDay, month.lastDay),
  );

  static List<PlanDay> _days(
    WeeklyTemplate template,
    LocalDate from,
    LocalDate to,
  ) => [
    for (var d = from; d <= to; d = d.addDays(1))
      if (!d.isSunday) PlanDay.fromTemplate(d, template.day(d.weekday)),
  ];
}
