import 'package:api_contract/api_contract.dart';
import 'package:postgres/postgres.dart';

import 'sync_entity_handler.dart';
import 'sync_service.dart';

/// Thời điểm ISO 8601 UTC, độ chính xác mili giây (05 §6.8.1).
String _instant(String column) =>
    '''to_char($column AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"')''';

/// Dòng dùng chung (05 Bản 2 §6.6.1, AP-7): không có `user_id`, chỉ server
/// ghi, mọi tài khoản cùng nhận. `server_version` lấy từ cùng sequence toàn
/// cục nên pull của mỗi tài khoản = dòng của tài khoản ∪ dòng dùng chung có
/// `server_version > cursor`, không bỏ sót (06 Bản 2 VS20-T08).
abstract base class SharedPullHandler extends PullOnlyHandler {
  const SharedPullHandler();

  @override
  Future<SyncChange?> read(Session s, String userId, String key) async {
    final rows = await s.execute(
      Sql.named('SELECT * FROM ($pullSql) c WHERE key = @key'),
      parameters: {'cursor': 0, 'key': key},
    );
    return rows.isEmpty ? null : changeFromRow(rows.first);
  }
}

/// Entity `exercise`, key = `id` (06 Bản 3 §6.5.1): mọi cột của `exercises`
/// trừ `library_version`, `equipment`. 14 bài bỏ ở Bản 3 là tombstone
/// (`deleted`, TR3-09); bài gỡ sau ra mắt vẫn gửi với `active = false`
/// (F18-R46).
///
/// App < 3.0.0 (TD3-21, 05 Bản 3 §6.6.7): dạng Bản 2 kèm `equipment`; chỉ gửi
/// tombstone và dòng app 2.x đọc được (có `equipment`, không phải nhóm Chân),
/// dòng khác có `entity` = [SyncService.skippedEntity].
final class ExerciseHandler extends SharedPullHandler implements VersionedPull {
  const ExerciseHandler();

  @override
  String get entity => SyncEntities.exercise;

  @override
  String pullSqlFor(AppVersion? appVersion) =>
      appVersion != null && appVersion >= AppVersion.v3 ? pullSql : _legacySql;

  static String _common(String extra) =>
      '''
             'muscleGroup', muscle_group::text,
             'muscleRegion', muscle_region,$extra
             'logsWeight', logs_weight,
             'nameVi', name_vi,
             'nameEn', name_en,
             'youtubeVideoId', youtube_video_id,
             'videoChannel', video_channel,
             'videoDurationS', video_duration_s,
             'videoAvailable', video_available,
             'videoCheckedAt', ${_instant('video_checked_at')},
             'videoUnavailableReason', video_unavailable_reason,
             'guideSteps', to_jsonb(guide_steps),
             'guideSafety', to_jsonb(guide_safety),
             'approvedAt', to_char(approved_at, 'YYYY-MM-DD'),''';

  @override
  String get pullSql =>
      '''
    SELECT 'exercise'::text AS entity, id AS key, deleted, server_version,
           CASE WHEN deleted THEN NULL ELSE jsonb_build_object(${_common('')}
             'sortInGroup', sort_in_group,
             'sortOrder', sort_order,
             'active', active) END AS data
    FROM exercises
    WHERE server_version > @cursor''';

  static final _legacySql =
      '''
    SELECT CASE WHEN deleted OR (equipment IS NOT NULL AND muscle_group <> 'legs')
                THEN 'exercise' ELSE '${SyncService.skippedEntity}' END::text AS entity,
           id AS key, deleted, server_version,
           CASE WHEN deleted OR equipment IS NULL OR muscle_group = 'legs' THEN NULL
                ELSE jsonb_build_object(${_common("\n             'equipment', equipment::text,")}
             'sortOrder', sort_order,
             'active', active) END AS data
    FROM exercises
    WHERE server_version > @cursor''';
}

/// Entity `dish_image`, key = `name_key` (06 Bản 2 §6.5.1): thông tin hình,
/// không gồm file. Không bao giờ xóa (FA2-16).
final class DishImageHandler extends SharedPullHandler {
  const DishImageHandler();

  @override
  String get entity => SyncEntities.dishImage;

  @override
  String get pullSql =>
      '''
    SELECT 'dish_image'::text AS entity, name_key AS key, false AS deleted, server_version,
           jsonb_build_object(
             'id', id::text,
             'nameKey', name_key,
             'displayName', display_name,
             'width', width,
             'height', height,
             'bytes', bytes,
             'createdAt', ${_instant('created_at')}) AS data
    FROM dish_images
    WHERE server_version > @cursor''';
}
