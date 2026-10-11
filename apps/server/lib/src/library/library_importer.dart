import 'package:domain/domain.dart';
import 'package:postgres/postgres.dart';

import 'library_file.dart';

/// Kết quả `admin library import` (05 Bản 2 §6.10.2 bước 5).
final class ImportReport {
  const ImportReport({
    required this.total,
    this.issues = const [],
    this.added = 0,
    this.updated = 0,
    this.deactivated = 0,
    this.checkOnly = false,
  });

  /// Số bài trong file.
  final int total;

  /// Lỗi làm từ chối toàn bộ; rỗng = đạt.
  final List<String> issues;
  final int added;
  final int updated;
  final int deactivated;
  final bool checkOnly;

  bool get ok => issues.isEmpty;

  /// Tóm tắt để in ra màn hình.
  String describe() {
    if (!ok) {
      return [
        'Từ chối: ${issues.length} lỗi, database không đổi.',
        for (final i in issues) '  - $i',
      ].join('\n');
    }
    if (checkOnly) {
      return 'Đạt: $total bài, đủ 6 nhóm cơ (F18-R1), đủ điều kiện ra mắt '
          '(LIB-AC1 → AC4). Chưa ghi gì vào database.';
    }
    return 'Đã nạp $total bài: thêm $added, sửa $updated, rời thư viện '
        '$deactivated.';
  }
}

/// Nạp thư viện từ file đã duyệt (05 Bản 2 §6.10.2, 06 Bản 2 VS21-T03):
///
/// 1. Kiểm cấu trúc từng bài ([LibraryRules.entryErrors]; `--check-only`
///    thêm điều kiện ra mắt [LibraryRules.releaseErrors]).
/// 2. Kiểm F18-R1, LIB-R8 trên trạng thái **sau khi nạp** (đúng tập bài trong
///    file). Không đạt → từ chối toàn bộ, không đổi gì.
/// 3. `sort_order` theo F18-R9.
/// 4. Một transaction: bài không còn trong file → `active = false` (không
///    xóa, TA2-10); upsert từng bài; chỉ dòng thay đổi được cấp
///    `server_version` mới. Thay video (`youtube_video_id` khác) thì trạng thái
///    video làm lại từ đầu; `id` giữ nguyên nên lịch sử mức tạ còn (FA2-14).
final class LibraryImporter {
  LibraryImporter(this._db);

  /// Pool của server hoặc một kết nối (công cụ dev `tool/seed_dev.dart`).
  final SessionExecutor _db;

  /// Khóa advisory: hai lần nạp không chạy chồng nhau.
  static const _lockKey = 7426003;

  Future<ImportReport> run(LibraryFile file, {bool checkOnly = false}) async {
    final issues = <String>[
      for (final e in file.exercises)
        for (final field
            in checkOnly
                ? LibraryRules.releaseErrors(e).toSet()
                : LibraryRules.entryErrors(e))
          '${e.id}: $field',
      for (final i in LibraryRules.coverageErrors(file.exercises))
        i.exerciseId == null ? i.rule : '${i.exerciseId}: ${i.rule}',
    ];
    final total = file.exercises.length;
    if (issues.isNotEmpty || checkOnly) {
      return ImportReport(total: total, issues: issues, checkOnly: checkOnly);
    }

    final sorted = LibraryRules.sorted(file.exercises);
    return _db.runTx((tx) async {
      await tx.execute(
        Sql.named('SELECT pg_advisory_xact_lock(@k)'),
        parameters: {'k': _lockKey},
      );
      final ids = [for (final e in sorted) e.id];
      final gone = await tx.execute(
        Sql.named('''
          UPDATE exercises SET active = false,
            server_version = nextval('sync_version_seq'), updated_at = now()
          WHERE active AND NOT (id = ANY(@ids::text[]))'''),
        parameters: {'ids': ids},
      );
      var added = 0, updated = 0;
      for (final e in sorted) {
        final rows = await tx.execute(
          _upsert,
          parameters: _params(e, file.libraryVersion),
        );
        if (rows.isEmpty) continue;
        if (rows.single[0] == true) {
          added++;
        } else {
          updated++;
        }
      }
      await tx.execute(
        Sql.named('''
          UPDATE exercises SET library_version = @v
          WHERE id = ANY(@ids::text[]) AND library_version <> @v'''),
        parameters: {'v': file.libraryVersion, 'ids': ids},
      );
      return ImportReport(
        total: total,
        added: added,
        updated: updated,
        deactivated: gone.affectedRows,
      );
    });
  }

