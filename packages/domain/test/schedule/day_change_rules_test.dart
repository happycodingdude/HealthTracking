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
  DayViolation locked(String f) => DayViolation(f, DayViolationCode.dayLocked);
  const windowClosed = DayViolation('mark', DayViolationCode.windowClosed);

  group('đánh dấu (05 Bản 5 §6.6.2, TD5-08; IR5-08 sửa kỳ vọng Bản 2 theo '
      'CR5-02, CR5-06)', () {
    test('F05-R22, FC5-02: "Đã tập" trước giờ tập → lift_window_closed; '
        '"Không tập" từ đầu ngày được', () {
      final at = DateTime(2026, 10, 7, 17, 59);
      expect(
        DayChangeRules.check(wed, marked(DayMark.done, at), at),
        windowClosed,
      );
      final ok = DateTime(2026, 10, 7, 18);
      expect(DayChangeRules.check(wed, marked(DayMark.done, ok), ok), isNull);
      final morning = DateTime(2026, 10, 7, 10);
      expect(
        DayChangeRules.check(wed, marked(DayMark.skipped, morning), morning),
        isNull,
      );
    });

    test('TAC5-04: done → skipped cùng ngày → được; hôm sau → day_locked', () {
      final done = marked(DayMark.done, DateTime(2026, 10, 7, 19));
      final at = DateTime(2026, 10, 7, 19, 30);
      expect(
        DayChangeRules.check(done, marked(DayMark.skipped, at), at),
        isNull,
      );
      expect(
        DayChangeRules.check(done, wed, at),
        isNull,
        reason: 'bỏ đánh dấu',
      );
      final next = DateTime(2026, 10, 8, 0, 1);
      expect(
        DayChangeRules.check(done, marked(DayMark.skipped, next), next),
        locked('mark'),
      );
      expect(
        DayChangeRules.check(wed, marked(DayMark.done, next), next),
        locked('mark'),
      );
    });

    test('TAC5-04, FD5-01: "Đã tập" 17:20 với openedAt 17:20, giờ tập 18:00 → '
        'được; không openedAt → lift_window_closed', () {
      final at = DateTime(2026, 10, 7, 17, 20);
      final opened = wed.withOpenedAt(at);
      expect(
        DayChangeRules.check(
          opened,
          marked(DayMark.done, at).withOpenedAt(at),
          at,
        ),
        isNull,
      );
      expect(
        DayChangeRules.check(wed, marked(DayMark.done, at), at),
        windowClosed,
      );
    });

    test(
      'openedAt: chỉ ngày tập, không muộn hơn giờ tập; mốc sớm hơn thắng',
      () {
        final at = DateTime(2026, 10, 7, 17, 20);
        expect(
          DayChangeRules.check(
            wed,
            wed.withOpenedAt(DateTime(2026, 10, 7, 18, 30)),
            at,
          ),
          field('openedAt'),
        );
        expect(DayChangeRules.check(wed, wed.withOpenedAt(at), at), isNull);
        final early = DateTime(2026, 10, 7, 17, 10);
        expect(
          DayChangeRules.mergeOpenedAt(
            wed.withOpenedAt(at),
            wed.withOpenedAt(early),
          ),
          early,
        );
        expect(
          DayChangeRules.mergeOpenedAt(
            wed.withOpenedAt(early),
            wed.withOpenedAt(at),
          ),
          early,
        );
        expect(DayChangeRules.mergeOpenedAt(wed.withOpenedAt(at), wed), at);
        expect(DayChangeRules.mergeOpenedAt(null, wed), isNull);
      },
    );

    test('sửa riêng buổi đã đánh dấu → key (F05-R68)', () {
      final done = marked(DayMark.done, DateTime(2026, 10, 7, 19));
      expect(
        DayChangeRules.check(
          done,
          PlanDay(
            date: wed.date,
            kind: DayKind.rest,
            source: DaySource.override,
          ),
          DateTime(2026, 10, 7, 19, 30),
        ),
        field('key'),
      );
    });

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
        windowClosed,
      );
    });

    test('không đổi gì → không áp quy tắc nào, kể cả ngày đã qua', () {
      final done = marked(DayMark.done, DateTime(2026, 10, 7, 19));
      expect(DayChangeRules.check(done, done, DateTime(2026, 11, 1)), isNull);
      expect(DayChangeRules.check(null, wed, DateTime(2026, 10, 1)), isNull);
    });

    test('chưa biết múi giờ → bỏ qua quy tắc thời gian', () {
      final at = DateTime(2026, 10, 7, 12);
      expect(DayChangeRules.check(wed, marked(DayMark.done, at), null), isNull);
    });
  });

  group('buổi tập thêm (05 Bản 5 §6.6.2, F05-R64)', () {
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

    test('TAC5-04: thêm cho hôm qua → day_locked', () {
      final sun = DateTime(2026, 10, 11, 0, 1);
      expect(
        DayChangeRules.check(sat, extra(sun), sun),
        locked('extraMuscles'),
      );
    });

    test('F05-E65: buổi tập thêm đã lưu → đổi nhóm cơ, xóa trong ngày được; '
        '00:00 → day_locked', () {
      final added = extra(DateTime(2026, 10, 10, 20));
      final at = DateTime(2026, 10, 10, 21);
      expect(DayChangeRules.check(added, sat, at), isNull);
      expect(
        DayChangeRules.check(
          added,
          sat.withExtra(const [
            MuscleGroup.back,
          ], loggedAt: added.extraLoggedAt),
          at,
        ),
        isNull,
      );
      final midnight = DateTime(2026, 10, 11);
      expect(
        DayChangeRules.check(added, sat, midnight),
        locked('extraMuscles'),
      );
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
