import 'package:api_contract/api_contract.dart';
import 'package:domain/domain.dart';
import 'package:postgres/postgres.dart';

import '../ai/budget_ledger.dart';
import '../db/transaction.dart';
import '../logging/logger.dart';
import 'sync_entity_handler.dart';

/// Đồng bộ (05 §6.6, TD-05): push các mutation, pull theo cursor.
final class SyncService {
  SyncService({
    required Pool<void> pool,
    required Clock clock,
    required List<SyncEntityHandler> handlers,
    required Logger logger,
    int budgetCapVnd = AiBudgetRules.capVnd,
  }) : _pool = pool,
       _budgetCapVnd = budgetCapVnd,
       _clock = clock,
       _log = logger,
       _handlers = {for (final h in handlers) h.entity: h};

  final Pool<void> _pool;
  final Clock _clock;
  final Logger _log;
  final Map<String, SyncEntityHandler> _handlers;
  final int _budgetCapVnd;

  /// Khóa advisory theo user cho mọi lần ghi bảng đồng bộ (ED-03).
  static const lockNamespace = 7426002;

  /// Khóa của dòng dùng chung (thư viện, hình món ăn — 05 Bản 2 §6.6.1).
  /// Dòng dùng chung lấy `server_version` từ cùng sequence nhưng không nằm
  /// trong khóa của user nào: nếu một pull chụp snapshot khi transaction ghi
  /// dòng dùng chung đang dở, dòng đó có thể có version nhỏ hơn cursor trả
  /// về và bị bỏ sót. Nơi ghi giữ khóa độc quyền đến hết transaction
  /// ([lockSharedRowsForWrite]); pull giữ khóa chia sẻ trước khi chụp
  /// snapshot, nên không bao giờ thấy nửa chừng.
  static const sharedRowsLock = 7426004;

  /// `clientUpdatedAt` lớn hơn giờ server quá mức này bị từ chối (05 §6.6.2).
  static const maxClockSkew = Duration(minutes: 10);

