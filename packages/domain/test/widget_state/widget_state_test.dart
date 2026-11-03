import 'package:domain/domain.dart';
import 'package:test/test.dart';

/// 06 Bản 3 VS39-T08 (domain): F24-AC1 → AC5, AC7, F24-E1 → E4, F24-R4,
/// FA3-10, TAC3-09 phần dữ liệu.
void main() {
  // T2 Ngực + Tay sau, T3 Lưng, T5 Vai, T6 Chân, đều 18:00: 4 buổi/tuần.
  final template = WeeklyTemplate({
    1: TemplateDay(
      enabled: true,
      time: LocalTime(18, 0),
      muscles: const [MuscleGroup.chest, MuscleGroup.triceps],
    ),
    2: TemplateDay(
      enabled: true,
      time: LocalTime(18, 0),
      muscles: const [MuscleGroup.back],
    ),
    4: TemplateDay(
      enabled: true,
      time: LocalTime(18, 0),
      muscles: const [MuscleGroup.shoulders],
    ),
    5: TemplateDay(
      enabled: true,
      time: LocalTime(18, 0),
      muscles: const [MuscleGroup.legs],
    ),
  });
  final oct = {YearMonth(2026, 10)};

  /// Lịch tháng 10 chia lúc 08:00 [setup] (mặc định 01/10).
  List<PlanDay> october([LocalDate? setup]) => MonthGenerator.first(
    template,
    (setup ?? LocalDate(2026, 10, 1)).atTime(LocalTime(8, 0)),
  ).days;

  List<PlanDay> mark(List<PlanDay> days, Map<int, DayMark> marks) => [
    for (final d in days)
      if (marks[d.date.day] case final m? when d.date.month == 10)
        d.withMark(
          m,
          actual: d.muscles,
          markedAt: d.date.atTime(LocalTime(19, 0)),
        )
      else
        d,
  ];

  WidgetState at(DateTime now, List<PlanDay> days) =>
      WidgetState.of(now: now, days: days, planned: oct, template: template);

  Map<String, Object?> json(WidgetDay d) => d.toJson();

  test('F24-AC1, F24-E1: thứ 3 lịch Lưng 18:00 chưa đánh dấu, tuần đã tập '
      '1/4 → "Thứ 3 · Lưng · Chưa tập 18:00 · 1/4"', () {
    final s = at(
      DateTime(2026, 10, 13, 10),
      mark(october(), {12: DayMark.done}),
    );
    expect(s.signedIn, isTrue);
    expect(s.hasSchedule, isTrue);
    expect(s.days, hasLength(8));
    expect(json(s.days.first), {
      'date': '2026-10-13',
      'weekday': 'Thứ 3',
      'kind': 'workout',
      'groups': ['Lưng'],
      'time': '18:00',
      'mark': null,
      'extra': false,
      'paused': false,
      'week': {
        'total': 4,
        'done': 1,
        'extra': 0,
        // Schema 2 (TD5-16): chấm hôm nay ghi thẳng trong file.
        'dots': ['done', 'today', 'pending', 'pending'],
      },
    });
  });

  test('F24-AC2: "Đã tập" → mark done, 2/4', () {
    final s = at(
      DateTime(2026, 10, 13, 19, 30),
      mark(october(), {12: DayMark.done, 13: DayMark.done}),
    );
    final today = json(s.days.first);
    expect(today['mark'], 'done');
    expect(today['week'], {
      'total': 4,
      'done': 2,
      'extra': 0,
      'dots': ['done', 'done', 'pending', 'pending'],
    });
  });

  test('"Không tập" → mark skipped; không tính vào X', () {
    final s = at(
      DateTime(2026, 10, 13, 19, 30),
      mark(october(), {12: DayMark.done, 13: DayMark.skipped}),
    );
    expect(s.days.first.mark, DayMark.skipped);
    expect(s.days.first.week.done, 1);
  });

  test('F24-AC3, F24-E3: ngày nghỉ → rest, 2/4; có buổi tập thêm → extra, '
      '"2/4 +1"', () {
    var days = mark(october(), {12: DayMark.done, 13: DayMark.done});
    var s = at(DateTime(2026, 10, 14, 10), days);
    expect(json(s.days.first), containsPair('kind', 'rest'));
    expect(s.days.first.groups, isEmpty);
    expect(s.days.first.extra, isFalse);
    expect(s.days.first.week.done, 2);
    days = [
      for (final d in days)
        d.date == LocalDate(2026, 10, 14)
            ? d.withExtra(const [
                MuscleGroup.abs,
              ], loggedAt: DateTime(2026, 10, 14, 9))
            : d,
    ];
    s = at(DateTime(2026, 10, 14, 10), days);
    expect(s.days.first.extra, isTrue);
    expect(s.days.first.week.toJson(), {
      'total': 4,
      'done': 2,
      'extra': 1,
      'dots': ['done', 'done', 'pending', 'pending'],
    });
  });

  test('F24-AC4: chưa có lịch → hasSchedule false, không có ngày', () {
    final s = WidgetState.of(
      now: DateTime(2026, 10, 13, 10),
      days: const [],
      planned: const {},
      template: null,
    );
    expect(s.toJson(), containsPair('hasSchedule', false));
    expect(s.toJson(), containsPair('signedIn', true));
    // Chỉ ngày và tên thứ cho dòng "Ironly · Thứ 3".
    expect(s.days, hasLength(8));
    expect(json(s.days.first), containsPair('weekday', 'Thứ 3'));
    expect(s.days.first.groups, isEmpty);
  });

  test('F24-AC5: đăng xuất → signedIn false', () {
    final s = WidgetState.signedOut(DateTime(2026, 10, 13, 10));
    expect(s.toJson(), containsPair('signedIn', false));
    expect(
      [for (final d in s.days) json(d)['weekday']],
      [
        'Thứ 3',
        'Thứ 4',
        'Thứ 5',
        'Thứ 6',
        'Thứ 7',
        'Chủ nhật',
        'Thứ 2',
        'Thứ 3',
      ],
    );
    expect(s.days.first.week.total, 0);
  });

  test('F24-AC7, TAC3-09: 8 ngày ghi sẵn — ngày mai là nội dung ngày mới; '
      'chủ nhật nghỉ với tiến độ tuần vừa qua; thứ 2 tuần mới 0/4', () {
    final s = at(
      DateTime(2026, 10, 16, 20),
      mark(october(), {12: DayMark.done, 13: DayMark.done, 15: DayMark.done}),
    );
    expect(
      [for (final d in s.days) d.date.day],
      [16, 17, 18, 19, 20, 21, 22, 23],
    );
    final sat = json(s.days[1]);
    expect(sat['weekday'], 'Thứ 7');
    expect(sat['kind'], 'rest');
    final sun = s.days[2];
    expect(VietnameseLabels.weekday(sun.date), 'Chủ nhật');
    expect(sun.kind, DayKind.rest);
    expect(sun.week.done, s.days.first.week.done, reason: 'tuần vừa kết thúc');
    final monday = json(s.days[3]);
    expect(monday['groups'], ['Ngực', 'Tay sau'], reason: 'F24-R4: " + "');
    expect(monday['mark'], isNull);
    expect(monday['week'], {
      'total': 4,
      'done': 0,
      'extra': 0,
      'dots': ['today', 'pending', 'pending', 'pending'],
    });
  });

  test('ngày tương lai: mark luôn null, tiến độ như hôm nay', () {
    final s = at(
      DateTime(2026, 10, 12, 19),
      mark(october(), {12: DayMark.done}),
    );
    expect(s.days.first.mark, DayMark.done);
    final tuesday = s.days[1];
    expect(tuesday.mark, isNull);
    expect(tuesday.week.done, 1);
  });

  test('F24-E2: sửa riêng hôm nay từ Lưng sang Vai → "Vai"', () {
    final days = [
      for (final d in october())
        d.date == LocalDate(2026, 10, 13)
            ? PlanDay(
                date: d.date,
                kind: DayKind.workout,
                time: LocalTime(17, 30),
                muscles: const [MuscleGroup.shoulders],
                source: DaySource.override,
              )
            : d,
    ];
    final today = json(at(DateTime(2026, 10, 13, 10), days).days.first);
    expect(today['groups'], ['Vai']);
    expect(today['time'], '17:30');
  });

  test('F24-E4: xếp lịch lần đầu giữa tuần → Y đếm từ ngày lưu lịch', () {
    final s = at(DateTime(2026, 10, 14, 10), october(LocalDate(2026, 10, 14)));
    expect(s.days.first.week.total, 2, reason: 'thứ 5, thứ 6');
  });

  test('ngày thuộc tháng chưa chia lịch suy ra từ lịch tuần', () {
    final s = at(DateTime(2026, 10, 28, 10), october());
    final nov2 = s.days.firstWhere((d) => d.date == LocalDate(2026, 11, 2));
    expect(nov2.kind, DayKind.workout);
    expect(nov2.groups, [MuscleGroup.chest, MuscleGroup.triceps]);
  });

  test('JSON theo 05 Bản 3 §6.8.1, Bản 5 §6.8: schema 2, generatedAt kèm '
      'múi giờ, range đủ để tính', () {
    final s = at(DateTime(2026, 10, 13, 10), october());
    final j = s.toJson();
    expect(j['schema'], 2);
    expect(
      j['generatedAt'],
      matches(RegExp(r'^2026-10-13T10:00:00[+-]\d\d:\d\d$')),
    );
    expect(WidgetState.range(LocalDate(2026, 10, 18)), (
      LocalDate(2026, 10, 12),
      LocalDate(2026, 10, 25),
    ));
  });

  group('Bản 5 — tạm dừng (F24-R61 → R64, TD5-16)', () {
    SchedulePause pause(int from, int to) => SchedulePause(
      id: 'p',
      startDate: LocalDate(2026, 10, from),
      endDate: LocalDate(2026, 10, to),
    );

    WidgetState paused(DateTime now, List<PlanDay> days, SchedulePause p) =>
        WidgetState.of(
          now: now,
          days: days,
          planned: oct,
          template: template,
          pauses: [p],
        );

    test('F24-AC61: tạm dừng hôm nay (thứ 3 Lưng) → "Lưng" + tạm dừng, '
        'không chấm hôm nay; tiến độ trừ buổi tạm dừng', () {
      // Tuần: T2 Ngực + Tay sau (đã tập), T3 Lưng, T5 Vai, T6 Chân; tạm dừng
      // T3 → CN.
      final s = paused(
        DateTime(2026, 10, 13, 10),
        mark(october(), {12: DayMark.done}),
        pause(13, 18),
      );
      expect(json(s.days.first), {
        'date': '2026-10-13',
        'weekday': 'Thứ 3',
        'kind': 'workout',
        'groups': ['Lưng'],
        'time': '18:00',
        'mark': null,
        'extra': false,
        'paused': true,
        'week': {
          'total': 1,
          'done': 1,
          'extra': 0,
          'dots': ['done', 'paused', 'paused', 'paused'],
        },
      });
      // Ngày nghỉ trong khoảng (T4): "Nghỉ" + tạm dừng.
      final wed = json(s.days[1]);
      expect(wed['kind'], 'rest');
      expect(wed['paused'], isTrue);
      // Ngày sau khoảng (T2 tuần sau): bình thường, chấm hôm nay của ngày đó.
      final nextMonday = json(s.days[6]);
      expect(nextMonday['paused'], isFalse);
      expect((nextMonday['week']! as Map)['dots'], [
        'today',
        'pending',
        'pending',
        'pending',
      ]);
    });

    test('F24-R62, A5-06: buổi trong khoảng đã "Đã tập" → Đã tập như thường, '
        'tính vào X và Y', () {
      final s = paused(
        DateTime(2026, 10, 13, 19),
        mark(october(), {12: DayMark.done, 13: DayMark.done}),
        pause(13, 18),
      );
      final today = json(s.days.first);
      expect(today['mark'], 'done');
      expect(today['paused'], isFalse);
      expect(today['week'], {
        'total': 2,
        'done': 2,
        'extra': 0,
        'dots': ['done', 'done', 'paused', 'paused'],
      });
    });

    test('"Không tập" trong khoảng (Bạn chủ động) → không phải tạm dừng, '
        'tính vào Y (F06-R61)', () {
      final s = paused(
        DateTime(2026, 10, 13, 19),
        mark(october(), {12: DayMark.done, 13: DayMark.skipped}),
        pause(13, 18),
      );
      final today = json(s.days.first);
      expect(today['mark'], 'skipped');
      expect(today['paused'], isFalse);
      expect((today['week']! as Map)['total'], 2);
      expect((today['week']! as Map)['dots'], [
        'done',
        'pending',
        'paused',
        'paused',
      ]);
    });

    test('F06-R62: tạm dừng cả tuần → total 0, mọi chấm tạm dừng', () {
      final s = paused(DateTime(2026, 10, 12, 10), october(), pause(12, 18));
      expect(s.days.first.week.total, 0);
      expect(s.days.first.week.toJson()['dots'], [
        'paused',
        'paused',
        'paused',
        'paused',
      ]);
    });

    test('F24-R64: file không có mức thoải mái, bài thay / thêm', () {
      final j = paused(
        DateTime(2026, 10, 13, 10),
        october(),
        pause(13, 13),
      ).toJson().toString();
      for (final word in ['feel', 'replacement', 'extraExercise', 'skipped:']) {
        expect(j, isNot(contains(word)));
      }
    });
  });
}
