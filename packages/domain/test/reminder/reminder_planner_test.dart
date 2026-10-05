import 'package:domain/domain.dart';
import 'package:test/test.dart';

void main() {
  final t1800 = LocalTime(18, 0);
  final template = WeeklyTemplate({
    1: TemplateDay(
      enabled: true,
      time: t1800,
      muscles: const [MuscleGroup.chest],
    ),
    3: TemplateDay(
      enabled: true,
      time: t1800,
      muscles: const [MuscleGroup.back],
    ),
  });

  List<PlanDay> month(YearMonth m) =>
      MonthGenerator.month(template, m, DateTime(m.year, m.month)).days;

  test('F04-AC1, F04-R2: buổi Ngực 18:00 → nhắc lúc 17:00 cùng ngày', () {
    final r = ReminderPlanner.plan(
      currentMonth: month(YearMonth(2026, 10)),
      nextMonth: null,
      template: template,
      now: DateTime(2026, 10, 5, 8),
    );
    expect(r.first.at, DateTime(2026, 10, 5, 17));
    expect(r.first.date, LocalDate(2026, 10, 5));
    expect(r.first.muscles, [MuscleGroup.chest]);
    expect(r.first.isTomorrow, isFalse);
    expect(r.first.id, 20261005);
  });

  test(
    'F04-R6: chỉ nhắc buổi còn kịp thời điểm nhắc; ngày đã qua không nhắc',
    () {
      final r = ReminderPlanner.plan(
        currentMonth: month(YearMonth(2026, 10)),
        nextMonth: null,
        template: template,
        now: DateTime(2026, 10, 5, 17, 30),
      );
      expect(
        r.first.date,
        LocalDate(2026, 10, 7),
        reason: '17:00 hôm nay đã qua',
      );
    },
  );

  test('F04-AC4: đổi giờ 18:00 → 19:00 trước 17:00 → nhắc lúc 18:00', () {
    final days = month(YearMonth(2026, 10));
    final i = days.indexWhere((d) => d.date == LocalDate(2026, 10, 5));
    days[i] = PlanDay(
      date: days[i].date,
      kind: DayKind.workout,
      time: LocalTime(19, 0),
      muscles: days[i].muscles,
      source: DaySource.override,
    );
    final r = ReminderPlanner.plan(
      currentMonth: days,
      nextMonth: null,
      template: template,
      now: DateTime(2026, 10, 5, 16),
    );
    expect(r.first.at, DateTime(2026, 10, 5, 18));
    expect(r.where((x) => x.at == DateTime(2026, 10, 5, 17)), isEmpty);
  });

  test('F04-E1: giờ tập 00:30 → nhắc 23:30 hôm trước, "ngày mai"', () {
    final early = PlanDay(
      date: LocalDate(2026, 10, 6),
      kind: DayKind.workout,
      time: LocalTime(0, 30),
      muscles: const [MuscleGroup.abs],
    );
    final r = ReminderPlanner.plan(
      currentMonth: [early],
      nextMonth: const [],
      template: null,
      now: DateTime(2026, 10, 5, 12),
    );
    expect(r.single.at, DateTime(2026, 10, 5, 23, 30));
    expect(r.single.isTomorrow, isTrue);
  });

  test('F04-E4, F04-R4: ngày nghỉ (kể cả có buổi tập thêm) không nhắc; buổi '
      'đã đánh dấu không nhắc', () {
    final r = ReminderPlanner.plan(
      currentMonth: [
        PlanDay(
          date: LocalDate(2026, 10, 6),
          kind: DayKind.rest,
          extraMuscles: const [MuscleGroup.abs],
        ),
        PlanDay(
          date: LocalDate(2026, 10, 7),
          kind: DayKind.workout,
          time: t1800,
          muscles: const [MuscleGroup.back],
          mark: DayMark.skipped,
        ),
      ],
      nextMonth: const [],
      template: null,
      now: DateTime(2026, 10, 5, 12),
    );
    expect(r, isEmpty);
  });

  test('TAC-09: tháng sau chưa được tạo → nhắc những ngày đầu tháng sau suy '
      'ra từ lịch tuần', () {
    final r = ReminderPlanner.plan(
      currentMonth: month(YearMonth(2026, 10)),
      nextMonth: null,
      template: template,
      now: DateTime(2026, 10, 28, 20),
    );
    expect(
      [for (final x in r.take(3)) x.date],
      [LocalDate(2026, 11, 2), LocalDate(2026, 11, 4), LocalDate(2026, 11, 9)],
    );
    // Tháng sau đã có (ví dụ máy khác đã tạo) thì dùng đúng lịch đó.
    final created = [
      PlanDay(
        date: LocalDate(2026, 11, 3),
        kind: DayKind.workout,
        time: LocalTime(7, 0),
        muscles: const [MuscleGroup.abs],
        source: DaySource.override,
      ),
    ];
    final r2 = ReminderPlanner.plan(
      currentMonth: month(YearMonth(2026, 10)),
      nextMonth: created,
      template: template,
      now: DateTime(2026, 10, 28, 20),
    );
    expect([for (final x in r2) x.date], [LocalDate(2026, 11, 3)]);
  });

  test('TR-10: tối đa 60 nhắc, theo thứ tự thời gian', () {
    final daily = WeeklyTemplate({
      for (var w = 1; w <= 6; w++)
        w: TemplateDay(
          enabled: true,
          time: t1800,
          muscles: const [MuscleGroup.chest],
        ),
    });
    final r = ReminderPlanner.plan(
      currentMonth: MonthGenerator.month(
        daily,
        YearMonth(2026, 10),
        DateTime(2026, 10),
      ).days,
      nextMonth: MonthGenerator.month(
        daily,
        YearMonth(2026, 11),
        DateTime(2026, 11),
      ).days,
      template: daily,
      now: DateTime(2026, 10, 1, 8),
    );
    expect(r, hasLength(52), reason: '27 ngày tháng 10 + 25 ngày tháng 11');
    final more = ReminderPlanner.plan(
      currentMonth: [
        for (var i = 0; i < 70; i++)
          PlanDay(
            date: LocalDate(2026, 10, 1).addDays(i),
            kind: DayKind.workout,
            time: t1800,
            muscles: const [MuscleGroup.chest],
          ),
      ],
      nextMonth: const [],
      template: null,
      now: DateTime(2026, 10, 1, 8),
    );
    expect(more, hasLength(ReminderPlanner.limit));
    for (var i = 1; i < more.length; i++) {
      expect(more[i].at.isAfter(more[i - 1].at), isTrue);
    }
  });
}