  static final _uuid = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  );

  Iterable<SyncEntityHandler> get handlers => _handlers.values;

  /// Xử lý tuần tự trong một transaction giữ khóa của user, mỗi mutation một
  /// savepoint. Thứ tự `server_version` trùng thứ tự commit trong phạm vi một
  /// user, nên pull theo cursor không bỏ sót (ED-03).
  /// [appVersion] = header `X-App-Version` (null = app Bản 1).
  Future<PushResponse> push(
    String userId,
    PushRequest request, {
    AppVersion? appVersion,
  }) {
    return inTransaction(_pool, (conn) async {
      await lockUser(conn, userId);
      final ctx = SyncContext(
        userId: userId,
        serverNow: _clock.now().toUtc(),
        appVersion: appVersion,
      );
      final results = <PushResult>[];
      for (final m in request.mutations) {
        results.add(await _pushOne(conn, ctx, m));
      }
      return PushResponse(results);
    });
  }

  /// Các thay đổi của [userId] có `server_version > cursor`, tăng dần, tối đa
  /// [limit] (05 §6.6.3). Đọc trong một snapshot để `remaining` khớp `changes`.
  Future<PullResponse> pull(
    String userId, {
    required int cursor,
    int limit = PullResponse.maxLimit,
  }) {
    final union = [
      for (final h in _handlers.values) '(${h.pullSql})',
    ].join('\nUNION ALL\n');
    return _pool.withConnection((conn) async {
      // Khóa chia sẻ mức phiên, lấy TRƯỚC khi transaction chụp snapshot.
      await conn.execute(
        Sql.named('SELECT pg_advisory_lock_shared(@k)'),
        parameters: {'k': sharedRowsLock},
      );
      try {
        return await _pullIn(conn, userId, union, cursor, limit);
      } finally {
        await conn.execute(
          Sql.named('SELECT pg_advisory_unlock_shared(@k)'),
          parameters: {'k': sharedRowsLock},
        );
      }
    });
  }

  Future<PullResponse> _pullIn(
    Connection connection,
    String userId,
    String union,
    int cursor,
    int limit,
  ) {
    return inTransactionOn(
      connection,
      begin: 'BEGIN ISOLATION LEVEL REPEATABLE READ READ ONLY',
      (conn) async {
        final rows = await conn.execute(
          Sql.named(
            'SELECT entity, key, deleted, server_version, data FROM ($union) c ORDER BY server_version LIMIT @limit',
          ),
          parameters: {'user': userId, 'cursor': cursor, 'limit': limit},
        );
        final changes = [for (final r in rows) changeFromRow(r)];
        final next = changes.isEmpty ? cursor : changes.last.serverVersion;
        final remaining =
            (await conn.execute(
                  Sql.named('SELECT count(*) FROM ($union) c'),
                  parameters: {'user': userId, 'cursor': next},
                )).first[0]!
                as int;
        final now = _clock.now().toUtc();
        // ED-04: ngân sách AI của tháng chỉ đi qua meta.
        final budget = await BudgetLedger.meta(conn, now, _budgetCapVnd);
        return PullResponse(
          changes: changes,
          nextCursor: next,
          hasMore: remaining > 0,
          remaining: remaining,
          meta: SyncMeta(serverTime: now, aiBudget: budget.toJson()),
        );
      },
    );
  }

  /// Gọi đầu tiên trong transaction ghi dòng dùng chung, trước mọi `nextval`.
  static Future<void> lockSharedRowsForWrite(Session s) => s.execute(
    Sql.named('SELECT pg_advisory_xact_lock(@k)'),
    parameters: {'k': sharedRowsLock},
  );

  /// Khóa advisory của [userId] đến hết transaction (ED-03).
  static Future<void> lockUser(Session s, String userId) => s.execute(
    Sql.named('SELECT pg_advisory_xact_lock(@ns::int, hashtext(@user))'),
    parameters: {'ns': lockNamespace, 'user': userId},
  );

  Future<PushResult> _pushOne(
    Connection conn,
    SyncContext ctx,
    SyncMutation m,
  ) async {
    if (!_uuid.hasMatch(m.mutationId)) return _rejected(m, 'mutationId');

    // 1. Idempotency (TAC-03): mutation đã xử lý → trả lại kết quả cũ.
    final stored = await conn.execute(
      Sql.named(
        'SELECT user_id, result FROM processed_mutations WHERE mutation_id = @id::uuid',
      ),
      parameters: {'id': m.mutationId},
    );
    if (stored.isNotEmpty) {
      if (stored.first[0] != ctx.userId) return _rejected(m, 'mutationId');
      return _withCurrent(conn, ctx, m, PushResult.fromJson(stored.first[1]));
    }

    final result = await _apply(conn, ctx, m);
    await conn.execute(
      Sql.named(
        'INSERT INTO processed_mutations (mutation_id, user_id, result) VALUES (@id::uuid, @user, @result:jsonb)',
      ),
      parameters: {
        'id': m.mutationId,
        'user': ctx.userId,
        'result': result.toJson(),
      },
    );
    return _withCurrent(conn, ctx, m, result);
  }

  Future<PushResult> _apply(
    Connection conn,
    SyncContext ctx,
    SyncMutation m,
  ) async {
    // 2. Validate cấu trúc và business rules bằng packages/domain.
    final handler = _handlers[m.entity];
    if (handler == null) return _rejected(m, 'entity');
    if (!handler.ops.contains(m.op)) return _rejected(m, 'op');
    if (m.clientUpdatedAt.isAfter(ctx.serverNow.add(maxClockSkew))) {
      return _rejected(m, 'clientUpdatedAt');
    }
    final error = handler.validate(m, ctx);
    if (error != null) {
      return PushResult(
        mutationId: m.mutationId,
        status: PushStatus.rejected,
        code: error.code,
        field: error.field,
      );
    }

    try {
      return await inSavepoint(conn, 'm', () async {
        final row = await handler.lock(conn, ctx.userId, m.key);
        // 3. Xung đột: bản trên server mới hơn thì giữ bản server (TA-11).
        //    `ensure` chỉ tạo khi chưa có (05 §6.6.2).
        final stale = switch (m.op) {
          SyncOp.ensure => row != null && !row.deleted,
          SyncOp.upsert || SyncOp.delete =>
            row != null && row.clientUpdatedAt.isAfter(m.clientUpdatedAt),
        };
        if (stale) {
          return PushResult(
            mutationId: m.mutationId,
            status: PushStatus.ignoredStale,
          );
        }
        if (m.op == SyncOp.delete && (row == null || row.deleted)) {
          return PushResult(
            mutationId: m.mutationId,
            status: PushStatus.applied,
          );
        }
        // 4. Ghi, gán server_version mới.
        final version =
            (await conn.execute("SELECT nextval('sync_version_seq')")).first[0]!
                as int;
        await handler.apply(conn, ctx, m, version);
        return PushResult(mutationId: m.mutationId, status: PushStatus.applied);
      });
    } on SyncRejection catch (e) {
      return _rejected(m, e.field, e.code);
    } on ServerException catch (e) {
      // CHECK của database chặn dữ liệu sai mà validate chưa bắt được.
      _log.warn('sync_mutation_rejected', {
        'entity': m.entity,
        'sqlState': e.code,
      });
      return _rejected(m, null);
    }
  }

  /// Kết quả không `applied` kèm bản ghi hiện tại trên server (TA-12).
  Future<PushResult> _withCurrent(
    Connection conn,
    SyncContext ctx,
    SyncMutation m,
    PushResult r,
  ) async {
    if (r.status == PushStatus.applied) return r;
    final handler = _handlers[m.entity];
    if (handler == null || r.field == 'mutationId') return r;
    return r.withCurrent(await handler.read(conn, ctx.userId, m.key));
  }

  static PushResult _rejected(
    SyncMutation m,
    String? field, [
    ErrorCode code = ErrorCode.validationFailed,
  ]) => PushResult(
    mutationId: m.mutationId,
    status: PushStatus.rejected,
    code: code,
    field: field,
  );
}
