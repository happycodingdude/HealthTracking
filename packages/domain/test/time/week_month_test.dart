import 'package:domain/domain.dart';
import 'package:test/test.dart';

void main() {
  group('Week (FR-08)', () {
    test('FR-08: tuần từ thứ 2 đến chủ nhật', () {
      final w = Week.containing(LocalDate(2026, 10, 7));
      expect(w.start, LocalDate(2026, 10, 5));
      expect(w.end, LocalDate(2026, 10, 11));
      expect(w.days, hasLength(7));
      expect(w.contains(LocalDate(2026, 10, 11)), isTrue);
      expect(w.contains(LocalDate(2026, 10, 12)), isFalse);
    });

    test('FR-08: chủ nhật thuộc tuần bắt đầu từ thứ 2 trước đó', () {
      expect(
        Week.containing(LocalDate(2026, 10, 18)).start,
        LocalDate(2026, 10, 12),
      );
      expect(
        Week.containing(LocalDate(2026, 10, 12)).start,
        LocalDate(2026, 10, 12),
      );
    });

    test('FR-08: tuần vắt qua hai tháng', () {
      final w = Week.containing(LocalDate(2026, 10, 1));
      expect(w.start, LocalDate(2026, 9, 28));
      expect(w.end, LocalDate(2026, 10, 4));
      expect(w.days.map((d) => d.month).toSet(), {9, 10});
    });

    test('FR-08: tuần vắt qua hai năm', () {
      final w = Week.containing(LocalDate(2027, 1, 1));
      expect(w.start, LocalDate(2026, 12, 28));
      expect(w.next.start, LocalDate(2027, 1, 4));
      expect(w.previous.start, LocalDate(2026, 12, 21));
    });
  });

  group('ProgressWeek (FR-20)', () {
    test('FR-20: tuần tiến độ từ thứ 2 đến thứ 7, không gồm chủ nhật', () {
      final w = ProgressWeek.containing(LocalDate(2026, 10, 14));
      expect(w.start, LocalDate(2026, 10, 12));
      expect(w.end, LocalDate(2026, 10, 17));
      expect(w.days, hasLength(6));
      expect(w.days.any((d) => d.isSunday), isFalse);
      expect(w.contains(LocalDate(2026, 10, 18)), isFalse);
    });

    test('FR-20: kết thúc lúc 00:00 chủ nhật', () {
      final w = ProgressWeek.containing(LocalDate(2026, 10, 14));
      expect(w.endsAt, DateTime(2026, 10, 18));
    });

    test('FR-20: tuần tiến độ vắt qua hai tháng (28/09 → 03/10/2026)', () {
      final w = ProgressWeek.containing(LocalDate(2026, 10, 2));
      expect(w.start, LocalDate(2026, 9, 28));
      expect(w.end, LocalDate(2026, 10, 3));
    });
  });

  group('YearMonth', () {
    test('độ dài tháng, kể cả tháng 2 năm nhuận', () {
      expect(YearMonth(2026, 2).lengthInDays, 28);
      expect(YearMonth(2024, 2).lengthInDays, 29);
      expect(YearMonth(2000, 2).lengthInDays, 29);
      expect(YearMonth(1900, 2).lengthInDays, 28);
      expect(YearMonth(2026, 10).lengthInDays, 31);
      expect(YearMonth(2026, 11).lengthInDays, 30);
    });

    test('ngày đầu, ngày cuối, danh sách ngày', () {
      final m = YearMonth(2026, 10);
      expect(m.firstDay, LocalDate(2026, 10, 1));
      expect(m.lastDay, LocalDate(2026, 10, 31));
      expect(m.days, hasLength(31));
      expect(m.contains(LocalDate(2026, 10, 31)), isTrue);
      expect(m.contains(LocalDate(2026, 11, 1)), isFalse);
    });

    test('tháng sau, tháng trước, qua năm', () {
      expect(YearMonth(2026, 12).next, YearMonth(2027, 1));
      expect(YearMonth(2027, 1).previous, YearMonth(2026, 12));
      expect(LocalDate(2026, 10, 31).yearMonth.next, YearMonth(2026, 11));
    });

    test('parse/toKey YYYY-MM', () {
      expect(YearMonth.parse('2026-10'), YearMonth(2026, 10));
      expect(YearMonth(2026, 1).toKey(), '2026-01');
      expect(() => YearMonth.parse('2026-13'), throwsFormatException);
      expect(() => YearMonth.parse('2026-1'), throwsFormatException);
    });
  });

  group('Clock (IS-5)', () {
    test('FixedClock trả đúng mốc đã đặt, tua được', () {
      final clock = FixedClock(DateTime(2026, 10, 31, 23, 59));
      expect(clock.today(), LocalDate(2026, 10, 31));
      clock.advance(const Duration(minutes: 1));
      expect(clock.today(), LocalDate(2026, 11, 1));
      clock.set(DateTime(2026, 12, 31, 23, 59));
      expect(clock.now(), DateTime(2026, 12, 31, 23, 59));
    });

    test('SystemClock trả giờ hiện tại', () {
      final before = DateTime.now();
      final now = const SystemClock().now();
      expect(now.isBefore(before), isFalse);
    });
  });
}
