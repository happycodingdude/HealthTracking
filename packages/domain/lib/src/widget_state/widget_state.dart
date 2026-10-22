import '../progress/weekly_progress.dart';
import '../schedule/month_plan.dart';
import '../schedule/weekly_template.dart';
import '../time/local_date.dart';
import '../time/local_time.dart';
import '../time/week.dart';
import '../time/year_month.dart';

/// Tên tiếng Việt dùng ngoài app (widget, thẻ màn hình khóa): Swift và server
/// không có bảng dịch riêng (05 Bản 3 §6.8.1, 06 Bản 3 ED3-07). Trùng câu chữ
/// của app (`Fmt.muscle`, `S.weekdays`), có test đối chiếu.
abstract final class VietnameseLabels {
  static String muscle(MuscleGroup m) => switch (m) {
    MuscleGroup.chest => 'Ngực',
    MuscleGroup.triceps => 'Tay sau',
    MuscleGroup.shoulders => 'Vai',
    MuscleGroup.abs => 'Bụng',
    MuscleGroup.back => 'Lưng',
    MuscleGroup.biceps => 'Tay trước',
    MuscleGroup.legs => 'Chân',
  };

  static const weekdays = [
    'Thứ 2',
    'Thứ 3',
    'Thứ 4',
    'Thứ 5',
    'Thứ 6',
    'Thứ 7',
    'Chủ nhật',
  ];

  static String weekday(LocalDate date) => weekdays[date.weekday - 1];
}

/// Tiến độ tuần trên widget (FA3-10): đúng con số của màn hình Hôm nay.
final class WidgetWeek {
  const WidgetWeek({
    required this.total,
    required this.done,
    required this.extra,
    required this.dots,
  });

  factory WidgetWeek.of(WeeklyProgress p) => WidgetWeek(
    total: p.planned,
    done: p.done,
    extra: p.extra,
    dots: [
      for (final d in p.days)
        if (d.status case final s?) s.counts,
    ],
  );

  /// Y: số buổi theo lịch của tuần.
  final int total;

  /// X: số buổi theo lịch "Đã tập".
  final int done;

  /// n trong "+n": số buổi tập thêm.
  final int extra;

  /// Một chấm cho mỗi buổi theo lịch, theo ngày; true = Đã tập.
  final List<bool> dots;

  Map<String, Object?> toJson() => {
    'total': total,
    'done': done,
    'extra': extra,
    'dots': dots,
  };
}

/// Một ngày trong `widget_state.json`.
final class WidgetDay {
  const WidgetDay({
    required this.date,
    required this.kind,
    required this.groups,
    required this.time,
    required this.mark,
    required this.extra,
    required this.week,
  });

  final LocalDate date;

  /// Buổi theo lịch hoặc ngày nghỉ (kể cả chủ nhật).
  final DayKind kind;

  /// Nhóm cơ theo thứ tự trong lịch (F24-R4); rỗng khi nghỉ.
  final List<MuscleGroup> groups;
  final LocalTime? time;

  /// Chỉ hôm nay; ngày tương lai luôn null (05 Bản 3 §6.8.1).
  final DayMark? mark;

  /// Có buổi tập thêm (ngày nghỉ, "+1 buổi thêm").
  final bool extra;
  final WidgetWeek week;

  Map<String, Object?> toJson() => {
    'date': date.toKey(),
    'weekday': VietnameseLabels.weekday(date),
    'kind': kind.name,
    'groups': [for (final g in groups) VietnameseLabels.muscle(g)],
    'time': time?.toKey(),
    'mark': mark?.name,
    'extra': extra,
    'week': week.toJson(),
  };
}

/// Nội dung widget S-70 (05 Bản 3 §6.8.1, TD3-15): hôm nay + 7 ngày, tính
/// sẵn để iPhone tự đổi lúc 00:00 không cần mở app (TR3-10). Swift chỉ vẽ.
final class WidgetState {
  const WidgetState({
    required this.signedIn,
    required this.hasSchedule,
    required this.generatedAt,
    required this.days,
  });

  /// Chưa đăng nhập, đã đăng xuất, phiên hết hạn: "Mở app để đăng nhập".
  /// Vẫn ghi 8 ngày (chỉ có tên thứ) để widget hiện "Ironly · {Thứ}" mà Swift
  /// không tự tính ngày (ED3-07).
  factory WidgetState.signedOut(DateTime now) => WidgetState(
    signedIn: false,
    hasSchedule: false,
    generatedAt: now,
    days: _blankDays(now),
  );

