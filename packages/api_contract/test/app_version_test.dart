import 'package:api_contract/api_contract.dart';
import 'package:test/test.dart';

void main() {
  group('AppVersion (05 Bản 2 TD2-15, TR2-13)', () {
    test('đọc semver, bỏ phần build; so sánh theo major → minor → patch', () {
      expect(AppVersion.parse('2.0.0'), AppVersion.v2);
      expect(AppVersion.parse('2.0.0+17'), AppVersion.v2);
      expect(AppVersion.parse('2.10.3').toString(), '2.10.3');
      expect(AppVersion.parse('2.10.0') >= AppVersion.parse('2.9.9'), isTrue);
      expect(AppVersion.parse('1.9.9') < AppVersion.v2, isTrue);
      expect(AppVersion.parse('3.0.0') >= AppVersion.v2, isTrue);
    });

    test('giá trị lạ → null (server coi như app Bản 1)', () {
      for (final bad in [null, '', 'abc', '2.0', '2.0.0-beta', 'v2.0.0']) {
        expect(AppVersion.tryParse(bad), isNull, reason: '$bad');
      }
      expect(() => AppVersion.parse('2'), throwsFormatException);
    });

    test('tên header', () => expect(AppVersion.header, 'X-App-Version'));
  });
}
