import 'package:domain/domain.dart';
import 'package:postgres/postgres.dart';

/// Dọn dữ liệu kỹ thuật hằng ngày (05 §6.11, 06 VS02-T06).
final class Maintenance {
  Maintenance(this._pool, this._clock);

  final Pool<void> _pool;
  final Clock _clock;

  static const retention = Duration(days: 30);

  /// Tombstone mức tạ, ghi chú giữ 90 ngày cho máy chưa pull kịp rồi mới xóa
  /// vật lý (05 Bản 3 TD3-08).
  static const tombstoneRetention = Duration(days: 90);

  /// Xóa `processed_mutations` cũ hơn 30 ngày, refresh token đã hết hạn quá
  /// 30 ngày, tombstone `lift_logs`, `exercise_notes` quá 90 ngày. Trả số
  /// dòng đã xóa của từng bảng.
  Future<({int mutations, int refreshTokens, int liftLogs, int exerciseNotes})>
  dailyCleanup() async {
    final now = _clock.now().toUtc();
    final cutoff = now.subtract(retention);
    final mutations = await _pool.execute(
      Sql.named('DELETE FROM processed_mutations WHERE created_at < @cutoff'),
      parameters: {'cutoff': cutoff},
    );
    final tokens = await _pool.execute(
      Sql.named('DELETE FROM refresh_tokens WHERE expires_at < @cutoff'),
      parameters: {'cutoff': cutoff},
    );
    final tombstoneCutoff = {'cutoff': now.subtract(tombstoneRetention)};
    final liftLogs = await _pool.execute(
      Sql.named('DELETE FROM lift_logs WHERE deleted AND updated_at < @cutoff'),
      parameters: tombstoneCutoff,
    );
    final notes = await _pool.execute(
      Sql.named(
        'DELETE FROM exercise_notes WHERE deleted AND updated_at < @cutoff',
      ),
      parameters: tombstoneCutoff,
    );
    return (
      mutations: mutations.affectedRows,
      refreshTokens: tokens.affectedRows,
      liftLogs: liftLogs.affectedRows,
      exerciseNotes: notes.affectedRows,
    );
  }
}
