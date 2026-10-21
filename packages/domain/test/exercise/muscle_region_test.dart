import 'package:domain/domain.dart';
import 'package:test/test.dart';

void main() {
  test('05 Bản 3 §6.10.3: 19 vùng (16 + 3 vùng chân), đúng nhóm, đúng mặt', () {
    expect(MuscleRegion.values, hasLength(19));
    expect(
      [for (final r in MuscleRegion.values) r.id],
      [
        'chest_upper',
        'chest_mid',
        'chest_lower',
        'lats',
        'back_mid',
        'back_lower',
        'delt_front',
        'delt_side',
        'delt_rear',
        'biceps',
        'brachialis_forearm',
        'triceps_long',
        'triceps_lateral_medial',
        'abs_lower',
        'abs_mid',
        'obliques',
        'quads',
        'hamstrings',
        'calves',
      ],
    );
    expect([
      for (final r in MuscleRegion.values) r.sortOrder,
    ], List.generate(19, (i) => i + 1));
    expect(
      MuscleRegion.values.where((r) => r.view == BodyView.front),
      hasLength(11),
    );
    expect(
      MuscleRegion.values
          .where((r) => r.view == BodyView.back)
          .map((r) => r.id),
      [
        'lats',
        'back_mid',
        'back_lower',
        'delt_rear',
        'triceps_long',
        'triceps_lateral_medial',
        'hamstrings',
        'calves',
      ],
    );
  });

  test('BR2-23, BR3-11: số vùng mỗi nhóm cơ', () {
    expect(MuscleRegion.of(MuscleGroup.chest), hasLength(3));
    expect(MuscleRegion.of(MuscleGroup.back), hasLength(3));
    expect(MuscleRegion.of(MuscleGroup.shoulders), hasLength(3));
    expect(MuscleRegion.of(MuscleGroup.biceps), hasLength(2));
    expect(MuscleRegion.of(MuscleGroup.triceps), hasLength(2));
    expect(MuscleRegion.of(MuscleGroup.abs), [
      MuscleRegion.absLower,
      MuscleRegion.absMid,
      MuscleRegion.obliques,
    ]);
    expect(MuscleRegion.of(MuscleGroup.legs), [
      MuscleRegion.quads,
      MuscleRegion.hamstrings,
      MuscleRegion.calves,
    ]);
    expect(MuscleRegion.tryParse('delt_side'), MuscleRegion.deltSide);
    expect(MuscleRegion.tryParse('khong_co'), isNull);
  });
}
