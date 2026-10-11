import 'package:api_contract/api_contract.dart';
import 'package:domain/domain.dart';
import 'package:test/test.dart';

void main() {
  const codec = LiftLogCodec();
  final log = LiftLog(
    date: LocalDate(2026, 11, 12),
    exerciseId: 'chest-upper-db-incline-press',
    startKgX10: 120,
    endKgX10: 140,
  );

  test('05 Bản 2 §6.6.2: key {date}:{exerciseId}, khứ hồi đúng', () {
    expect(log.key, '2026-11-12:chest-upper-db-incline-press');
    final data = codec.encode(log);
    expect(data, {
      'date': '2026-11-12',
      'exerciseId': 'chest-upper-db-incline-press',
      'startKgX10': 120,
      'endKgX10': 140,
    });
    expect(codec.decode(log.key, data), log);
  });

  test(
    'data không khớp key, key sai dạng, thiếu trường → ContractFormatException',
    () {
      final data = codec.encode(log);
      expect(
        () => codec.decode('2026-11-13:chest-upper-db-incline-press', data),
        throwsA(isA<ContractFormatException>()),
      );
      expect(
        () => codec.decode('2026-11-12:other', data),
        throwsA(isA<ContractFormatException>()),
      );
      expect(
        () => codec.decode('nokey', data),
        throwsA(isA<ContractFormatException>()),
      );
      expect(
        () => codec.decode(log.key, {...data}..remove('endKgX10')),
        throwsA(isA<ContractFormatException>()),
      );
    },
  );
}
