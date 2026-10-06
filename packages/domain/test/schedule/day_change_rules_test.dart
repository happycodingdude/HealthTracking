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

  group('đánh dấu (VS06-T03)', () {
    test('F05-R1: đánh dấu trước giờ tập → mark', () {
      final at = DateTime(2026, 10, 7, 17, 59);
      expect(DayChangeRules.check(wed, marked(DayMark.done, at), at), 'mark');
      final ok = DateTime(2026, 10, 7, 18);
      expect(DayChangeRules.check(wed, marked(DayMark.done, ok), ok), isNull);
    });

    test('F05-R2: quá 7 ngày → mark; trong hạn sửa được', () {
      final late = DateTime(2026, 10, 15, 0, 1);
      expect(
        DayChangeRules.check(wed, marked(DayMark.skipped, late), late),
        'mark',
      );
      final last = DateTime(2026, 10, 14, 23, 59);
      expect(
        DayChangeRules.check(
          marked(DayMark.done, DateTime(2026, 10, 7, 19)),
          marked(DayMark.skipped, last),
          last,
        ),
        isNull,
      );
    });

    test('bản mới tạo đã có đánh dấu cũng được kiểm tra', () {
      final at = DateTime(2026, 10, 7, 12);
      expect(DayChangeRules.check(null, marked(DayMark.done, at), at), 'mark');
    });

    test('không đổi đánh dấu → không áp quy tắc thời gian', () {
      final done = marked(DayMark.done, DateTime(2026, 10, 7, 19));
      // Ghi lại nguyên bản đã đánh dấu khi đã quá hạn.
      expect(DayChangeRules.check(done, done, DateTime(2026, 11, 1)), isNull);
      // Tạo lịch (chưa đánh dấu) trước giờ tập.
      expect(DayChangeRules.check(null, wed, DateTime(2026, 10, 1)), isNull);
    });

    test('chưa biết múi giờ → bỏ qua quy tắc thời gian', () {
      final at = DateTime(2026, 10, 7, 12);
      expect(DayChangeRules.check(wed, marked(DayMark.done, at), null), isNull);
    });
  });
}
