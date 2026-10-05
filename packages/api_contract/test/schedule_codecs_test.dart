import 'package:api_contract/api_contract.dart';
import 'package:domain/domain.dart';
import 'package:test/test.dart';

void main() {
  final template = WeeklyTemplate({
    1: TemplateDay(
      enabled: true,
      time: LocalTime(18, 0),
      muscles: const [MuscleGroup.chest, MuscleGroup.triceps],
    ),
  });

  test('weekly_template: days + contentHash; hash sai bị từ chối', () {
    final json = const WeeklyTemplateCodec().encode(template);
    expect(json['contentHash'], template.contentHash);
    expect(const WeeklyTemplateCodec().decode(json), template);
    expect(
      () => const WeeklyTemplateCodec().decode({
        ...json,
        'contentHash': '0' * 64,
      }),
      throwsA(
        isA<ContractFormatException>().having(
          (e) => e.field,
          'field',
          'data.contentHash',
        ),
      ),
    );
    expect(
      () => const WeeklyTemplateCodec().decode({
        'days': {
          '7': {'enabled': false},
        },
        'contentHash': '0' * 64,
      }),
      throwsA(
        isA<ContractFormatException>().having(
          (e) => e.field,
          'field',
          'data.days',
        ),
      ),
    );
  });

  test('month_plan khứ hồi, key YYYY-MM', () {
    final plan = MonthPlan(
      month: YearMonth(2026, 10),
      startDate: LocalDate(2026, 10, 7),
      templateHash: template.contentHash,
      generatedAt: DateTime.utc(2026, 10, 7, 5),
    );
    final json = const MonthPlanCodec().encode(plan);
    expect(json, {
      'startDate': '2026-10-07',
      'templateHash': template.contentHash,
      'generatedAt': '2026-10-07T05:00:00.000Z',
      'redistributedAt': null,
    });
    expect(MonthPlanCodec.keyOf(plan.month), '2026-10');
    expect(const MonthPlanCodec().decode('2026-10', json), plan);
  });

  test('day khứ hồi; ngày nghỉ không có giờ và nhóm cơ', () {
    final workout = PlanDay(
      date: LocalDate(2026, 10, 5),
      kind: DayKind.workout,
      time: LocalTime(18, 0),
      muscles: const [MuscleGroup.chest, MuscleGroup.triceps],
    );
    final json = const DayCodec().encode(workout);
    expect(json['muscles'], ['chest', 'triceps']);
    expect(json['time'], '18:00');
    expect(json['source'], 'template');
    expect(const DayCodec().decode('2026-10-05', json), workout);

    final rest = PlanDay(date: LocalDate(2026, 10, 6), kind: DayKind.rest);
    final restJson = const DayCodec().encode(rest);
    expect((restJson['time'], restJson['muscles']), (null, null));
    expect(const DayCodec().decode('2026-10-06', restJson), rest);
    expect(
      () => const DayCodec().decode('2026-10-06', {...restJson, 'kind': 'x'}),
      throwsA(isA<ContractFormatException>()),
    );
  });
}
