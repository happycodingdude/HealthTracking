import 'package:api_contract/api_contract.dart';
import 'package:postgres/postgres.dart';

import '../ai/menu_service.dart';
import 'sync_entity_handler.dart';

/// Entity chỉ pull do server ghi (05 §6.6.1): app gửi lên → `rejected` (op).
abstract base class _PullOnlyHandler implements SyncEntityHandler {
  const _PullOnlyHandler();

  @override
  Set<SyncOp> get ops => const {};

  @override
  ApiError? validate(SyncMutation mutation, SyncContext ctx) =>
      const ApiError(ErrorCode.validationFailed, field: 'op');

  @override
  Future<RowState?> lock(Session s, String userId, String key) =>
      throw UnsupportedError('$entity chỉ pull');

  @override
  Future<void> apply(
    Session s,
    String userId,
    SyncMutation mutation,
    int serverVersion,
  ) => throw UnsupportedError('$entity chỉ pull');

  @override
  Future<SyncChange?> read(Session s, String userId, String key) async {
    final rows = await s.execute(
      Sql.named('SELECT * FROM ($pullSql) c WHERE key = @key'),
      parameters: {'user': userId, 'cursor': 0, 'key': key},
    );
    return rows.isEmpty ? null : changeFromRow(rows.first);
  }
}

/// Entity `menu`, key = ngày (06 §6.5.1, VS12-T03).
final class MenuHandler extends _PullOnlyHandler {
  const MenuHandler();

  @override
  String get entity => SyncEntities.menu;

  @override
  String get pullSql => MenuQueries.pullSql;
}

/// Entity `ai_daily_usage`, key `YYYY-MM-DD:menu`.
final class AiDailyUsageHandler extends _PullOnlyHandler {
  const AiDailyUsageHandler();

  @override
  String get entity => SyncEntities.aiDailyUsage;

  @override
  String get pullSql => MenuQueries.usagePullSql;
}
