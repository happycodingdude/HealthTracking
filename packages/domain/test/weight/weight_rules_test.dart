import 'package:domain/domain.dart';
import 'package:test/test.dart';

void main() {
  test('FR-11: khóa tuần là thứ 2 của tuần chứa ngày', () {
    // 07/10/2026 là thứ 4; chủ nhật 11/10 vẫn thuộc tuần bắt đầu 05/10.
    expect(WeightRules.weekKey(LocalDate(2026, 10, 7)), LocalDate(2026, 10, 5));
    expect(
      WeightRules.weekKey(LocalDate(2026, 10, 11)),
      LocalDate(2026, 10, 5),
    );
    expect(
      WeightRules.weekKey(LocalDate(2026, 10, 12)),
      LocalDate(2026, 10, 12),
    );
    expect(WeightRules.isWeekKey(LocalDate(2026, 10, 5)), isTrue);
    expect(WeightRules.isWeekKey(LocalDate(2026, 10, 6)), isFalse);
  });

  test('F07-R2: không ghi cho tuần tương lai', () {
    final today = LocalDate(2026, 10, 11); // chủ nhật
    expect(WeightRules.isFutureWeek(LocalDate(2026, 10, 5), today), isFalse);
    expect(WeightRules.isFutureWeek(LocalDate(2026, 9, 28), today), isFalse);
    expect(WeightRules.isFutureWeek(LocalDate(2026, 10, 12), today), isTrue);
  });

  test('F07-V1: 30–250 kg, nhận "," và "."', () {
    expect(WeightRules.isValidInput('7,5'), isFalse);
    expect(WeightRules.isValidInput('74,6'), isTrue);
    expect(WeightRules.isValidInput('74.6'), isTrue);
    expect(WeightRules.isValidKgX10(300), isTrue);
    expect(WeightRules.isValidKgX10(2500), isTrue);
    expect(WeightRules.isValidKgX10(2501), isFalse);
    expect(WeightRules.isValidKgX10(null), isFalse);
  });
}
