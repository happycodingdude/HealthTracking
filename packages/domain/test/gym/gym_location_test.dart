import 'package:domain/domain.dart';
import 'package:test/test.dart';

/// F32-R1, 05 Bản 5 §6.6.2 `gym_location`.
void main() {
  final at = DateTime.utc(2026, 11, 4, 10);

  test('lat ∈ [−90, 90], lng ∈ [−180, 180]', () {
    expect(
      GymLocation(lat: 10.77, lng: 106.69, savedAt: at).invalidField,
      isNull,
    );
    expect(GymLocation(lat: 90.1, lng: 0, savedAt: at).invalidField, 'lat');
    expect(GymLocation(lat: 0, lng: -180.5, savedAt: at).invalidField, 'lng');
    expect(
      GymLocation(lat: double.nan, lng: 0, savedAt: at).invalidField,
      'lat',
    );
  });

  test('TAC5-10: toString không có tọa độ', () {
    final g = GymLocation(lat: 10.770123, lng: 106.690456, savedAt: at);
    expect(g.toString(), isNot(contains('10.77')));
    expect(g.toString(), isNot(contains('106.69')));
    expect(g.withEnabled(false).enabled, isFalse);
  });
}
