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

  group('trạng thái buổi tập Bản 2 (03 Bản 2 §6.1)', () {
    test('ngày nghỉ không có trạng thái buổi tập', () {
      expect(SessionStatus.derive(rest, DateTime(2026, 10, 8, 12)), isNull);
    });

    test('F05-R22: 17:59 Sắp tới, chưa đánh dấu được; 18:00 Chờ đánh dấu', () {
      final before = DateTime(2026, 10, 5, 17, 59);
      final at = DateTime(2026, 10, 5, 18);
      expect(status(chest, before).state, SessionState.upcoming);
      expect(SessionRules.validateDone(chest, before), MarkError.tooEarly);
      expect(SessionRules.validateSkipped(chest, before), MarkError.tooEarly);
      expect(status(chest, at).state, SessionState.awaitingMark);
      expect(SessionRules.canMarkDone(chest, at), isTrue);
      expect(SessionRules.canMarkSkipped(chest, at), isTrue);
    });

    test('F05-AC21: "Đã tập" không chọn nhóm cơ — ghi nhóm cơ của lịch tháng '
        '(TD2-08); trạng thái Đã tập, không đổi được gì nữa', () {
      final at = DateTime(2026, 10, 7, 19);
      final done = SessionRules.markDone(wed, now: at);
      expect(done.mark, DayMark.done);
      expect(done.actualMuscles, [MuscleGroup.back]);
      expect(done.markedAt, at);
      expect(status(done, at), const SessionStatus(SessionState.done));
      expect(status(done, at).counts, isTrue);
      expect(SessionLock.of(done), isTrue);
      expect(SessionRules.validateDone(done, at), MarkError.alreadyDone);
      expect(SessionRules.validateSkipped(done, at), MarkError.alreadyDone);
    });

    test('F05-AC22: buổi Đã tập không đổi sang Không tập, kể cả trong ngày; '
        'không bao giờ "Đã khóa" hay hết hạn — chốt mãi', () {
      final done = SessionRules.markDone(wed, now: DateTime(2026, 10, 7, 19));
      for (final now in [
        DateTime(2026, 10, 7, 19, 1),
        DateTime(2026, 10, 14, 23, 59),
        DateTime(2026, 11, 30),
      ]) {
        expect(
          () => SessionRules.markSkipped(done, now: now),
          throwsA(
            isA<MarkException>().having(
              (e) => e.error,
              'error',
              MarkError.alreadyDone,
            ),
          ),
        );
        expect(status(done, now), const SessionStatus(SessionState.done));
      }
    });

    test('F05-AC23: buổi Không tập 07/10 → đổi sang Đã tập được đến hết '
        '14/10; đổi xong thì chốt; từ 15/10 chưa đổi thì Đã khóa', () {
      final skipped = SessionRules.markSkipped(
        wed,
        now: DateTime(2026, 10, 7, 19),
      );
      expect(skipped.actualMuscles, isNull);
      expect(
        status(skipped, DateTime(2026, 10, 7, 20)).state,
        SessionState.skipped,
      );
      expect(SessionRules.lastChangeDate(wed.date), LocalDate(2026, 10, 14));
      final lastMinute = DateTime(2026, 10, 14, 23, 59, 59);
      expect(SessionRules.canMarkDone(skipped, lastMinute), isTrue);
      expect(
        SessionRules.validateSkipped(skipped, lastMinute),
        MarkError.notAwaiting,
        reason: 'không còn thao tác nào khác trên buổi Không tập',
      );
      final changed = SessionRules.markDone(skipped, now: lastMinute);
      expect(status(changed, lastMinute).state, SessionState.done);
      expect(SessionLock.session(changed), isTrue);

      final locked = DateTime(2026, 10, 15);
      expect(SessionRules.validateDone(skipped, locked), MarkError.locked);
      expect(
        status(skipped, locked),
        const SessionStatus(SessionState.skipped, locked: true),
      );
    });

    test('F05-R26: buổi thứ 4 chưa đánh dấu → 00:00 chủ nhật cùng tuần thành '
        'Không tập (tự động); không bấm "Không tập" được nữa, đổi sang Đã tập '
        'được trong 7 ngày rồi Đã khóa', () {
      expect(
        status(wed, DateTime(2026, 10, 10, 23, 59)).state,
        SessionState.awaitingMark,
      );
      final sunday = DateTime(2026, 10, 11);
      expect(status(wed, sunday).state, SessionState.autoSkipped);
      expect(status(wed, sunday).counts, isFalse);
      expect(SessionRules.validateSkipped(wed, sunday), MarkError.notAwaiting);
      expect(SessionRules.canMarkDone(wed, sunday), isTrue);
      expect(
        status(wed, DateTime(2026, 10, 15)),
        const SessionStatus(SessionState.autoSkipped, locked: true),
      );
      expect(SessionRules.canMarkDone(wed, DateTime(2026, 10, 15)), isFalse);
    });

    test('sơ đồ trạng thái Bản 2: chỉ các chuyển đổi trong sơ đồ', () {
      final at = DateTime(2026, 10, 7, 18, 30);
      // Chờ đánh dấu → Đã tập.
      expect(
        status(SessionRules.markDone(wed, now: at), at).state,
        SessionState.done,
      );
      // Chờ đánh dấu → Không tập → Đã tập.
      final skipped = SessionRules.markSkipped(wed, now: at);
      expect(
        status(SessionRules.markDone(skipped, now: at), at).state,
        SessionState.done,
      );
      // Không tập (tự động) → Đã tập.
      final sunday = DateTime(2026, 10, 11, 9);
      expect(
        status(SessionRules.markDone(wed, now: sunday), sunday).state,
        SessionState.done,
      );
      // Không có Đã tập → Không tập, Không tập → Không tập, Đã tập → Đã tập.
      final done = SessionRules.markDone(wed, now: at);
      expect(SessionRules.canMarkSkipped(done, at), isFalse);
      expect(SessionRules.canMarkSkipped(skipped, at), isFalse);
      expect(SessionRules.canMarkDone(done, at), isFalse);
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

  group('chuyển tiếp từ Bản 1: legacyDoneDays (F05-R36 → R38)', () {
    final now = legacyToday;

    test(
      'F05-AC29, F05-E30: buổi Đã tập hôm qua và thứ 2 cùng tuần (còn "hạn '
      '7 ngày" của Bản 1) khóa ngay; không có "Đã khóa" hay biểu tượng khóa',
      () {
        for (final d in [
          LegacyDoneDays.doneYesterday,
          LegacyDoneDays.doneMonday,
          LegacyDoneDays.doneOtherMuscles,
        ]) {
          expect(SessionLock.of(d), isTrue, reason: '${d.date}');
          expect(SessionRules.canMarkSkipped(d, now), isFalse);
          expect(SessionRules.canMarkDone(d, now), isFalse);
          expect(status(d, now), const SessionStatus(SessionState.done));
          expect(OverrideRules.canEdit(d, now), isFalse);
        }
      },
    );

    test('F05-AC30, F05-R38: buổi Bản 1 lịch Ngực, nhóm cơ thực tế Vai → hiện '
        'Vai', () {
      final d = LegacyDoneDays.doneOtherMuscles;
      expect(d.muscles, [MuscleGroup.chest]);
      expect(SessionRules.musclesOf(d), [MuscleGroup.shoulders]);
      expect(d.sessionMuscles, [MuscleGroup.shoulders]);
    });

    test(
      'F05-R36: buổi tập thêm Bản 1 khóa ngay (không thêm lại, không sửa)',
      () {
        final d = LegacyDoneDays.extra;
        expect(SessionLock.extra(d), isTrue);
        expect(SessionLock.of(d), isTrue);
        expect(ExtraSessionRules.canAdd(d, now), isFalse);
        expect(
          ExtraSessionRules.validate(d, const [MuscleGroup.back], now),
          ExtraError.alreadyLogged,
        );
      },
    );

    test(
      'F05-R37: buổi Không tập Bản 1 còn trong 7 ngày đổi sang Đã tập được',
      () {
        final d = LegacyDoneDays.skipped;
        expect(SessionLock.of(d), isFalse);
        expect(SessionRules.canMarkDone(d, now), isTrue);
        expect(SessionRules.markDone(d, now: now).actualMuscles, d.muscles);
      },
    );

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
