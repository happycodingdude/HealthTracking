import 'package:domain/domain.dart';
import 'package:test/test.dart';

/// F31-R1, R2, R8, R9, V1 → V3; 05 Bản 5 §6.6.2 `schedule_pause`.
void main() {
  final today = LocalDate(2026, 11, 3);
  SchedulePause pause(
    String id,
    LocalDate a,
    LocalDate b, [
    LocalDate? ended,
  ]) => SchedulePause(id: id, startDate: a, endDate: b, endedOn: ended);
  final wed = LocalDate(2026, 11, 4), sun = LocalDate(2026, 11, 8);

  test('khoảng: ngày cuối, phủ ngày, kết thúc sớm', () {
    final p = pause('p', wed, sun);
    expect(p.covers(wed), isTrue);
    expect(p.covers(sun), isTrue);
    expect(p.covers(today), isFalse);
    final ended = pause('p', wed, sun, LocalDate(2026, 11, 6));
    expect(ended.lastDay, LocalDate(2026, 11, 6));
    expect(ended.covers(LocalDate(2026, 11, 7)), isFalse);
    final emptied = pause('p', wed, sun, today);
    expect(emptied.isEmpty, isTrue);
    expect(emptied.activeOn(today), isFalse);
  });

  test(
    'F31-V1, V2, V3: ngày bắt đầu đã qua, B trước A, sửa B về ngày đã qua',
    () {
      PauseError? check(SchedulePause? before, SchedulePause after) =>
          PauseRules.check(
            before: before,
            after: after,
            others: const [],
            today: today,
          );
      expect(check(null, pause('p', today, today)), isNull);
      expect(
        check(null, pause('p', today.addDays(-1), sun)),
        PauseError.startInPast,
      );
      expect(check(null, pause('p', sun, wed)), PauseError.endBeforeStart);
      final started = pause('p', LocalDate(2026, 11, 1), sun);
      expect(
        check(
          started,
          pause('p', LocalDate(2026, 11, 1), LocalDate(2026, 11, 2)),
        ),
        PauseError.endInPast,
      );
      expect(
        check(
          started,
          pause('p', LocalDate(2026, 11, 1), sun, today.addDays(-1)),
        ),
        isNull,
        reason: 'kết thúc sớm = hôm qua',
      );
      expect(
        check(
          started,
          pause('p', LocalDate(2026, 11, 1), sun, LocalDate(2026, 10, 30)),
        ),
        PauseError.endedOnOutOfRange,
      );
    },
  );

  test('F31-R1, F31-AC6: một khoảng hiệu lực tại một thời điểm', () {
    final first = pause('a', wed, sun);
    expect(
      PauseRules.check(
        before: null,
        after: pause('b', LocalDate(2026, 11, 10), LocalDate(2026, 11, 12)),
        others: [first],
        today: today,
      ),
      PauseError.overlap,
    );
    final finished = pause(
      'a',
      LocalDate(2026, 10, 20),
      LocalDate(2026, 10, 25),
    );
    expect(
      PauseRules.check(
        before: null,
        after: pause('b', wed, sun),
        others: [finished],
        today: today,
      ),
      isNull,
    );
  });
}
