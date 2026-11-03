import 'package:domain/domain.dart';
import 'package:domain/testing.dart';
import 'package:test/test.dart';

void main() {
  final t1800 = LocalTime(18, 0);

  /// Buổi thứ 4 ngày 07/10/2026, Lưng 18:00 (template F03-AC2).
  final wed = PlanDay(
    date: LocalDate(2026, 10, 7),
    kind: DayKind.workout,
    time: t1800,
    muscles: const [MuscleGroup.back],
  );
  final chest = PlanDay(
    date: LocalDate(2026, 10, 5),
    kind: DayKind.workout,
    time: t1800,
    muscles: const [MuscleGroup.chest],
  );
  final rest = PlanDay(date: LocalDate(2026, 10, 8), kind: DayKind.rest);

  SessionStatus status(PlanDay d, DateTime now) =>
      SessionStatus.derive(d, now)!;

  group('trạng thái buổi tập Bản 5 (03 Bản 5 §6.8; IR5-08 sửa kỳ vọng Bản 2 '
      'theo CR5-02, CR5-06, CR5-08)', () {
    test('ngày nghỉ không có trạng thái buổi tập', () {
      expect(SessionStatus.derive(rest, DateTime(2026, 10, 8, 12)), isNull);
    });

    test('FC5-02: 17:59 Sắp tới — chưa "Đã tập" được, "Không tập" được từ '
        'đầu ngày; 18:00 Chờ đánh dấu', () {
      final before = DateTime(2026, 10, 5, 17, 59);
      final at = DateTime(2026, 10, 5, 18);
      expect(status(chest, before).state, SessionState.upcoming);
      expect(SessionRules.validateDone(chest, before), MarkError.tooEarly);
      expect(SessionRules.canMarkSkipped(chest, before), isTrue);
      expect(
        SessionRules.canMarkSkipped(chest, DateTime(2026, 10, 5)),
        isTrue,
        reason: 'F05-E62: bấm "Không tập" 10:00 cho buổi 18:00',
      );
      expect(status(chest, at).state, SessionState.awaitingMark);
      expect(SessionRules.canMarkDone(chest, at), isTrue);
      expect(SessionRules.canMarkSkipped(chest, at), isTrue);
    });

    test('F05-AC61: "Đã tập" ghi nhóm cơ của lịch (TD2-08); trong ngày đổi '
        'sang Không tập rồi lại Đã tập được', () {
      final at = DateTime(2026, 10, 7, 19);
      final done = SessionRules.markDone(wed, now: at);
      expect(done.mark, DayMark.done);
      expect(done.actualMuscles, [MuscleGroup.back]);
      expect(done.markedAt, at);
      expect(status(done, at), const SessionStatus(SessionState.done));
      expect(status(done, at).counts, isTrue);
      expect(SessionRules.validateDone(done, at), MarkError.alreadyDone);
      final skipped = SessionRules.markSkipped(done, now: at);
      expect(skipped.mark, DayMark.skipped);
      expect(skipped.actualMuscles, isNull);
      final again = SessionRules.markDone(skipped, now: at);
      expect(status(again, at).state, SessionState.done);
    });

    test('FC5-13, F05-AC62: bỏ đánh dấu → Chờ đánh dấu; chưa đánh dấu thì '
        'không bỏ được', () {
      final at = DateTime(2026, 10, 7, 19);
      final done = SessionRules.markDone(wed, now: at);
      final unmarked = SessionRules.unmark(done, now: at);
      expect(unmarked.mark, isNull);
      expect(unmarked.actualMuscles, isNull);
      expect(unmarked.markedAt, isNull);
      expect(unmarked.invalidField, isNull);
      expect(status(unmarked, at).state, SessionState.awaitingMark);
      expect(SessionRules.validateUnmark(wed, at), MarkError.notMarked);
      final skipped = SessionRules.markSkipped(wed, now: at);
      expect(SessionRules.canUnmark(skipped, at), isTrue);
    });

    test('F05-E63: 23:59 bấm "Đã tập", 00:00 khóa "Đã tập"; 00:01 không đổi '
        'được', () {
      final done = SessionRules.markDone(
        wed,
        now: DateTime(2026, 10, 7, 23, 59),
      );
      for (final now in [DateTime(2026, 10, 8), DateTime(2026, 10, 8, 0, 1)]) {
        expect(SessionRules.validateSkipped(done, now), MarkError.locked);
        expect(SessionRules.validateUnmark(done, now), MarkError.locked);
        expect(
          status(done, now),
          const SessionStatus(SessionState.done, locked: true),
        );
      }
    });

    test('F05-AC63, F05-R63: không bấm gì → 00:00 thành Không tập (tự động) '
        'ngay trong đêm (không chờ chủ nhật); 00:01 không sửa', () {
      expect(
        status(wed, DateTime(2026, 10, 7, 23, 59)).state,
        SessionState.awaitingMark,
      );
      final midnight = DateTime(2026, 10, 8);
      expect(
        status(wed, midnight),
        const SessionStatus(SessionState.autoSkipped, locked: true),
      );
      expect(status(wed, midnight).counts, isFalse);
      final later = DateTime(2026, 10, 8, 0, 1);
      expect(SessionRules.validateDone(wed, later), MarkError.locked);
      expect(SessionRules.validateSkipped(wed, later), MarkError.locked);
    });

    test('F05-E62: "Không tập" 10:00, 19:00 đổi sang "Đã tập"', () {
      final skipped = SessionRules.markSkipped(
        wed,
        now: DateTime(2026, 10, 7, 10),
      );
      expect(
        status(skipped, DateTime(2026, 10, 7, 10)).state,
        SessionState.skipped,
      );
      expect(
        SessionRules.validateDone(skipped, DateTime(2026, 10, 7, 17)),
        MarkError.tooEarly,
      );
      final done = SessionRules.markDone(
        skipped,
        now: DateTime(2026, 10, 7, 19),
      );
      expect(done.mark, DayMark.done);
    });

    test('FD5-01 = A, F25-E61: tới gym 17:20 → buổi mở từ 17:20 ("Đã tập", '
        'cửa sổ ghi tạ)', () {
      final opened = wed.withOpenedAt(DateTime(2026, 10, 7, 17, 20));
      expect(SessionRules.opensAt(opened), DateTime(2026, 10, 7, 17, 20));
      final at = DateTime(2026, 10, 7, 17, 25);
      expect(status(opened, at).state, SessionState.awaitingMark);
      expect(SessionRules.canMarkDone(opened, at), isTrue);
      expect(
        status(opened, DateTime(2026, 10, 7, 17, 19)).state,
        SessionState.upcoming,
      );
      // Tới gym sau giờ tập không đổi giờ mở.
      final late = wed.withOpenedAt(DateTime(2026, 10, 7, 18, 30));
      expect(SessionRules.opensAt(late), DateTime(2026, 10, 7, 18));
    });

    test('F05-AC24: 10:00 sửa riêng thứ 4 14/10 từ Lưng thành Vai; 18:00 bấm '
        'Đã tập → ghi nhận Vai', () {
      final day = PlanDay(
        date: LocalDate(2026, 10, 14),
        kind: DayKind.workout,
        time: t1800,
        muscles: const [MuscleGroup.back],
      );
      final shoulders = OverrideRules.override(
        day,
        time: t1800,
        muscles: const [MuscleGroup.shoulders],
        now: DateTime(2026, 10, 14, 10),
      );
      final done = SessionRules.markDone(
        shoulders,
        now: DateTime(2026, 10, 14, 18),
      );
      expect(done.actualMuscles, [MuscleGroup.shoulders]);
      expect(SessionRules.musclesOf(done), [MuscleGroup.shoulders]);
    });

    test('F05-AC25: 18:30 không sửa riêng được buổi hôm nay', () {
      final day = PlanDay(
        date: LocalDate(2026, 10, 14),
        kind: DayKind.workout,
        time: t1800,
        muscles: const [MuscleGroup.back],
      );
      final at = DateTime(2026, 10, 14, 18, 30);
      expect(OverrideRules.canEdit(day, at), isFalse);
      expect(
        () => OverrideRules.override(
          day,
          time: t1800,
          muscles: const [MuscleGroup.shoulders],
          now: at,
        ),
        throwsA(isA<OverrideException>()),
      );
    });

    test('ngày nghỉ không đánh dấu được', () {
      final at = DateTime(2026, 10, 8, 19);
      expect(SessionRules.validateDone(rest, at), MarkError.notWorkout);
      expect(SessionRules.validateSkipped(rest, at), MarkError.notWorkout);
    });

    test('ràng buộc bản ghi: done ⇔ có nhóm cơ thực tế; có đánh dấu ⇔ có '
        'markedAt', () {
      final at = DateTime(2026, 10, 7, 19);
      PlanDay withMark(
        DayMark? mark,
        List<MuscleGroup>? actual,
        DateTime? markedAt,
      ) => PlanDay(
        date: wed.date,
        kind: DayKind.workout,
        time: t1800,
        muscles: const [MuscleGroup.back],
        mark: mark,
        actualMuscles: actual,
        markedAt: markedAt,
      );
      expect(withMark(DayMark.done, null, at).invalidField, 'actualMuscles');
      expect(
        withMark(DayMark.done, const [], at).invalidField,
        'actualMuscles',
      );
      expect(
        withMark(DayMark.skipped, const [MuscleGroup.back], at).invalidField,
        'actualMuscles',
      );
      expect(withMark(DayMark.skipped, null, null).invalidField, 'markedAt');
      expect(withMark(null, null, at).invalidField, 'markedAt');
      expect(withMark(null, null, null).invalidField, isNull);
    });
  });

  group('chuyển tiếp: legacyDoneDays (F05-R36 → R38; FC5-12)', () {
    final now = legacyToday;

    test('F05-AC29, FC5-12: buổi Đã tập hôm qua và thứ 2 cùng tuần khóa ngay ở '
        'trạng thái hiện có', () {
      for (final d in [
        LegacyDoneDays.doneYesterday,
        LegacyDoneDays.doneMonday,
        LegacyDoneDays.doneOtherMuscles,
      ]) {
        expect(SessionLock.of(d), isTrue, reason: '${d.date}');
        expect(SessionRules.canMarkSkipped(d, now), isFalse);
        expect(SessionRules.canMarkDone(d, now), isFalse);
        expect(
          status(d, now),
          const SessionStatus(SessionState.done, locked: true),
        );
        expect(OverrideRules.canEdit(d, now), isFalse);
      }
    });

    test('F05-AC30, F05-R38: buổi Bản 1 lịch Ngực, nhóm cơ thực tế Vai → hiện '
        'Vai', () {
      final d = LegacyDoneDays.doneOtherMuscles;
      expect(d.muscles, [MuscleGroup.chest]);
      expect(SessionRules.musclesOf(d), [MuscleGroup.shoulders]);
      expect(d.sessionMuscles, [MuscleGroup.shoulders]);
    });

    test(
      'F05-R36, F05-R64: buổi tập thêm của ngày đã qua khóa (không thêm lại, '
      'không sửa, không xóa)',
      () {
        final d = LegacyDoneDays.extra;
        expect(SessionLock.extra(d), isTrue);
        expect(SessionLock.of(d), isTrue);
        expect(ExtraSessionRules.canAdd(d, now), isFalse);
        expect(
          ExtraSessionRules.validate(d, const [MuscleGroup.back], now),
          ExtraError.locked,
        );
        expect(ExtraSessionRules.canEdit(d, now), isFalse);
      },
    );

    test('F05-E67, FC5-12: buổi Không tập còn "hạn 7 ngày" cũ khóa ngay, không '
        'đổi sang Đã tập được', () {
      final d = LegacyDoneDays.skipped;
      expect(SessionLock.of(d), isFalse);
      expect(SessionRules.validateDone(d, now), MarkError.locked);
      expect(
        status(d, now),
        const SessionStatus(SessionState.skipped, locked: true),
      );
    });

    test('ngày chưa chốt: không có SessionLock', () {
      expect(SessionLock.of(wed), isFalse);
      expect(SessionLock.of(rest), isFalse);
    });
  });

  group('buổi tới (S-10)', () {
    final ac2 = WeeklyTemplate({
      1: TemplateDay(
        enabled: true,
        time: t1800,
        muscles: const [MuscleGroup.chest, MuscleGroup.triceps],
      ),
      3: TemplateDay(
        enabled: true,
        time: t1800,
        muscles: const [MuscleGroup.back],
      ),
      5: TemplateDay(
        enabled: true,
        time: t1800,
        muscles: const [MuscleGroup.shoulders],
      ),
    });
    final october = MonthGenerator.month(
      ac2,
      YearMonth(2026, 10),
      DateTime(2026, 10),
    ).days;

    test('ngày nghỉ thứ 5 08/10 → buổi tới thứ 6 09/10 Vai 18:00', () {
      final next = SessionRules.nextSession(
        after: LocalDate(2026, 10, 8),
        days: october,
        planned: {YearMonth(2026, 10)},
        template: ac2,
      )!;
      expect(next.date, LocalDate(2026, 10, 9));
      expect(next.muscles, [MuscleGroup.shoulders]);
      expect(next.time, t1800);
    });

    test('theo lịch tháng, kể cả ngày sửa riêng', () {
      final days = [
        for (final d in october)
          d.date == LocalDate(2026, 10, 9)
              ? PlanDay(
                  date: d.date,
                  kind: DayKind.rest,
                  source: DaySource.override,
                )
              : d,
      ];
      final next = SessionRules.nextSession(
        after: LocalDate(2026, 10, 8),
        days: days,
        planned: {YearMonth(2026, 10)},
        template: ac2,
      )!;
      expect(next.date, LocalDate(2026, 10, 12));
    });

    test('thứ 7 31/10, tháng 11 chưa có lịch → suy ra từ lịch tuần: thứ 2 '
        '02/11', () {
      final next = SessionRules.nextSession(
        after: LocalDate(2026, 10, 31),
        days: october,
        planned: {YearMonth(2026, 10)},
        template: ac2,
      )!;
      expect(next.date, LocalDate(2026, 11, 2));
      expect(next.muscles, [MuscleGroup.chest, MuscleGroup.triceps]);
    });

    test('không có lịch tuần và không còn buổi → null', () {
      expect(
        SessionRules.nextSession(
          after: LocalDate(2026, 10, 31),
          days: october,
          planned: {YearMonth(2026, 10)},
          template: null,
        ),
        isNull,
      );
    });
  });
}
