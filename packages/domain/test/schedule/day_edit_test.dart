import 'package:domain/domain.dart';
import 'package:test/test.dart';

void main() {
  // F03-AC2: T2 Ngực + Tay sau, T4 Lưng, T6 Vai, đều 18:00; thiết lập 01/10.
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
  // F03-AC5: thứ 4 đổi từ Lưng sang Vai.
  final shouldersOnWed = WeeklyTemplate({
    ...template.days,
    3: TemplateDay(
      enabled: true,
      time: LocalTime(18, 0),
      muscles: const [MuscleGroup.shoulders],
    ),
  });
  final october = MonthGenerator.first(template, DateTime(2026, 10, 1, 8)).days;
  PlanDay day(int d) =>
      october.firstWhere((x) => x.date == LocalDate(2026, 10, d));
  final at14 = DateTime(2026, 10, 14, 10);

  group('S-21: tình huống của ngày (UX-AC8)', () {
    DaySituation of(PlanDay? d, LocalDate date, DateTime now) =>
        OverrideRules.situation(date, d, now);

    test('ngày tập từ hôm nay, chưa đến giờ → đổi giờ, nhóm cơ, cho nghỉ', () {
      expect(of(day(14), day(14).date, at14), DaySituation.editableWorkout);
      expect(of(day(21), day(21).date, at14), DaySituation.editableWorkout);
    });

    test('ngày nghỉ từ ngày mai → lên lịch tập', () {
      expect(of(day(15), day(15).date, at14), DaySituation.futureRest);
    });

    test('hôm nay nghỉ: chưa có buổi tập thêm / đã có (F03-E4)', () {
      final thu = DateTime(2026, 10, 15, 9);
      expect(of(day(15), day(15).date, thu), DaySituation.todayRest);
      final extra = day(15).withExtra(const [MuscleGroup.abs], loggedAt: thu);
      expect(of(extra, extra.date, thu), DaySituation.todayExtra);
    });

    test('ngày tập đã đến giờ hoặc đã qua trong 7 ngày → đánh dấu', () {
      expect(
        of(day(14), day(14).date, DateTime(2026, 10, 14, 18)),
        DaySituation.markable,
      );
      expect(of(day(9), day(9).date, at14), DaySituation.markable);
      final marked = day(
        14,
      ).withMark(DayMark.skipped, markedAt: DateTime(2026, 10, 14, 18, 30));
      expect(
        of(marked, marked.date, DateTime(2026, 10, 14, 19)),
        DaySituation.markable,
      );
    });

    test('ngày nghỉ đã qua trong 7 ngày → buổi tập thêm; quá 7 ngày → khóa; '
        'chủ nhật', () {
      expect(of(day(13), day(13).date, at14), DaySituation.pastRest);
      expect(of(day(2), day(2).date, at14), DaySituation.locked);
      expect(of(day(6), day(6).date, at14), DaySituation.locked);
      expect(of(null, LocalDate(2026, 10, 18), at14), DaySituation.sunday);
    });
  });

  group('sửa riêng (F03-R9 → R11)', () {
    test('F03-AC9: không sửa riêng được ngày đã qua, chủ nhật, ngày của '
        'tháng sau', () {
      expect(OverrideRules.canEdit(day(13), at14), isFalse);
      expect(
        OverrideRules.canEdit(
          PlanDay(date: LocalDate(2026, 10, 18), kind: DayKind.rest),
          at14,
        ),
        isFalse,
      );
      final nov = PlanDay.fromTemplate(
        LocalDate(2026, 11, 2),
        template.day(DateTime.monday),
      );
      expect(OverrideRules.canEdit(nov, DateTime(2026, 10, 31, 9)), isFalse);
      expect(
        () => OverrideRules.override(day(13), now: at14),
        throwsA(isA<OverrideException>()),
      );
    });

    test('F03-R9: hôm nay chỉ sửa được khi chưa đến giờ và chưa đánh dấu', () {
      expect(
        OverrideRules.canEdit(day(14), DateTime(2026, 10, 14, 17, 59)),
        isTrue,
      );
      expect(
        OverrideRules.canEdit(day(14), DateTime(2026, 10, 14, 18)),
        isFalse,
      );
    });

    test(
      'F03-AC8: thứ 5 22/10 (nghỉ; spec ghi 23/10 nhưng năm 2026 là thứ 6) thành Bụng 18:00 → ngày tập, "Đã sửa '
      'riêng"',
      () {
        final d = OverrideRules.override(
          day(22),
          time: LocalTime(18, 0),
          muscles: const [MuscleGroup.abs],
          now: at14,
        );
        expect(d.isWorkout, isTrue);
        expect(d.muscles, [MuscleGroup.abs]);
        expect(d.source, DaySource.override);
        expect(d.invalidField, isNull);
        expect(SessionStatus.derive(d, at14)!.state, SessionState.upcoming);
      },
    );

    test('F03-V4: ngày tập phải có giờ và nhóm cơ; F03-E4: hôm nay đã có '
        'buổi tập thêm thì không thành ngày tập được; cho nghỉ giữ buổi tập '
        'thêm', () {
      expect(
        () =>
            OverrideRules.override(day(22), time: LocalTime(18, 0), now: at14),
        throwsA(
          isA<OverrideException>().having(
            (e) => e.error,
            'error',
            OverrideError.missingTimeOrMuscles,
          ),
        ),
      );
      final thu = DateTime(2026, 10, 15, 9);
      final extra = day(15).withExtra(const [MuscleGroup.abs], loggedAt: thu);
      expect(
        OverrideRules.validate(
          extra,
          PlanDay(
            date: extra.date,
            kind: DayKind.workout,
            time: LocalTime(19, 0),
            muscles: const [MuscleGroup.back],
            source: DaySource.override,
          ),
          thu,
        ),
        OverrideError.hasExtra,
      );
      final rest = OverrideRules.override(extra, now: thu);
      expect(rest.extraMuscles, [MuscleGroup.abs]);
    });

    test('F03-R10: trả về theo lịch tuần → lấy lại lịch tuần hiện tại, bỏ '
        'nhãn "Đã sửa riêng"', () {
      final rest = OverrideRules.override(day(21), now: at14);
      expect((rest.isWorkout, rest.source), (false, DaySource.override));
      final back = OverrideRules.revert(rest, shouldersOnWed, now: at14);
      expect(back.isWorkout, isTrue);
      expect(back.muscles, [MuscleGroup.shoulders]);
      expect(back.source, DaySource.template);
    });
  });

  group('chia lại (F03-R8)', () {
    test('F03-AC6: 10:00 ngày 14/10 chia lại → các thứ 4 từ 14/10 đến 28/10 '
        'thành Vai; thứ 4 07/10 giữ nguyên trạng thái đã đánh dấu', () {
      final days = [
        for (final d in october)
          d.date == LocalDate(2026, 10, 7)
              ? d.withMark(
                  DayMark.done,
                  actual: d.muscles,
                  markedAt: DateTime(2026, 10, 7, 19),
                )
              : d,
      ];
      final r = Redistributor.apply(
        days: days,
        template: shouldersOnWed,
        now: at14,
      );
      expect(r.changed.map((d) => d.date.day), [14, 21, 28]);
      expect(
        r.changed.every((d) => d.muscles.single == MuscleGroup.shoulders),
        isTrue,
      );
      expect(
        (r.from, r.to),
        (LocalDate(2026, 10, 14), LocalDate(2026, 10, 31)),
      );
      expect(r.keptOverrides, 0);
    });

    test('F03-AC7: 21/10 đã sửa riêng thành nghỉ → chia lại vẫn nghỉ, báo giữ '
        '1 ngày sửa riêng', () {
      final rest21 = OverrideRules.override(day(21), now: at14);
      final r = Redistributor.apply(
        days: [for (final d in october) d.date == rest21.date ? rest21 : d],
        template: shouldersOnWed,
        now: at14,
      );
      expect(r.changed.map((d) => d.date.day), [14, 28]);
      expect(r.keptOverrides, 1);
    });

    test('giữ buổi hôm nay đã đến giờ; F03-E1: lịch mới cho hôm nay nghỉ khi '
        'buổi chưa đến giờ → hôm nay nghỉ', () {
      final restOnWed = WeeklyTemplate({...template.days, 3: TemplateDay.off});
      final started = Redistributor.apply(
        days: october,
        template: restOnWed,
        now: DateTime(2026, 10, 14, 18, 30),
      );
      expect(started.changed.map((d) => d.date.day), [21, 28]);
      final early = Redistributor.apply(
        days: october,
        template: restOnWed,
        now: at14,
      );
      expect(early.changed.first.date.day, 14);
      expect(early.changed.first.isWorkout, isFalse);
    });

    test('lịch mới cho hôm nay buổi mà giờ đã qua → hôm nay nghỉ; hôm nay đã '
        'có buổi tập thêm mà lịch mới là ngày tập → giữ nguyên (F03-E4)', () {
      // Thứ 5 15/10 nghỉ; lịch mới cho thứ 5 tập 07:00.
      final thuMorning = WeeklyTemplate({
        ...template.days,
        4: TemplateDay(
          enabled: true,
          time: LocalTime(7, 0),
          muscles: const [MuscleGroup.abs],
        ),
      });
      final thu = DateTime(2026, 10, 15, 9);
      final r = Redistributor.apply(
        days: october,
        template: thuMorning,
        now: thu,
      );
      expect(r.changed.first.date.day, 22, reason: '15/10 07:00 đã qua');

      final thuEvening = WeeklyTemplate({
        ...template.days,
        4: TemplateDay(
          enabled: true,
          time: LocalTime(20, 0),
          muscles: const [MuscleGroup.abs],
        ),
      });
      final withExtra = [
        for (final d in october)
          d.date == LocalDate(2026, 10, 15)
              ? d.withExtra(const [MuscleGroup.back], loggedAt: thu)
              : d,
      ];
      final kept = Redistributor.apply(
        days: withExtra,
        template: thuEvening,
        now: thu,
      );
      expect(kept.changed.map((d) => d.date.day), [22, 29]);
    });
  });

  group('server: đổi lịch của ngày (VS09-T04)', () {
    test('F03-AC9: sửa riêng ngày đã qua, ngày tháng sau → key', () {
      final rest13 = PlanDay(
        date: LocalDate(2026, 10, 13),
        kind: DayKind.rest,
        source: DaySource.override,
      );
      expect(DayChangeRules.check(day(13), rest13, at14), 'key');
      final workout15 = OverrideRules.override(
        day(15),
        time: LocalTime(18, 0),
        muscles: const [MuscleGroup.abs],
        now: at14,
      );
      expect(DayChangeRules.check(day(15), workout15, at14), isNull);
      expect(
        DayChangeRules.check(day(15), workout15, DateTime(2026, 10, 16, 9)),
        'key',
        reason: 'ngày đã qua',
      );
      final nov2 = PlanDay.fromTemplate(
        LocalDate(2026, 11, 2),
        template.day(DateTime.monday),
      );
      final nov2Rest = PlanDay(
        date: nov2.date,
        kind: DayKind.rest,
        source: DaySource.override,
      );
      expect(
        DayChangeRules.check(nov2, nov2Rest, DateTime(2026, 10, 31, 9)),
        'key',
        reason: 'tháng sau',
      );
    });

    test('tạo ngày mới (chia tháng) và đổi lịch khi chưa biết múi giờ không '
        'áp quy tắc', () {
      expect(DayChangeRules.check(null, day(13), at14), isNull);
      final rest = OverrideRules.override(day(21), now: at14);
      expect(DayChangeRules.check(day(21), rest, null), isNull);
    });
  });
}
