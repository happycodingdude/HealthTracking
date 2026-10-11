import 'package:domain/domain.dart';
import 'package:postgres/postgres.dart';

import '../alerts.dart';
import '../logging/logger.dart';
import '../sync/sync_service.dart';
import 'youtube_api.dart';

/// Một bài đổi trạng thái video.
typedef VideoChange = ({
  String exerciseId,
  String youtubeId,
  bool available,
  VideoUnavailableReason? reason,
});

/// Kết quả một lần kiểm tra.
final class VideoCheckResult {
  const VideoCheckResult({
    required this.checked,
    this.changes = const [],
    this.failed = false,
  });

  /// Số video đã hỏi YouTube.
  final int checked;
  final List<VideoChange> changes;

  /// Gọi API lỗi: không đổi gì, thử lại lần sau.
  final bool failed;

  String describe() {
    if (failed) {
      return 'Không gọi được YouTube Data API: giữ nguyên trạng thái, thử lại '
          'lần sau.';
    }
    final lines = [
      'Đã kiểm tra $checked video: ${changes.length} bài đổi trạng thái.',
      for (final c in changes)
        '  - ${c.exerciseId} (${c.youtubeId}): '
            '${c.available ? 'khả dụng trở lại' : 'không khả dụng (${c.reason!.wire})'}',
    ];
    return lines.join('\n');
  }
}

/// Kiểm tra video của thư viện (05 Bản 2 §6.10.3, TD2-17), dùng chung cho job
/// hằng ngày 03:30 và `admin library check-videos`:
///
/// 1. Lấy mã video của mọi bài đang có (`active`), hỏi YouTube theo lô 50.
/// 2. Khả dụng khi video còn, công khai, cho nhúng, đã xử lý xong, ≤ 60 giây.
/// 3. Chỉ ghi khi trạng thái đổi, cấp `server_version` mới (app nhận qua
///    pull → "Video không khả dụng" ở S-67); mỗi thay đổi gửi cảnh báo.
/// 4. Lỗi gọi API → giữ nguyên, ghi log, thử lại lần sau.
/// 5. Video khả dụng trở lại → tự chuyển về khả dụng. Thay video mới vẫn phải
///    qua file thư viện và Bạn duyệt (A2-02).
final class VideoCheckJob {
  VideoCheckJob({
    required SessionExecutor db,
    required YouTubeApi api,
    required Alerts alerts,
    required Logger logger,
  }) : _db = db,
       _api = api,
       _alerts = alerts,
       _log = logger;

  final SessionExecutor _db;
  final YouTubeApi _api;
  final Alerts _alerts;
  final Logger _log;

  Future<VideoCheckResult> run() async {
    final rows = await _db.run(
      (s) => s.execute(
        'SELECT id, youtube_video_id, video_available, '
        'video_unavailable_reason FROM exercises WHERE active ORDER BY sort_order',
      ),
    );
    final ids = [for (final r in rows) r[1]! as String];
    final Map<String, VideoInfo> info;
    try {
      info = await _api.videos(ids.toSet().toList());
    } on YouTubeApiException catch (e) {
      _log.warn('video_check_failed', {'error': e.message});
      return VideoCheckResult(checked: ids.length, failed: true);
    }

    final changes = <VideoChange>[];
    for (final r in rows) {
      final v = info[r[1]! as String];
      final reason = v == null ? VideoUnavailableReason.removed : v.problem;
      final available = reason == null;
      if (available == r[2] && reason?.wire == r[3]) continue;
      changes.add((
        exerciseId: r[0]! as String,
        youtubeId: r[1]! as String,
        available: available,
        reason: reason,
      ));
    }
    if (changes.isNotEmpty) {
      await _db.runTx((tx) async {
        await SyncService.lockSharedRowsForWrite(tx);
        for (final c in changes) {
          await tx.execute(
            Sql.named('''
              UPDATE exercises SET video_available = @available,
                video_unavailable_reason = @reason, video_checked_at = now(),
                server_version = nextval('sync_version_seq'), updated_at = now()
              WHERE id = @id'''),
            parameters: {
              'id': c.exerciseId,
              'available': c.available,
              'reason': c.reason?.wire,
            },
          );
        }
      });
    }
    for (final c in changes) {
      await _alerts.warning(
        c.available
            ? 'Video thư viện khả dụng trở lại'
            : 'Video thư viện không khả dụng',
        {
          'exerciseId': c.exerciseId,
          'youtubeId': c.youtubeId,
          'reason': c.reason?.wire ?? 'available',
        },
      );
    }
    _log.info('video_check', {
      'checked': ids.length,
      'changed': changes.length,
    });
    return VideoCheckResult(checked: ids.length, changes: changes);
  }
}
