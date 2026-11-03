import 'package:domain/domain.dart';
import 'package:domain/testing.dart';
import 'package:test/test.dart';

/// 03 Bản 5 F-31 (tạm dừng là lớp phủ), F-06 (tiến độ tuần), F-04 (nhắc);
/// 05 Bản 5 TD5-05, TD5-11. Dữ liệu `pauseWeekCases` (06 Bản 5 §6.10.2).
void main() {
  WeeklyProgress progress(
    List<PlanDay> days,
    Iterable<SchedulePause> pauses, {
    DateTime? now,
  }) => WeeklyProgress.compute(
    PauseWeekCases.week,
    days: days,
    planned: {PauseWeekCases.month},
    template: null,
    now: now ?? PauseWeekCases.now,
    pauses: pauses,
  );

  group('F06-AC61, F06-R61, F31-E1: tiến độ tuần trừ buổi tạm dừng', () {
    test('tuần 5 buổi, đã tập 2, tạm dừng 3 → 2 / 2', () {
      final p = progress(PauseWeekCases.days(), [PauseWeekCases.pause]);
      expect((p.done, p.planned, p.paused), (2, 2, 3));
    });

    test('chốt "Đã tập" 1 buổi tạm dừng → 3 / 3', () {
      final p = progress(PauseWeekCases.days(marks: {6: DayMark.done}), [
        PauseWeekCases.pause,
      ]);
      expect((p.done, p.planned), (3, 3));
    });

    test('rồi chốt "Không tập" 1 buổi tạm dừng → 3 / 4', () {
      final p = progress(
        PauseWeekCases.days(marks: {6: DayMark.done, 7: DayMark.skipped}),
        [PauseWeekCases.pause],
      );
      expect((p.done, p.planned), (3, 4));
    });

    test('không tạm dừng: như Bản 1 (2 / 5)', () {
      final p = progress(PauseWeekCases.days(), const []);
      expect((p.done, p.planned, p.paused), (2, 5, 0));
    });
  });

  test('F31-E2, F06-R62: tạm dừng cả tuần, không tập buổi nào → 0 / 0, '
      'đếm được buổi tạm dừng để hiện dấu', () {
    final p = progress(
      PauseWeekCases.days(marks: {2: DayMark.skipped, 3: DayMark.skipped}),
      const [],
    );
    expect(p.planned, 5);
    final whole = progress(
      [
        for (final d in PauseWeekCases.days())
          d.isWorkout ? d.withMark(null) : d,
      ],
      [PauseWeekCases.wholeWeek],
    );
    expect((whole.done, whole.planned, whole.paused), (0, 0, 5));
  });

  group('F31-R3, F31-AC5, FC5-09: trạng thái buổi tạm dừng', () {
    final back = ClockV5.backDay;

    test('trong khoảng, chưa đánh dấu → Tạm dừng, cả trước giờ tập', () {
      for (final now in [
        DateTime(2026, 11, 4, 9),
        ClockV5.start,
        ClockV5.t2359,
      ]) {
        expect(
          SessionStatus.derive(back, now, paused: true)?.state,
          SessionState.paused,
        );
      }
    });

    test('hết ngày vẫn là Tạm dừng (không thành Không tập tự động), '
        'khóa sau 00:00', () {
      final s = SessionStatus.derive(back, ClockV5.t0001, paused: true)!;
      expect(s.state, SessionState.paused);
      expect(s.locked, isTrue);
      expect(s.counts, isFalse);
      expect(
        SessionStatus.derive(back, ClockV5.t0001)?.state,
        SessionState.autoSkipped,
      );
    });

    test('F31-R5: chốt "Đã tập" / "Không tập" trong khoảng giữ trạng thái đó; '
        'ghi được như thường', () {
      final done = SessionRules.markDone(back, now: ClockV5.t1805);
      expect(
        SessionStatus.derive(done, ClockV5.t1900, paused: true)?.state,
        SessionState.done,
      );
      final skipped = SessionRules.markSkipped(back, now: ClockV5.t1805);
      expect(
        SessionStatus.derive(skipped, ClockV5.t1900, paused: true)?.state,
        SessionState.skipped,
      );
      expect(SessionRules.canMarkDone(back, ClockV5.t1805), isTrue);
    });

    test('F31-E4: buổi mới (sửa lịch) rơi vào khoảng cũng là Tạm dừng', () {
      final legs = PlanDay(
        date: LocalDate(2026, 11, 5),
        kind: DayKind.workout,
        time: LocalTime(7, 0),
        muscles: const [MuscleGroup.legs],
        source: DaySource.override,
      );
      expect(PauseRules.isPaused(legs.date, [PauseWeekCases.pause]), isTrue);
      expect(
        SessionStatus.derive(
          legs,
          PauseWeekCases.now,
          paused: PauseRules.isPaused(legs.date, [PauseWeekCases.pause]),
        )?.state,
        SessionState.paused,
      );
    });

    test('ngày nghỉ trong khoảng vẫn là Nghỉ (không có trạng thái buổi)', () {
      final rest = PlanDay(date: LocalDate(2026, 11, 5), kind: DayKind.rest);
      expect(
        SessionStatus.derive(rest, PauseWeekCases.now, paused: true),
        null,
      );
    });
  });

  group('FC5-08, F31-R1, R2, R8, R9: đặt, sửa, kết thúc khoảng', () {
    final today = ClockV5.wed;
    final sun = LocalDate(2026, 11, 8);
    const id = '6f1d2c3b-0000-4000-8000-0000000000aa';

    test('F31-V1: A ≥ hôm nay; F31-V2: B ≥ A', () {
      expect(
        PauseRules.start(
          id: id,
          start: today,
          end: sun,
          others: const [],
          today: today,
        ),
        SchedulePause(id: id, startDate: today, endDate: sun),
      );
      expect(
        () => PauseRules.start(
          id: id,
          start: today.addDays(-1),
          end: sun,
          others: const [],
          today: today,
        ),
        throwsA(
          isA<PauseException>().having(
            (e) => e.error,
            'error',
            PauseError.startInPast,
          ),
        ),
      );
      expect(
        () => PauseRules.start(
          id: id,
          start: sun,
          end: today,
          others: const [],
          today: today,
        ),
        throwsA(
          isA<PauseException>().having(
            (e) => e.error,
            'error',
            PauseError.endBeforeStart,
          ),
        ),
      );
    });

    test('F31-R1, F31-AC6: đang có khoảng (kể cả đặt trước) → không tạo khoảng '
        'thứ hai', () {
      final future = SchedulePause(
        id: 'other',
        startDate: today.addDays(10),
        endDate: today.addDays(12),
      );
      expect(PauseRules.active([future], today), future);
      expect(
        () => PauseRules.start(
          id: id,
          start: today,
          end: today,
          others: [future],
          today: today,
        ),
        throwsA(
          isA<PauseException>().having(
            (e) => e.error,
            'error',
            PauseError.overlap,
          ),
        ),
      );
    });

    test('F31-R8: kết thúc sớm = khoảng kết thúc hôm qua; vào ngày A (chưa qua '
        'ngày nào) hoặc khoảng đặt trước = xóa', () {
      final p = SchedulePause(id: id, startDate: today, endDate: sun);
      expect(PauseRules.endEarly(p, today), isNull);
      final sat = LocalDate(2026, 11, 7);
      final ended = PauseRules.endEarly(p, sat)!;
      expect(ended.endedOn, LocalDate(2026, 11, 6));
      expect(ended.covers(sat), isFalse);
      expect(ended.covers(LocalDate(2026, 11, 6)), isTrue);
      expect(PauseRules.active([ended], sat), isNull);
      final booked = SchedulePause(
        id: id,
        startDate: today.addDays(3),
        endDate: sun,
      );
      expect(PauseRules.endEarly(booked, today), isNull);
    });

    test('F31-R9, F31-V3: sửa B ≥ hôm nay; rút B bỏ ngày tương lai khỏi '
        'khoảng', () {
      final p = SchedulePause(id: id, startDate: today, endDate: sun);
      final fri = LocalDate(2026, 11, 6), thu = LocalDate(2026, 11, 5);
      final shorter = PauseRules.updateEnd(
        p,
        thu,
        others: const [],
        today: fri.addDays(-1),
      );
      expect(shorter.covers(fri), isFalse);
      expect(
        () => PauseRules.updateEnd(p, thu, others: const [], today: fri),
        throwsA(
          isA<PauseException>().having(
            (e) => e.error,
            'error',
            PauseError.endInPast,
          ),
        ),
      );
    });

    test('F31-E5: kết thúc sớm 19:00 ngày có buổi 18:00 → Chờ đánh dấu, '
        'hết ngày chưa chốt → Không tập (tự động)', () {
      final p = SchedulePause(
        id: id,
        startDate: LocalDate(2026, 11, 2),
        endDate: LocalDate(2026, 11, 8),
      );
      final ended = PauseRules.endEarly(p, ClockV5.wed)!;
      final paused = PauseRules.isPaused(ClockV5.wed, [ended]);
      expect(paused, isFalse);
      expect(
        SessionStatus.derive(ClockV5.backDay, ClockV5.t1900)?.state,
        SessionState.awaitingMark,
      );
      expect(
        SessionStatus.derive(ClockV5.backDay, ClockV5.t0001)?.state,
        SessionState.autoSkipped,
      );
    });
  });

  group('F04-R61, F04-AC61: nhắc đi tập trong khoảng tạm dừng', () {
    final template = WeeklyTemplate({
      3: TemplateDay(
        enabled: true,
        time: LocalTime(18, 0),
        muscles: const [MuscleGroup.back],
      ),
    });
    final month = YearMonth(2026, 11);
    final days = MonthGenerator.month(template, month, DateTime(2026, 11)).days;
    final morning = DateTime(2026, 11, 4, 9);
    List<Reminder> plan(Iterable<SchedulePause> pauses, DateTime now) =>
        ReminderPlanner.plan(
          currentMonth: days,
          nextMonth: null,
          template: template,
          now: now,
          pauses: pauses,
        );
    final pause = SchedulePause(
      id: 'p',
      startDate: ClockV5.wed,
      endDate: LocalDate(2026, 11, 8),
    );

    test('không tạm dừng → nhắc 17:00 thứ 4', () {
      expect(plan(const [], morning).first.at, DateTime(2026, 11, 4, 17));
    });

    test(
      'tạm dừng thứ 4 → không nhắc 17:00 thứ 4 (buổi sau khoảng vẫn nhắc)',
      () {
        final r = plan([pause], morning);
        expect(r.any((x) => x.date == ClockV5.wed), isFalse);
        expect(r.first.date, LocalDate(2026, 11, 11));
      },
    );

    test('kết thúc sớm thứ 4 lúc 15:00 → lại có nhắc 17:00', () {
      final at = DateTime(2026, 11, 4, 15);
      final ended = PauseRules.endEarly(pause, ClockV5.wed);
      final r = plan([?ended], at);
      expect(r.first.at, DateTime(2026, 11, 4, 17));
    });
  });
}
