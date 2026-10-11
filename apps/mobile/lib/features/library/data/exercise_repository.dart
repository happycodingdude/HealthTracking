import 'dart:convert';

import 'package:api_contract/api_contract.dart';
import 'package:domain/domain.dart';
import 'package:drift/drift.dart';

import '../../../data/db/app_database.dart';

/// Bản sao chỉ đọc của thư viện (entity `exercise`, dòng dùng chung, AP-7).
/// Chỉ đồng bộ ghi vào; app không thêm, sửa, xóa bài (F18-AC7).
final class ExerciseRepository {
  ExerciseRepository(this._db);

  final AppDatabase _db;

  /// Ghi bản từ server (pull).
  Future<void> put(Exercise e) => _db
      .into(_db.exercises)
      .insertOnConflictUpdate(
        ExercisesCompanion.insert(
          id: e.id,
          muscleGroup: e.group.name,
          muscleRegion: e.region.id,
          equipment: e.equipment.wire,
          logsWeight: e.logsWeight,
          nameVi: e.nameVi,
          nameEn: Value(e.nameEn),
          youtubeVideoId: e.youtubeVideoId,
          videoChannel: e.videoChannel,
          videoDurationS: Value(e.videoDurationS),
          videoAvailable: e.videoAvailable,
          videoCheckedAt: Value(e.videoCheckedAt),
          videoUnavailableReason: Value(e.videoUnavailableReason?.wire),
          guideSteps: jsonEncode(e.guideSteps),
          guideSafety: jsonEncode(e.guideSafety),
          approvedAt: e.approvedAt.toKey(),
          sortOrder: e.sortOrder,
          active: e.active,
        ),
      );

  Future<void> delete(String id) =>
      (_db.delete(_db.exercises)..where((x) => x.id.equals(id))).go();

  /// Bài đang có trong thư viện của nhóm [group], thứ tự F18-R9.
  Stream<List<Exercise>> watchGroup(MuscleGroup group) =>
      (_db.select(_db.exercises)
            ..where((x) => x.muscleGroup.equals(group.name) & x.active)
            ..orderBy([(x) => OrderingTerm.asc(x.sortOrder)]))
          .watch()
          .map((rows) => [for (final r in rows) _toExercise(r)]);

  /// Một bài, kể cả bài đã rời thư viện (F19-E2). null khi chưa có.
  Stream<Exercise?> watch(String id) =>
      (_db.select(_db.exercises)..where((x) => x.id.equals(id)))
          .watchSingleOrNull()
          .map((r) => r == null ? null : _toExercise(r));

  Future<Exercise?> get(String id) async {
    final r = await (_db.select(
      _db.exercises,
    )..where((x) => x.id.equals(id))).getSingleOrNull();
    return r == null ? null : _toExercise(r);
  }

  static Exercise _toExercise(ExerciseRow r) => Exercise(
    id: r.id,
    region: MuscleRegion.tryParse(r.muscleRegion)!,
    equipment: Equipment.tryParse(r.equipment)!,
    nameVi: r.nameVi,
    nameEn: r.nameEn,
    youtubeVideoId: r.youtubeVideoId,
    videoChannel: r.videoChannel,
    videoDurationS: r.videoDurationS,
    videoAvailable: r.videoAvailable,
    videoUnavailableReason: r.videoUnavailableReason == null
        ? null
        : VideoUnavailableReason.tryParse(r.videoUnavailableReason!),
    videoCheckedAt: r.videoCheckedAt,
    guideSteps: (jsonDecode(r.guideSteps) as List).cast<String>(),
    guideSafety: (jsonDecode(r.guideSafety) as List).cast<String>(),
    approvedAt: DateCodec.decode(r.approvedAt),
    sortOrder: r.sortOrder,
    active: r.active,
  );
}