  /// Ngày không có nội dung lịch (đăng xuất, Chưa có lịch): chỉ ngày, thứ.
  static List<WidgetDay> _blankDays(DateTime now) => [
    for (var i = 0; i < 8; i++)
      WidgetDay(
        date: LocalDate.fromDateTime(now).addDays(i),
        kind: DayKind.rest,
        groups: const [],
        time: null,
        mark: null,
        extra: false,
        week: const WidgetWeek(total: 0, done: 0, extra: 0, dots: []),
      ),
  ];

  /// Lúc [now] (giờ trên iPhone). [days]: bản ghi ngày đã có, ít nhất từ thứ
  /// 2 của tuần chứa hôm nay đến hôm nay + 7 ([range]); [planned]: các tháng
  /// đã có lịch; [template] null = Chưa có lịch.
  factory WidgetState.of({
    required DateTime now,
    required List<PlanDay> days,
    required Set<YearMonth> planned,
    required WeeklyTemplate? template,
  }) {
    if (template == null) {
      return WidgetState(
        signedIn: true,
        hasSchedule: false,
        generatedAt: now,
        days: _blankDays(now),
      );
    }
    final today = LocalDate.fromDateTime(now);
    final weeks = <ProgressWeek, WidgetWeek>{};
    WidgetWeek weekOf(LocalDate date) =>
        weeks.putIfAbsent(ProgressWeek.containing(date), () {
          final week = ProgressWeek.containing(date);
          return WidgetWeek.of(
            WeeklyProgress.compute(
              week,
              days: [
                for (final d in days)
                  if (week.contains(d.date)) d,
              ],
              planned: planned,
              template: template,
              now: now,
            ),
          );
        });
    final byDate = {for (final d in days) d.date: d};
    final last = planned.isEmpty
        ? null
        : planned.reduce((a, b) => a.compareTo(b) >= 0 ? a : b);
    // Ngày thuộc tháng chưa chia lịch suy ra từ lịch tuần (như WeeklyProgress).
    PlanDay? dayOf(LocalDate date) {
      if (date.isSunday) return null;
      final d = byDate[date];
      if (d != null) return d;
      if (last == null || date.yearMonth.compareTo(last) <= 0) return null;
      return PlanDay.fromTemplate(date, template.day(date.weekday));
    }

    return WidgetState(
      signedIn: true,
      hasSchedule: true,
      generatedAt: now,
      days: [
        for (var i = 0; i < 8; i++)
          if (today.addDays(i) case final date)
            switch (dayOf(date)) {
              final d? when d.isWorkout => WidgetDay(
                date: date,
                kind: DayKind.workout,
                groups: d.sessionMuscles,
                time: d.time,
                mark: i == 0 ? d.mark : null,
                extra: false,
                week: weekOf(date),
              ),
              final d => WidgetDay(
                date: date,
                kind: DayKind.rest,
                groups: const [],
                time: null,
                mark: null,
                extra: d?.extraMuscles?.isNotEmpty ?? false,
                week: weekOf(date),
              ),
            },
      ],
    );
  }

  static const schema = 1;

  /// Khoảng ngày app cần đọc cho [WidgetState.of] lúc [today]: từ thứ 2 của
  /// tuần chứa hôm nay đến hôm nay + 7.
  static (LocalDate from, LocalDate to) range(LocalDate today) =>
      (ProgressWeek.containing(today).start, today.addDays(7));

  final bool signedIn;
  final bool hasSchedule;
  final DateTime generatedAt;
  final List<WidgetDay> days;

  Map<String, Object?> toJson() => {
    'schema': schema,
    'signedIn': signedIn,
    'hasSchedule': hasSchedule,
    'generatedAt': _withOffset(generatedAt),
    'days': [for (final d in days) d.toJson()],
  };

  /// `2026-11-12T18:41:00+07:00` (giờ trên iPhone kèm múi giờ).
  static String _withOffset(DateTime t) {
    String two(int n) => n.toString().padLeft(2, '0');
    final o = t.timeZoneOffset;
    final sign = o.isNegative ? '-' : '+';
    final m = o.inMinutes.abs();
    return '${t.year.toString().padLeft(4, '0')}-${two(t.month)}-'
        '${two(t.day)}T${two(t.hour)}:${two(t.minute)}:${two(t.second)}'
        '$sign${two(m ~/ 60)}:${two(m % 60)}';
  }
}
