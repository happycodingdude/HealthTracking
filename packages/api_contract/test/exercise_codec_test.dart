import 'package:api_contract/api_contract.dart';
import 'package:domain/domain.dart';
import 'package:test/test.dart';

void main() {
  final exercise = Exercise(
    id: 'chest-upper-free-weight-incline-dumbbell-press',
    region: MuscleRegion.chestUpper,
    equipment: Equipment.freeWeight,
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
    sortOrder: 2,
    active: false,
  );

  test('06 Bản 2 §6.5.1: exercise khứ hồi, đúng tên trường của pull', () {
    final json = const ExerciseCodec().encode(exercise);
    expect(json.keys.toSet(), {
      'muscleGroup',
      'muscleRegion',
      'equipment',
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
      'sortOrder',
      'active',
    });
    expect(json['equipment'], 'free_weight');
    expect(json['videoUnavailableReason'], 'not_embeddable');
    expect(const ExerciseCodec().decode(exercise.id, json), exercise);
  });

  test('vùng không thuộc nhóm cơ, dụng cụ lạ → lỗi hợp đồng', () {
    final json = const ExerciseCodec().encode(exercise);
    expect(
      () => const ExerciseCodec().decode('x', {...json, 'muscleGroup': 'back'}),
      throwsA(isA<ContractFormatException>()),
    );
    expect(
      () => const ExerciseCodec().decode('x', {...json, 'equipment': 'band'}),
      throwsA(isA<ContractFormatException>()),
    );
  });
}
