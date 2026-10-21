import 'package:domain/domain.dart';

import 'codecs.dart';
import 'json_reader.dart';
import 'sync_entities.dart';

/// Entity `exercise` (chỉ pull, dòng dùng chung, key = `id`, 06 Bản 3 §6.5.1):
/// mọi cột của `exercises` trừ `library_version`, `equipment`, `deleted`, tên
/// camelCase. Bài bỏ ở Bản 3 là tombstone (`deleted` của thay đổi). Server
/// gửi dạng Bản 2 (có `equipment`, không có `sortInGroup`) cho app < 3.0.0
/// (TD3-21); app Bản 3 bỏ qua trường thừa.
final class ExerciseCodec {
  const ExerciseCodec();

  String get entity => SyncEntities.exercise;

  Exercise decode(String key, Map<String, Object?> data) {
    final r = JsonReader(data, path: 'data');
    final region = MuscleRegion.tryParse(r.string('muscleRegion'));
    if (region == null || region.group.name != r.string('muscleGroup')) {
      throw const ContractFormatException('data.muscleRegion');
    }
    final reason = r.optString('videoUnavailableReason');
    List<String> strings(String k) => [
      for (final s in r.list(k))
        s is String ? s : throw ContractFormatException('data.$k'),
    ];
    return Exercise(
      id: key,
      region: region,
      nameVi: r.string('nameVi'),
      nameEn: r.optString('nameEn'),
      youtubeVideoId: r.string('youtubeVideoId'),
      videoChannel: r.string('videoChannel'),
      videoDurationS: r.optInteger('videoDurationS'),
      videoAvailable: r.boolean('videoAvailable'),
      videoUnavailableReason: reason == null
          ? null
          : VideoUnavailableReason.tryParse(reason) ??
                (throw const ContractFormatException(
                  'data.videoUnavailableReason',
                )),
      videoCheckedAt: r.has('videoCheckedAt')
          ? r.decoded('videoCheckedAt', InstantCodec.decode)
          : null,
      guideSteps: strings('guideSteps'),
      guideSafety: strings('guideSafety'),
      approvedAt: r.decoded('approvedAt', DateCodec.decode),
      sortInGroup: r.integer('sortInGroup'),
      sortOrder: r.integer('sortOrder'),
      active: r.boolean('active'),
    );
  }

  Map<String, Object?> encode(Exercise e) => {
    'muscleGroup': e.group.name,
    'muscleRegion': e.region.id,
    'logsWeight': e.logsWeight,
    'nameVi': e.nameVi,
    'nameEn': e.nameEn,
    'youtubeVideoId': e.youtubeVideoId,
    'videoChannel': e.videoChannel,
    'videoDurationS': e.videoDurationS,
    'videoAvailable': e.videoAvailable,
    'videoCheckedAt': e.videoCheckedAt == null
        ? null
        : InstantCodec.encode(e.videoCheckedAt!.toUtc()),
    'videoUnavailableReason': e.videoUnavailableReason?.wire,
    'guideSteps': e.guideSteps,
    'guideSafety': e.guideSafety,
    'approvedAt': DateCodec.encode(e.approvedAt),
    'sortInGroup': e.sortInGroup,
    'sortOrder': e.sortOrder,
    'active': e.active,
  };
}
