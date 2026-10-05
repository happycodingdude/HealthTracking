import 'package:api_contract/api_contract.dart';
import 'package:domain/domain.dart';
import 'package:test/test.dart';

void main() {
  test('DateCodec YYYY-MM-DD khứ hồi', () {
    final d = LocalDate(2026, 10, 7);
    expect(DateCodec.encode(d), '2026-10-07');
    expect(DateCodec.decode('2026-10-07'), d);
    expect(() => DateCodec.decode('07/10/2026'), throwsFormatException);
  });

  test('TimeCodec HH:mm khứ hồi', () {
    expect(TimeCodec.encode(LocalTime(18, 0)), '18:00');
    expect(TimeCodec.decode('07:05'), LocalTime(7, 5));
    expect(() => TimeCodec.decode('7:05'), throwsFormatException);
  });

  group('InstantCodec', () {
    test('UTC → hậu tố Z, mili giây', () {
      final t = DateTime.utc(2026, 10, 7, 11, 42, 10, 5);
      expect(InstantCodec.encode(t), '2026-10-07T11:42:10.005Z');
      expect(InstantCodec.decode('2026-10-07T11:42:10.005Z'), t);
    });

    test('giờ địa phương → có offset, giải mã về cùng thời điểm', () {
      final local = DateTime(2026, 10, 7, 18, 42, 10);
      final encoded = InstantCodec.encode(local);
      expect(
        encoded,
        matches(RegExp(r'^2026-10-07T18:42:10\.000[+-]\d{2}:\d{2}$')),
      );
      expect(InstantCodec.decode(encoded), local.toUtc());
    });

    test('đọc ví dụ của 05 §6.6.2 (+07:00)', () {
      expect(
        InstantCodec.decode('2026-10-07T18:42:10+07:00'),
        DateTime.utc(2026, 10, 7, 11, 42, 10),
      );
    });

    test('từ chối chuỗi thiếu múi giờ hoặc sai định dạng', () {
      for (final bad in ['2026-10-07T18:42:10', '2026-10-07', 'abc', '']) {
        expect(
          () => InstantCodec.decode(bad),
          throwsFormatException,
          reason: bad,
        );
        expect(InstantCodec.tryDecode(bad), isNull);
      }
    });
  });

  group('JsonReader', () {
    test('đọc đúng kiểu, báo tên trường khi sai', () {
      final r = JsonReader({
        'a': 'x',
        'n': 3,
        'b': true,
        'o': {'d': '2026-10-07'},
      });
      expect(r.string('a'), 'x');
      expect(r.integer('n'), 3);
      expect(r.boolean('b'), isTrue);
      expect(r.optString('missing'), isNull);
      expect(
        r.object('o').decoded('d', DateCodec.decode),
        LocalDate(2026, 10, 7),
      );
      expect(
        () => r.string('n'),
        throwsA(
          isA<ContractFormatException>().having((e) => e.field, 'field', 'n'),
        ),
      );
      expect(
        () => r.object('o').decoded('missing', DateCodec.decode),
        throwsA(
          isA<ContractFormatException>().having(
            (e) => e.field,
            'field',
            'o.missing',
          ),
        ),
      );
      expect(
        () => JsonReader({
          'o': {'d': 'x'},
        }).object('o').decoded('d', DateCodec.decode),
        throwsA(
          isA<ContractFormatException>().having((e) => e.field, 'field', 'o.d'),
        ),
      );
    });

    test('body không phải object', () {
      expect(
        () => JsonReader([1, 2]),
        throwsA(
          isA<ContractFormatException>().having(
            (e) => e.field,
            'field',
            'body',
          ),
        ),
      );
    });
  });
}
