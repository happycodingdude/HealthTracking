import 'dart:convert';

import 'package:api_contract/api_contract.dart';
import 'package:domain/domain.dart';
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../db/app_database.dart';

/// Ghi thay đổi vào outbox, **bên trong transaction của use case** (06 §6.4.2).
///
/// Nhiều lần sửa cùng `(entity, key)` khi chưa gửi được gộp thành một mutation,
/// chỉ giữ dữ liệu mới nhất; riêng `ensure` luôn được giữ riêng (05 §6.5).
/// Mutation bị gộp nhận `mutationId` mới, để kết quả của lần gửi đang dở (nếu
/// có) không xóa nhầm thay đổi mới hơn.
final class OutboxWriter {
  OutboxWriter(this._db, this._clock, {Uuid uuid = const Uuid()})
    : _uuid = uuid;

  final AppDatabase _db;
  final Clock _clock;
  final Uuid _uuid;

  Future<void> enqueue(
    String entity,
    String key,
    SyncOp op,
    Map<String, Object?>? data,
  ) async {
    final now = _clock.now();
    final payload = data == null ? null : jsonEncode(data);
    if (op != SyncOp.ensure) {
      final existing =
          await (_db.select(_db.outbox)
                ..where(
                  (o) =>
                      o.entity.equals(entity) &
                      o.entityKey.equals(key) &
                      o.op.equals(SyncOp.ensure.wire).not(),
                )
                ..orderBy([(o) => OrderingTerm.desc(o.id)])
                ..limit(1))
              .getSingleOrNull();
      if (existing != null) {
        await (_db.update(
          _db.outbox,
        )..where((o) => o.id.equals(existing.id))).write(
          OutboxCompanion(
            mutationId: Value(_uuid.v4()),
            op: Value(op.wire),
            payload: Value(payload),
            clientUpdatedAt: Value(now),
            attempts: const Value(0),
            lastError: const Value(null),
          ),
        );
        return;
      }
    }
    await _db
        .into(_db.outbox)
        .insert(
          OutboxCompanion.insert(
            mutationId: _uuid.v4(),
            entity: entity,
            entityKey: key,
            op: op.wire,
            payload: Value(payload),
            clientUpdatedAt: now,
          ),
        );
  }
}

extension OutboxRowMutation on OutboxRow {
  /// Đổi dòng outbox thành mutation để gửi (05 §6.6.2).
  SyncMutation toMutation() => SyncMutation(
    mutationId: mutationId,
    entity: entity,
    key: entityKey,
    op: SyncOp.fromWire(op),
    clientUpdatedAt: clientUpdatedAt,
    data: payload == null
        ? null
        : (jsonDecode(payload!) as Map).cast<String, Object?>(),
  );
}
