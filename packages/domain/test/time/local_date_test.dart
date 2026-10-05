import 'package:domain/domain.dart';
import 'package:test/test.dart';

void main() {
  group('LocalDate', () {
    test('parse và toKey khứ hồi YYYY-MM-DD', () {
      final d = LocalDate.parse('2026-10-07');
      expect(d, LocalDate(2026, 10, 7));
      expect(d.toKey(), '2026-10-07');
    });

    test('parse từ chối định dạng sai và ngày không tồn tại', () {
      for (final bad in [
        '2026-1-07',
        '07/10/2026',
        '2026-13-01',
        '2026-02-29',
        '2026-04-31',
        '',
        '2026-10-07T00:00',
      ]) {
        expect(() => LocalDate.parse(bad), throwsFormatException, reason: bad);
        expect(LocalDate.tryParse(bad), isNull, reason: bad);
      }
    });

    test('năm nhuận: 29/02 có ở 2024 và 2000, không có ở 2026 và 1900', () {
      expect(LocalDate.parse('2024-02-29').addDays(1), LocalDate(2024, 3, 1));
      expect(LocalDate.parse('2000-02-29'), LocalDate(2000, 2, 29));
      expect(() => LocalDate(2026, 2, 29), throwsArgumentError);
      expect(() => LocalDate(1900, 2, 29), throwsArgumentError);
      expect(LocalDate(2026, 2, 28).addDays(1), LocalDate(2026, 3, 1));
    });

    test('weekday: 07/10/2026 là thứ 4, 18/10/2026 là chủ nhật', () {
      expect(LocalDate(2026, 10, 7).weekday, DateTime.wednesday);
      expect(LocalDate(2026, 10, 18).isSunday, isTrue);
    });

    test('addDays và daysUntil qua tháng, qua năm', () {
      expect(LocalDate(2026, 12, 31).addDays(1), LocalDate(2027, 1, 1));
      expect(LocalDate(2026, 3, 1).addDays(-1), LocalDate(2026, 2, 28));
      expect(LocalDate(2026, 10, 7).daysUntil(LocalDate(2026, 10, 14)), 7);
      expect(LocalDate(2026, 10, 14).daysUntil(LocalDate(2026, 10, 7)), -7);
    });

    test('addDays không lệch khi qua mốc đổi giờ mùa hè', () {
      // Tính theo UTC nên không phụ thuộc DST của máy chạy test.
      expect(LocalDate(2026, 3, 8).addDays(1), LocalDate(2026, 3, 9));
      expect(LocalDate(2026, 3, 29).addDays(1), LocalDate(2026, 3, 30));
    });

    test('so sánh và bằng nhau', () {
      final a = LocalDate(2026, 10, 7);
      final b = LocalDate(2026, 10, 8);
      expect(a < b, isTrue);
      expect(b > a, isTrue);
      expect(a <= LocalDate(2026, 10, 7), isTrue);
      expect(a == LocalDate(2026, 10, 7), isTrue);
      expect({a, LocalDate(2026, 10, 7)}.length, 1);
    });

    test('fromDateTime lấy ngày theo giờ địa phương của DateTime', () {
      expect(
        LocalDate.fromDateTime(DateTime(2026, 10, 7, 23, 59)),
        LocalDate(2026, 10, 7),
      );
      expect(
        LocalDate(2026, 10, 7).atTime(LocalTime(18, 0)),
        DateTime(2026, 10, 7, 18),
      );
    });
  });

  group('LocalTime', () {
    test('parse/toKey HH:mm', () {
      expect(LocalTime.parse('18:00'), LocalTime(18, 0));
      expect(LocalTime(7, 5).toKey(), '07:05');
      expect(LocalTime.parse('00:00').minutesOfDay, 0);
      expect(LocalTime.parse('23:55').minutesOfDay, 23 * 60 + 55);
    });

    test('parse từ chối giá trị sai', () {
      for (final bad in ['24:00', '18:60', '8:00', '18.00', '']) {
        expect(() => LocalTime.parse(bad), throwsFormatException, reason: bad);
      }
    });

    test('so sánh', () {
      expect(LocalTime(17, 59).isBefore(LocalTime(18, 0)), isTrue);
      expect(LocalTime(18, 0).compareTo(LocalTime(18, 0)), 0);
    });
  });
}
