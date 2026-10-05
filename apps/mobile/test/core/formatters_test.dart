import 'package:domain/domain.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/formatters.dart';

void main() {
  group('UR-10: định dạng kiểu Việt Nam', () {
    test('UR-10: 72,5 kg', () {
      expect(Fmt.kg(725), '72,5 kg');
      expect(Fmt.kg(800), '80 kg');
      expect(Fmt.kg(746), '74,6 kg');
      expect(Fmt.kg(30), '3 kg');
      expect(Fmt.kgNumber(1005), '100,5');
      expect(Fmt.kgNumber(2500), '250');
    });

    test('UR-10: 2.210 kcal', () {
      expect(Fmt.kcal(2210), '2.210 kcal');
      expect(Fmt.kcal(800), '800 kcal');
      expect(Fmt.kcal(1500), '1.500 kcal');
    });

    test('UR-10: 50.000đ', () {
      expect(Fmt.vnd(50000), '50.000đ');
      expect(Fmt.vnd(12500), '12.500đ');
      expect(Fmt.vnd(450), '450đ');
      expect(Fmt.vnd(0), '0đ');
      expect(Fmt.integer(1234567), '1.234.567');
      expect(Fmt.integer(-1500), '-1.500');
    });

    test('UR-10: 07/10 và 18:00', () {
      expect(Fmt.dayMonth(LocalDate(2026, 10, 7)), '07/10');
      expect(Fmt.dayMonth(LocalDate(2026, 1, 31)), '31/01');
      expect(Fmt.time(LocalTime(18, 0)), '18:00');
      expect(Fmt.time(LocalTime(7, 5)), '07:05');
      expect(Fmt.clock(DateTime(2026, 10, 7, 18, 42)), '18:42');
    });

    test('04 §6.7: Thứ 4, 07/10 và Chủ nhật', () {
      expect(Fmt.weekdayDate(LocalDate(2026, 10, 7)), 'Thứ 4, 07/10');
      expect(Fmt.weekdayDate(LocalDate(2026, 10, 5)), 'Thứ 2, 05/10');
      expect(Fmt.weekday(LocalDate(2026, 10, 18)), 'Chủ nhật');
    });
  });
}
