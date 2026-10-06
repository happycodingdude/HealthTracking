import 'package:domain/domain.dart';
import 'package:test/test.dart';

void main() {
  test('F11-R1: mức trần 50.000đ/tháng', () {
    expect(AiBudgetRules.capVnd, 50000);
  });

  test('TA-17: tháng ngân sách theo giờ Việt Nam (UTC+7)', () {
    // 23:30 UTC ngày 31/10 = 06:30 ngày 01/11 giờ Việt Nam.
    expect(
      AiBudgetRules.monthOf(DateTime.utc(2026, 10, 31, 23, 30)),
      YearMonth(2026, 11),
    );
    expect(
      AiBudgetRules.monthOf(DateTime.utc(2026, 10, 31, 16, 59)),
      YearMonth(2026, 10),
    );
    expect(
      AiBudgetRules.monthOf(DateTime.utc(2026, 12, 31, 17)),
      YearMonth(2027, 1),
    );
  });

  test('F11-E2, 04 S-54: đặt lại vào 01 tháng sau', () {
    expect(
      AiBudgetRules.resetDate(YearMonth(2026, 10)),
      LocalDate(2026, 11, 1),
    );
    expect(AiBudgetRules.resetDate(YearMonth(2026, 12)), LocalDate(2027, 1, 1));
  });

  test(
    'F11-R6: phần trăm làm tròn xuống, tối đa 100 (04 S-54: 12.500đ → 25%)',
    () {
      expect(AiBudgetRules.percent(12500, 50000), 25);
      expect(AiBudgetRules.percent(39999.99, 50000), 79);
      expect(AiBudgetRules.percent(49800, 50000), 99);
      expect(AiBudgetRules.percent(0, 50000), 0);
      expect(AiBudgetRules.percent(60000, 50000), 100);
    },
  );

  test('F11-R4: đạt 80% từ 40.000đ', () {
    expect(AiBudgetRules.reachedWarning(39999.99, 50000), isFalse);
    expect(AiBudgetRules.reachedWarning(40000, 50000), isTrue);
  });
}
