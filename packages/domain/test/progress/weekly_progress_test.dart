import 'package:domain/domain.dart';
import 'package:test/test.dart';

void main() {
  // T2 Ngực + Tay sau, T4 Lưng, T6 Vai, đều 18:00.
  final template = WeeklyTemplate({
    1: TemplateDay(
      enabled: true,
      time: LocalTime(18, 0),
      muscles: const [MuscleGroup.chest, MuscleGroup.triceps],
    ),
    3: TemplateDay(
      enabled: true,
      time: LocalTime(18, 0),
      muscles: const [MuscleGroup.back],
    ),
    5: TemplateDay(
      enabled: true,
      time: LocalTime(18, 0),
      muscles: const [MuscleGroup.shoulders],
    ),
  });

  /// Lịch tháng 10 chia lúc 08:00 thứ 2 05/10.
  final october = MonthGenerator.first(template, DateTime(2026, 10, 5, 8));
  final week = ProgressWeek.containing(LocalDate(2026, 10, 5));
  final oct = {YearMonth(2026, 10)};

  PlanDay day(int d) =>
      october.days.firstWhere((x) => x.date == LocalDate(2026, 10, d));

  PlanDay done(int d) => day(d).withMark(
    DayMark.done,
    actual: day(d).muscles,
    markedAt: DateTime(2026, 10, d, 19),
  );

  WeeklyProgress compute(
    List<PlanDay> days,
    DateTime now, {
    ProgressWeek? w,
    Set<YearMonth>? planned,
  }) => WeeklyProgress.compute(
    w ?? week,
    days: days,
    planned: planned ?? oct,
    template: template,
    now: now,
  );

  test('F06-AC1, F06-R4: 3 buổi, đã tập 2, 1 chưa đến giờ → 2/3', () {
    final p = compute([
      done(5),
      day(6),
      done(7),
      day(8),
      day(9),
      day(10),
    ], DateTime(2026, 10, 9, 12));
    expect((p.done, p.planned, p.extra), (2, 3, 0));
    expect(p.days.map((d) => d.status?.state), [
      SessionState.done,
      null,
      SessionState.done,
      null,
      SessionState.upcoming,
      null,
    ]);
  });

  test('F06-AC2, F05-AC5, F05-R12: thêm buổi tập thêm thứ 7 → +1, dòng chính '
      'không đổi', () {
    final sat = day(
      10,
    ).withExtra(const [MuscleGroup.abs], loggedAt: DateTime(2026, 10, 10, 9));
    final p = compute([
      done(5),
      day(6),
      done(7),
      day(8),
      day(9),
      sat,
    ], DateTime(2026, 10, 10, 10));
    expect((p.done, p.planned, p.extra), (2, 3, 1));
    expect(p.days.last.extra, [MuscleGroup.abs]);
  });

  test('F06-AC3, F05-E2: tuần trước "Không tập (tự động)" sửa thành "Đã tập" '
      '→ tiến độ tuần trước tăng 1', () {
    final now = DateTime(2026, 10, 13, 9);
    final before = compute([day(5), day(7), day(9)], now);
    expect(before.days.first.status?.state, SessionState.autoSkipped);
    expect((before.done, before.planned), (0, 3));
    final after = compute([done(5), day(7), day(9)], now);
    expect((after.done, after.planned), (1, 3));
  });

  test('F06-E2: tuần đầu chỉ tính từ lúc thiết lập', () {
    // Thiết lập 12:00 thứ 4 07/10: thứ 2 05/10 chưa có lịch.
    final g = MonthGenerator.first(template, DateTime(2026, 10, 7, 12));
    final p = compute(g.days, DateTime(2026, 10, 7, 13));
    expect(p.days.first.day, isNull);
    expect((p.done, p.planned), (0, 2), reason: 'thứ 4, thứ 6');
  });

  test(
    'F06-E1: tuần không có buổi theo lịch → Y = 0, buổi tập thêm vẫn đếm',
    () {
      // Tuần mà Bạn cho nghỉ hết (sửa riêng).
      final rest = [
        for (final d in week.days)
          PlanDay(date: d, kind: DayKind.rest, source: DaySource.override),
      ];
      final mon = rest.first.withExtra(const [
        MuscleGroup.back,
      ], loggedAt: DateTime(2026, 10, 5, 20));
      final p = compute([mon, ...rest.skip(1)], DateTime(2026, 10, 5, 21));
      expect((p.done, p.planned, p.extra), (0, 0, 1));
    },
  );

  group('F06-AC5, F06-E4: tuần nằm giữa hai tháng', () {
    test('26/10 – 31/10 nằm trọn trong tháng 10', () {
      final w = ProgressWeek.containing(LocalDate(2026, 10, 26));
      final p = compute(october.days, DateTime(2026, 10, 26, 9), w: w);
      expect(p.days.first.date, LocalDate(2026, 10, 26));
      expect(p.days.last.date, LocalDate(2026, 10, 31));
      expect(p.planned, 3);
    });

    test('tuần từ 02/11 lấy lịch tháng 11 (kể cả ngày sửa riêng)', () {
      final nov = MonthGenerator.month(
        template,
        YearMonth(2026, 11),
        DateTime(2026, 11, 1),
      );
      // Sửa riêng thứ 3 03/11 thành ngày tập.
      final tue = PlanDay(
        date: LocalDate(2026, 11, 3),
        kind: DayKind.workout,
        time: LocalTime(7, 0),
        muscles: const [MuscleGroup.abs],
        source: DaySource.override,
      );
      final w = ProgressWeek.containing(LocalDate(2026, 11, 2));
      final p = compute(
        [
          for (final d in nov.days) d.date == tue.date ? tue : d,
          ...october.days,
        ],
        DateTime(2026, 11, 2, 9),
        w: w,
        planned: {YearMonth(2026, 10), YearMonth(2026, 11)},
      );
      expect(p.planned, 4);
      expect(p.days[1].day!.source, DaySource.override);
    });

    test('tuần 30/11 – 05/12 trước 01/12: tháng 12 chưa có lịch → suy ra từ '
        'lịch tuần', () {
      final nov = MonthGenerator.month(
        template,
        YearMonth(2026, 11),
        DateTime(2026, 11, 1),
      );
      final w = ProgressWeek.containing(LocalDate(2026, 11, 30));
      final p = compute(
        nov.days,
        DateTime(2026, 11, 30, 9),
        w: w,
        planned: {YearMonth(2026, 10), YearMonth(2026, 11)},
      );
      expect(p.planned, 3, reason: 'thứ 2 30/11, thứ 4 02/12, thứ 6 04/12');
      expect(p.days[2].status?.state, SessionState.upcoming);
    });
  });

  group('F06-R5, F06-AC4, F06-E3: danh sách tuần', () {
    test(
      'từ tuần thiết lập đến tuần hiện tại; không có tuần trước thiết lập',
      () {
        final weeks = WeeklyProgress.weeks(
          setupDate: LocalDate(2026, 10, 7),
          today: LocalDate(2026, 10, 21),
        );
        expect(weeks.map((w) => w.start), [
          LocalDate(2026, 10, 5),
          LocalDate(2026, 10, 12),
          LocalDate(2026, 10, 19),
        ]);
      },
    );

    test('chủ nhật thuộc tuần vừa kết thúc; thiết lập chủ nhật → tuần đầu là '
        'tuần sau', () {
      expect(
        WeeklyProgress.weeks(
          setupDate: LocalDate(2026, 10, 7),
          today: LocalDate(2026, 10, 11),
        ).map((w) => w.start),
        [LocalDate(2026, 10, 5)],
      );
      expect(
        WeeklyProgress.weeks(
          setupDate: LocalDate(2026, 10, 11),
          today: LocalDate(2026, 10, 11),
        ).map((w) => w.start),
        [LocalDate(2026, 10, 12)],
      );
    });
  });
}