  static final _upsert = Sql.named('''
    INSERT INTO exercises AS x (id, muscle_group, muscle_region, equipment, logs_weight, name_vi,
                                name_en, youtube_video_id, video_channel, video_duration_s,
                                guide_steps, guide_safety, approved_at, sort_order, active,
                                library_version, server_version)
    VALUES (@id, @group::muscle_group, @region, @equipment::equipment, @logsWeight, @nameVi,
            @nameEn, @youtubeId, @channel, @duration, @steps::text[], @safety::text[],
            @approvedAt::date, @sortOrder, true, @libraryVersion, nextval('sync_version_seq'))
    ON CONFLICT (id) DO UPDATE SET
      muscle_group = EXCLUDED.muscle_group,
      muscle_region = EXCLUDED.muscle_region,
      equipment = EXCLUDED.equipment,
      logs_weight = EXCLUDED.logs_weight,
      name_vi = EXCLUDED.name_vi,
      name_en = EXCLUDED.name_en,
      youtube_video_id = EXCLUDED.youtube_video_id,
      video_channel = EXCLUDED.video_channel,
      video_duration_s = EXCLUDED.video_duration_s,
      video_available = CASE WHEN x.youtube_video_id = EXCLUDED.youtube_video_id
                             THEN x.video_available ELSE true END,
      video_unavailable_reason = CASE WHEN x.youtube_video_id = EXCLUDED.youtube_video_id
                                      THEN x.video_unavailable_reason ELSE NULL END,
      video_checked_at = CASE WHEN x.youtube_video_id = EXCLUDED.youtube_video_id
                              THEN x.video_checked_at ELSE NULL END,
      guide_steps = EXCLUDED.guide_steps,
      guide_safety = EXCLUDED.guide_safety,
      approved_at = EXCLUDED.approved_at,
      sort_order = EXCLUDED.sort_order,
      active = true,
      library_version = EXCLUDED.library_version,
      server_version = EXCLUDED.server_version,
      updated_at = now()
    WHERE (x.muscle_group, x.muscle_region, x.equipment, x.logs_weight, x.name_vi, x.name_en,
           x.youtube_video_id, x.video_channel, x.video_duration_s, x.guide_steps,
           x.guide_safety, x.approved_at, x.sort_order, x.active)
          IS DISTINCT FROM
          (EXCLUDED.muscle_group, EXCLUDED.muscle_region, EXCLUDED.equipment,
           EXCLUDED.logs_weight, EXCLUDED.name_vi, EXCLUDED.name_en, EXCLUDED.youtube_video_id,
           EXCLUDED.video_channel, EXCLUDED.video_duration_s, EXCLUDED.guide_steps,
           EXCLUDED.guide_safety, EXCLUDED.approved_at, EXCLUDED.sort_order, true)
    RETURNING (xmax = 0) AS inserted''');

  static Map<String, Object?> _params(Exercise e, int libraryVersion) => {
    'id': e.id,
    'group': e.group.name,
    'region': e.region.id,
    'equipment': e.equipment.wire,
    'logsWeight': e.logsWeight,
    'nameVi': e.nameVi,
    'nameEn': e.nameEn,
    'youtubeId': e.youtubeVideoId,
    'channel': e.videoChannel,
    'duration': e.videoDurationS,
    'steps': e.guideSteps,
    'safety': e.guideSafety,
    'approvedAt': e.approvedAt.toKey(),
    'sortOrder': e.sortOrder,
    'libraryVersion': libraryVersion,
  };
}
