import 'package:api_contract/api_contract.dart';
import 'package:domain/domain.dart';
import 'package:test/test.dart';

void main() {
  final exercise = Exercise(
    id: 'chest-upper-free-weight-incline-dumbbell-press',
    region: MuscleRegion.chestUpper,
    nameVi: 'Đẩy ngực trên với tạ đơn',
    nameEn: 'Incline Dumbbell Press',
    youtubeVideoId: 'PZecKOpWOrk',
    videoChannel: 'Barbell Logic',
    videoDurationS: 48,
    videoAvailable: false,
    videoUnavailableReason: VideoUnavailableReason.notEmbeddable,
    videoCheckedAt: DateTime.utc(2026, 10, 12, 20, 30),
    guideSteps: const ['Một', 'Hai', 'Ba'],
    guideSafety: const ['Một', 'Hai'],
    approvedAt: LocalDate(2026, 10, 11),
    sortInGroup: 2,
    sortOrder: 102,
    active: false,
  );

  test('06 Bản 3 §6.5.1: exercise khứ hồi, đúng tên trường của pull, không '
      'có equipment (TD3-20)', () {
    final json = const ExerciseCodec().encode(exercise);
    expect(json.keys.toSet(), {
      'muscleGroup',
      'muscleRegion',
      'logsWeight',
      'nameVi',
      'nameEn',
      'youtubeVideoId',
      'videoChannel',
      'videoDurationS',
      'videoAvailable',
      'videoCheckedAt',
      'videoUnavailableReason',
      'guideSteps',
      'guideSafety',
      'approvedAt',
      'sortInGroup',
      'sortOrder',
      'active',
    });
    expect(json['videoUnavailableReason'], 'not_embeddable');
    expect(const ExerciseCodec().decode(exercise.id, json), exercise);
  });

  test('vùng không thuộc nhóm cơ → lỗi hợp đồng; trường equipment cũ bị bỏ '
      'qua', () {
    final json = const ExerciseCodec().encode(exercise);
    expect(
      () => const ExerciseCodec().decode('x', {...json, 'muscleGroup': 'back'}),
      throwsA(isA<ContractFormatException>()),
    );
    expect(
      const ExerciseCodec().decode(exercise.id, {
        ...json,
        'equipment': 'machine',
      }),
      exercise,
    );
  });

  test('BR3-10, BR3-11: bài chân, vùng chân', () {
    final legs = Exercise(
      id: 'legs-quads-leg-press',
      region: MuscleRegion.quads,
      nameVi: 'Nằm máy đạp chân',
      youtubeVideoId: 'abcdefghijk',
      videoChannel: 'Kênh',
      guideSteps: const ['Một', 'Hai', 'Ba'],
      guideSafety: const ['Một', 'Hai'],
      approvedAt: LocalDate(2026, 10, 21),
      sortInGroup: 1,
      sortOrder: 701,
    );
    final json = const ExerciseCodec().encode(legs);
    expect(json['muscleGroup'], 'legs');
    expect(json['muscleRegion'], 'quads');
    expect(json['logsWeight'], isTrue);
    expect(const ExerciseCodec().decode(legs.id, json), legs);
  });

  group('exercise_unit (05 Bản 3 §6.6.2)', () {
    const codec = ExerciseUnitCodec();
    final unit = ExerciseUnit(
      exerciseId: 'chest-mid-machine-pec-deck',
      unit: LiftUnit.steps,
      changedOn: LocalDate(2026, 11, 12),
    );

    test('khứ hồi, đúng tên trường', () {
      final json = codec.encode(unit);
      expect(json, {
        'exerciseId': 'chest-mid-machine-pec-deck',
        'unit': 'steps',
        'changedOn': '2026-11-12',
      });
      expect(codec.decode(unit.exerciseId, json), unit);
    });

    test('exerciseId khác key, đơn vị lạ → lỗi hợp đồng', () {
      final json = codec.encode(unit);
      expect(
        () => codec.decode('other', json),
        throwsA(isA<ContractFormatException>()),
      );
      expect(
        () => codec.decode(unit.exerciseId, {...json, 'unit': 'plates'}),
        throwsA(
          isA<ContractFormatException>().having(
            (e) => e.field,
            'field',
            'data.unit',
          ),
        ),
      );
    });
  });

  group('exercise_note (05 Bản 3 §6.6.4)', () {
    const codec = ExerciseNoteCodec();
    final note = ExerciseNote(
      date: LocalDate(2026, 11, 12),
      exerciseId: 'chest-mid-machine-pec-deck',
      text: 'máy 2 hỏng, tập máy 5',
    );

    test('khứ hồi, key dạng {date}:{exerciseId}', () {
      final json = codec.encode(note);
      expect(note.key, '2026-11-12:chest-mid-machine-pec-deck');
      expect(json, {
        'date': '2026-11-12',
        'exerciseId': 'chest-mid-machine-pec-deck',
        'text': 'máy 2 hỏng, tập máy 5',
      });
      expect(codec.decode(note.key, json), note);
    });

    test('ngày hoặc bài khác key → lỗi hợp đồng', () {
      final json = codec.encode(note);
      expect(
        () => codec.decode('2026-11-13:chest-mid-machine-pec-deck', json),
        throwsA(isA<ContractFormatException>()),
      );
      expect(
        () => codec.decode('2026-11-12:other', json),
        throwsA(isA<ContractFormatException>()),
      );
      expect(
        () => codec.decode('sai', json),
        throwsA(isA<ContractFormatException>()),
      );
    });
  });
}
