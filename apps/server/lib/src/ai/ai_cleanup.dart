import 'package:domain/domain.dart';
import 'package:postgres/postgres.dart';

import '../db/transaction.dart';
import '../sync/sync_service.dart';
import 'menu_service.dart';

/// Job 5 phút (06 VS12-T08, 05 §6.11): yêu cầu AI treo quá 10 phút (server
/// khởi động lại giữa chừng) → `expired`, tính trọn số đã đặt trước vì không
/// biết nhà cung cấp đã tính tiền hay chưa (05 §6.9.3); thực đơn đang
/// `generating` quá 10 phút → `failed`.
final class AiCleanup {
  AiCleanup(this._pool, this._clock);

  final Pool<void> _pool;
  final Clock _clock;

  Future<({int requests, int menus})> run() async {
    final cutoff = _clock.now().toUtc().subtract(MenuService.staleAfter);
    final stale = await _pool.execute(
      Sql.named('''
        SELECT id::text, user_id::text FROM ai_requests
        WHERE status = 'reserved' AND created_at < @cutoff'''),
      parameters: {'cutoff': cutoff},
    );
    var requests = 0;
    for (final row in stale) {
      // Cùng thứ tự khóa với MenuService: user → dòng tháng → dòng yêu cầu.
      final done = await inTransaction(_pool, (conn) async {
        await SyncService.lockUser(conn, row[1]! as String);
        final r = await conn.execute(
          Sql.named('''
            SELECT month, round(reserved_vnd * 100)::bigint FROM ai_requests
            WHERE id = @id::uuid AND status = 'reserved' '''),
          parameters: {'id': row[0]},
        );
        if (r.isEmpty) return false;
        final month = r.single[0]! as String;
        await conn.execute(
          Sql.named(
            'SELECT 1 FROM ai_budget_months WHERE month = @m FOR UPDATE',
          ),
          parameters: {'m': month},
        );
        await conn.execute(
          Sql.named('''
            UPDATE ai_budget_months
            SET used_vnd = used_vnd + @c::numeric / 100,
                reserved_vnd = greatest(reserved_vnd - @c::numeric / 100, 0)
            WHERE month = @m'''),
          parameters: {'m': month, 'c': r.single[1]},
        );
        await conn.execute(
          Sql.named('''
            UPDATE ai_requests SET status = 'expired', actual_vnd = reserved_vnd,
                   error_code = 'ai_provider_error', settled_at = @now
            WHERE id = @id::uuid'''),
          parameters: {'id': row[0], 'now': _clock.now().toUtc()},
        );
        return true;
      });
      if (done) requests++;
    }

    final users = await _pool.execute(
      Sql.named(
        '''
        SELECT DISTINCT user_id::text FROM menus
        WHERE last_attempt_status = 'generating' AND attempt_started_at < @cutoff''',
      ),
      parameters: {'cutoff': cutoff},
    );
    var menus = 0;
    for (final row in users) {
      menus += await inTransaction(_pool, (conn) async {
        await SyncService.lockUser(conn, row[0]! as String);
        final updated = await conn.execute(
          Sql.named('''
            UPDATE menus SET last_attempt_status = 'failed',
                   last_error_code = 'ai_provider_error', attempt_started_at = NULL,
                   server_version = nextval('sync_version_seq'), updated_at = now()
            WHERE user_id = @u AND last_attempt_status = 'generating'
              AND attempt_started_at < @cutoff'''),
          parameters: {'u': row[0], 'cutoff': cutoff},
        );
        return updated.affectedRows;
      });
    }
    return (requests: requests, menus: menus);
  }
}
