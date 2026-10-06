import 'package:domain/domain.dart';
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

  group('trạng thái buổi tập (03 §6.1)', () {
    test('ngày nghỉ không có trạng thái buổi tập', () {
      expect(SessionStatus.derive(rest, DateTime(2026, 10, 8, 12)), isNull);
    });

    test('F05-AC1: 17:59 Sắp tới, 18:00 Chờ đánh dấu', () {
      expect(
        status(chest, DateTime(2026, 10, 5, 17, 59)).state,
        SessionState.upcoming,
      );
      expect(
        status(chest, DateTime(2026, 10, 5, 18)).state,
        SessionState.awaitingMark,
      );
      expect(SessionRules.canMark(chest, DateTime(2026, 10, 5, 17, 59)), false);
      expect(SessionRules.canMark(chest, DateTime(2026, 10, 5, 18)), true);
    });

    test('Đã tập / Không tập theo đánh dấu của Bạn', () {
      final now = DateTime(2026, 10, 7, 19);
      final done = SessionRules.mark(
        wed,
        DayMark.done,
        actual: const [MuscleGroup.back],
        now: now,
      );
      expect(status(done, now).state, SessionState.done);
      expect(status(done, now).counts, isTrue);
      final skipped = SessionRules.mark(wed, DayMark.skipped, now: now);
      expect(status(skipped, now).state, SessionState.skipped);
      expect(status(skipped, now).counts, isFalse);
    });

    test('F05-AC3, F05-R3: buổi thứ 4 chưa đánh dấu → 00:00 chủ nhật cùng tuần '
        'thành Không tập (tự động)', () {
      expect(
        status(wed, DateTime(2026, 10, 10, 23, 59)).state,
        SessionState.awaitingMark,
      );
      expect(
        status(wed, DateTime(2026, 10, 11)).state,
        SessionState.autoSkipped,
      );
      expect(status(wed, DateTime(2026, 10, 11)).counts, isFalse);
      // Vẫn sửa được trong hạn (F05-R3).
      expect(SessionRules.canMark(wed, DateTime(2026, 10, 11)), isTrue);
    });

    test('F05-AC4, F05-R2: buổi 07/10 sửa được đến hết 14/10, từ 15/10 bị '
        'khóa; trạng thái cuối được giữ', () {
      final lastMinute = DateTime(2026, 10, 14, 23, 59, 59);
      final locked = DateTime(2026, 10, 15);
      expect(SessionRules.lockedFrom(wed.date), locked);
      expect(SessionRules.canMark(wed, lastMinute), isTrue);
      expect(status(wed, lastMinute).locked, isFalse);
      expect(SessionRules.canMark(wed, locked), isFalse);
      expect(
        status(wed, locked),
        const SessionStatus(SessionState.autoSkipped, locked: true),
      );
      final done = SessionRules.mark(
        wed,
        DayMark.done,
        actual: const [MuscleGroup.back],
        now: DateTime(2026, 10, 7, 19),
      );
      expect(
        status(done, locked),
        const SessionStatus(SessionState.done, locked: true),
      );
    });

    test('sơ đồ trạng thái: mọi chuyển đổi hợp lệ trong hạn sửa', () {
      // Chờ đánh dấu → Đã tập → Không tập → Đã tập (F05-R2).
      var d = wed;
      final at = DateTime(2026, 10, 7, 18, 30);
      d = SessionRules.mark(
        d,
        DayMark.done,
        actual: const [MuscleGroup.back],
        now: at,
      );
      expect(status(d, at).state, SessionState.done);
      d = SessionRules.mark(d, DayMark.skipped, now: at);
      expect(status(d, at).state, SessionState.skipped);
      d = SessionRules.mark(
        d,
        DayMark.done,
        actual: const [MuscleGroup.shoulders],
        now: at,
      );
      expect(status(d, at).state, SessionState.done);
      // Không tập (tự động) → Đã tập / Không tập (F05-E2).
      final sunday = DateTime(2026, 10, 11, 9);
      final auto = wed;
      expect(status(auto, sunday).state, SessionState.autoSkipped);
      expect(
        status(
          SessionRules.mark(
            auto,
            DayMark.done,
            actual: const [MuscleGroup.back],
            now: sunday,
          ),
          sunday,
        ).state,
        SessionState.done,
      );
      expect(
        status(
          SessionRules.mark(auto, DayMark.skipped, now: sunday),
          sunday,
        ).state,
        SessionState.skipped,
      );
    });
  });

  group('đánh dấu (F05-R1 → R5, F05-V1)', () {
    final at = DateTime(2026, 10, 7, 18, 5);

    test('F05-R1: chưa đến giờ → tooEarly; F05-R2: quá hạn → locked', () {
      expect(
        SessionRules.validateMark(wed, DayMark.done, const [
          MuscleGroup.back,
        ], DateTime(2026, 10, 7, 17, 59)),
        MarkError.tooEarly,
      );
      expect(
        SessionRules.validateMark(
          wed,
          DayMark.skipped,
          null,
          DateTime(2026, 10, 15),
        ),
        MarkError.locked,
      );
      expect(
        SessionRules.validateMark(rest, DayMark.skipped, null, at),
        MarkError.notWorkout,
      );
    });

    test('F05-V1, F05-R4: "Đã tập" phải có ít nhất 1 nhóm cơ', () {
      expect(
        SessionRules.validateMark(wed, DayMark.done, const [], at),
        MarkError.noMuscles,
      );
      expect(
        SessionRules.validateMark(wed, DayMark.done, null, at),
        MarkError.noMuscles,
      );
      expect(
        SessionRules.validateMark(wed, DayMark.done, const [
          MuscleGroup.back,
        ], at),
        isNull,
      );
    });

    test(
      'F05-AC2: "Đã tập" ghi nhóm cơ thực tế theo thứ tự PR-02; giữ lịch',
      () {
        final d = SessionRules.mark(
          wed,
          DayMark.done,
          actual: const [MuscleGroup.biceps, MuscleGroup.shoulders],
          now: at,
        );
        expect(d.mark, DayMark.done);
        expect(d.actualMuscles, [MuscleGroup.shoulders, MuscleGroup.biceps]);
        expect(d.markedAt, at);
        expect(d.muscles, [MuscleGroup.back]);
        expect(d.time, t1800);
        expect(d.invalidField, isNull);
      },
    );

    test('F05-R5: đổi "Đã tập" sang "Không tập" thì bỏ nhóm cơ thực tế', () {
      final done = SessionRules.mark(
        wed,
        DayMark.done,
        actual: const [MuscleGroup.back],
        now: at,
      );
      final skipped = SessionRules.mark(
        done,
        DayMark.skipped,
        actual: const [MuscleGroup.back],
        now: at,
      );
      expect(skipped.actualMuscles, isNull);
      expect(skipped.invalidField, isNull);
    });

    test('UA-09 Hoàn tác: bỏ đánh dấu → Chờ đánh dấu, không còn markedAt', () {
      final skipped = SessionRules.mark(wed, DayMark.skipped, now: at);
      final undone = SessionRules.mark(skipped, null, now: at);
      expect(undone.mark, isNull);
      expect(undone.markedAt, isNull);
      expect(status(undone, at).state, SessionState.awaitingMark);
    });

    test('mark ném lỗi khi vi phạm quy tắc', () {
      expect(
        () => SessionRules.mark(
          wed,
          DayMark.done,
          actual: const [MuscleGroup.back],
          now: DateTime(2026, 10, 7, 17),
        ),
        throwsA(isA<MarkException>()),
      );
    });

    test('ràng buộc bản ghi: done ⇔ có nhóm cơ thực tế; có đánh dấu ⇔ có '
        'markedAt', () {
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
