import 'package:domain/domain.dart';
import 'package:postgres/postgres.dart';

/// Dọn dữ liệu kỹ thuật hằng ngày (05 §6.11, 06 VS02-T06).
final class Maintenance {
  Maintenance(this._pool, this._clock);

  final Pool<void> _pool;
  final Clock _clock;

  static const retention = Duration(days: 30);

  /// Xóa `processed_mutations` cũ hơn 30 ngày và refresh token đã hết hạn quá
  /// 30 ngày. Trả số dòng đã xóa của từng bảng.
  Future<({int mutations, int refreshTokens})> dailyCleanup() async {
    final cutoff = _clock.now().toUtc().subtract(retention);
    final mutations = await _pool.execute(
      Sql.named('DELETE FROM processed_mutations WHERE created_at < @cutoff'),
      parameters: {'cutoff': cutoff},
    );
    final tokens = await _pool.execute(
      Sql.named('DELETE FROM refresh_tokens WHERE expires_at < @cutoff'),
      parameters: {'cutoff': cutoff},
    );
    return (
      mutations: mutations.affectedRows,
      refreshTokens: tokens.affectedRows,
    );
  }
}
