import 'package:domain/domain.dart';
import 'package:test/test.dart';

void main() {
  final wed = PlanDay(
    date: LocalDate(2026, 10, 7),
    kind: DayKind.workout,
    time: LocalTime(18, 0),
    muscles: const [MuscleGroup.back],
  );

  PlanDay marked(DayMark mark, DateTime at) => wed.withMark(
    mark,
    actual: mark == DayMark.done ? const [MuscleGroup.back] : null,
    markedAt: at,
  );

  DayViolation field(String f) => DayViolation(f);
  const sessionLocked = DayViolation('mark', DayLock.session);
  const extraLocked = DayViolation('extraMuscles', DayLock.extra);

  group('đánh dấu (05 Bản 2 §6.6.3)', () {
    test('F05-R22: đánh dấu trước giờ tập → mark', () {
      final at = DateTime(2026, 10, 7, 17, 59);
      expect(
        DayChangeRules.check(wed, marked(DayMark.done, at), at),
        field('mark'),
      );
      final ok = DateTime(2026, 10, 7, 18);
      expect(DayChangeRules.check(wed, marked(DayMark.done, ok), ok), isNull);
    });

    test(
      'skipped → done chấp nhận đến hết ngày thứ 7; ngày thứ 8 bị từ chối',
      () {
        final skipped = marked(DayMark.skipped, DateTime(2026, 10, 7, 19));
        final last = DateTime(2026, 10, 14, 23, 59);
        expect(
          DayChangeRules.check(skipped, marked(DayMark.done, last), last),
          isNull,
        );
        final late = DateTime(2026, 10, 15, 0, 1);
        expect(
          DayChangeRules.check(skipped, marked(DayMark.done, late), late),
          field('mark'),
        );
      },
    );

    test(
      'TAC2-03: buổi done → đổi sang skipped, đổi nhóm cơ thực tế, bỏ đánh '
      'dấu, sửa riêng → session_locked, kể cả trong ngày và trong hạn 7 ngày',
      () {
        final done = marked(DayMark.done, DateTime(2026, 10, 7, 19));
        final at = DateTime(2026, 10, 7, 19, 30);
        expect(
          DayChangeRules.check(done, marked(DayMark.skipped, at), at),
          sessionLocked,
        );
        expect(
          DayChangeRules.check(
            done,
            done.withMark(
              DayMark.done,
              actual: const [MuscleGroup.shoulders],
              markedAt: done.markedAt,
            ),
            at,
          ),
          sessionLocked,
        );
        expect(
          DayChangeRules.check(done, wed, at),
          sessionLocked,
          reason: 'Hoàn tác',
        );
        expect(
          DayChangeRules.check(
            done,
            PlanDay(
              date: wed.date,
              kind: DayKind.rest,
              source: DaySource.override,
            ),
            DateTime(2026, 10, 7, 12),
          ),
          sessionLocked,
          reason: 'sửa riêng',
        );
        // Không có múi giờ vẫn khóa (không phụ thuộc thời gian).
        expect(
          DayChangeRules.check(done, marked(DayMark.skipped, at), null),
          sessionLocked,
        );
      },
    );

    test('TD2-08: app Bản 2 ghi Đã tập phải có nhóm cơ thực tế = nhóm cơ lịch; '
        'app Bản 1 tự chọn được rồi khóa', () {
      final at = DateTime(2026, 10, 7, 19);
      final other = wed.withMark(
        DayMark.done,
        actual: const [MuscleGroup.shoulders],
        markedAt: at,
      );
      expect(
        DayChangeRules.check(wed, other, at, fromV2App: true),
        field('actualMuscles'),
      );
      expect(DayChangeRules.check(wed, other, at), isNull);
      expect(
        DayChangeRules.check(
          wed,
          marked(DayMark.done, at),
          at,
          fromV2App: true,
        ),
        isNull,
      );
    });

    test('bản mới tạo đã có đánh dấu cũng được kiểm tra', () {
      final at = DateTime(2026, 10, 7, 12);
      expect(
        DayChangeRules.check(null, marked(DayMark.done, at), at),
        field('mark'),
      );
    });

    test('không đổi gì → không áp quy tắc nào', () {
      final done = marked(DayMark.done, DateTime(2026, 10, 7, 19));
      expect(DayChangeRules.check(done, done, DateTime(2026, 11, 1)), isNull);
      expect(DayChangeRules.check(null, wed, DateTime(2026, 10, 1)), isNull);
    });

    test('chưa biết múi giờ → bỏ qua quy tắc thời gian', () {
      final at = DateTime(2026, 10, 7, 12);
      expect(DayChangeRules.check(wed, marked(DayMark.done, at), null), isNull);
    });
  });

  group('buổi tập thêm (05 Bản 2 §6.6.3)', () {
    final sat = PlanDay(date: LocalDate(2026, 10, 10), kind: DayKind.rest);
    PlanDay extra(DateTime at, [MuscleGroup m = MuscleGroup.abs]) =>
        sat.withExtra([m], loggedAt: at);

    test('thêm cho ngày mai → extraMuscles; hôm nay được', () {
      final fri = DateTime(2026, 10, 9, 20);
      expect(DayChangeRules.check(sat, extra(fri), fri), field('extraMuscles'));
      final now = DateTime(2026, 10, 10, 20);
      expect(DayChangeRules.check(sat, extra(now), now), isNull);
      expect(DayChangeRules.check(null, extra(now), now), isNull);
    });

    test('quá 7 ngày không thêm được', () {
      final late = DateTime(2026, 10, 18, 0, 1);
      expect(
        DayChangeRules.check(sat, extra(late), late),
        field('extraMuscles'),
      );
    });

    test('TAC2-04: buổi tập thêm đã lưu → xóa hoặc đổi nhóm cơ → '
        'extra_session_locked, kể cả trong ngày', () {
      final added = extra(DateTime(2026, 10, 10, 20));
      final at = DateTime(2026, 10, 10, 21);
      expect(DayChangeRules.check(added, sat, at), extraLocked);
      expect(
        DayChangeRules.check(added, extra(at, MuscleGroup.back), at),
        extraLocked,
      );
      expect(DayChangeRules.check(added, sat, null), extraLocked);
      expect(DayChangeRules.check(added, added, at), isNull);
    });

    test('ngày tập thêm buổi tập thêm → extraMuscles', () {
      final at = DateTime(2026, 10, 7, 20);
      expect(
        DayChangeRules.check(
          wed,
          wed.withExtra(const [MuscleGroup.abs], loggedAt: at),
          at,
        ),
        field('extraMuscles'),
      );
    });
  });
}
