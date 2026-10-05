import 'package:api_contract/api_contract.dart';
import 'package:domain/domain.dart';
import 'package:postgres/postgres.dart';

import 'sync_entity_handler.dart';

/// Entity `weight` (key = thứ 2 của tuần) = bảng `weights` (06 VS03-T05).
final class WeightHandler implements SyncEntityHandler {
  const WeightHandler();

  static const _codec = WeightCodec();

  /// Múi giờ sớm nhất (UTC+14): ngày trên iPhone không thể muộn hơn
  /// `clientUpdatedAt` + 14 giờ.
  static const _maxUtcOffset = Duration(hours: 14);

  @override
  String get entity => SyncEntities.weight;

  @override
  Set<SyncOp> get ops => const {SyncOp.upsert, SyncOp.delete};

  @override
  ApiError? validate(SyncMutation m, SyncContext ctx) {
    final week = LocalDate.tryParse(m.key);
    if (week == null || !WeightRules.isWeekKey(week)) {
      return const ApiError(ErrorCode.validationFailed, field: 'key');
    }
    // F07-R2: không ghi cho tuần tương lai, theo ngày trên iPhone lúc ghi.
    final latestToday = LocalDate.fromDateTime(
      m.clientUpdatedAt.toUtc().add(_maxUtcOffset),
    );
    if (WeightRules.isFutureWeek(week, latestToday)) {
      return const ApiError(ErrorCode.validationFailed, field: 'key');
    }
    if (m.op == SyncOp.delete) return null;
    final data = m.data;
    if (data == null) {
      return const ApiError(ErrorCode.validationFailed, field: 'data');
    }
    try {
      if (WeightRules.isValidKgX10(_codec.decode(data).weightKgX10)) {
        return null;
      }
    } on ContractFormatException {
      // Báo theo tên trường bên dưới.
    }
    return const ApiError(ErrorCode.validationFailed, field: 'weightKgX10');
  }

  @override
  Future<RowState?> lock(Session s, String userId, String key) async {
    final rows = await s.execute(
      Sql.named(
        'SELECT client_updated_at, deleted FROM weights WHERE user_id = @user AND week_start = @week::date FOR UPDATE',
      ),
      parameters: {'user': userId, 'week': key},
    );
    if (rows.isEmpty) return null;
    return RowState(
      clientUpdatedAt: rows.first[0]! as DateTime,
      deleted: rows.first[1]! as bool,
    );
  }

  @override
  Future<void> apply(
    Session s,
    String userId,
    SyncMutation m,
    int serverVersion,
  ) async {
    final parameters = {
      'user': userId,
      'week': m.key,
      'version': serverVersion,
      'clientUpdatedAt': m.clientUpdatedAt,
    };
    if (m.op == SyncOp.delete) {
      await s.execute(
        Sql.named('''
          UPDATE weights
          SET deleted = true, weight_kg_x10 = NULL, server_version = @version,
              client_updated_at = @clientUpdatedAt, updated_at = now()
          WHERE user_id = @user AND week_start = @week::date'''),
        parameters: parameters,
      );
      return;
    }
    await s.execute(
      Sql.named('''
        INSERT INTO weights (user_id, week_start, weight_kg_x10, server_version, client_updated_at)
        VALUES (@user, @week::date, @kg, @version, @clientUpdatedAt)
        ON CONFLICT (user_id, week_start) DO UPDATE SET
          weight_kg_x10 = EXCLUDED.weight_kg_x10,
          server_version = EXCLUDED.server_version,
          client_updated_at = EXCLUDED.client_updated_at,
          updated_at = now(),
          deleted = false'''),
      parameters: {...parameters, 'kg': _codec.decode(m.data!).weightKgX10},
    );
  }

  @override
  Future<SyncChange?> read(Session s, String userId, String key) async {
    final rows = await s.execute(
      Sql.named('SELECT * FROM ($pullSql) c WHERE c.key = @key'),
      parameters: {'user': userId, 'cursor': 0, 'key': key},
    );
    return rows.isEmpty ? null : changeFromRow(rows.first);
  }

  @override
  String get pullSql => '''
    SELECT 'weight'::text AS entity, to_char(week_start, 'YYYY-MM-DD') AS key,
           deleted, server_version,
           CASE WHEN deleted THEN NULL
                ELSE jsonb_build_object('weightKgX10', weight_kg_x10) END AS data
    FROM weights
    WHERE user_id = @user AND server_version > @cursor''';
}
