import 'package:api_contract/api_contract.dart';
import 'package:domain/domain.dart';
import 'package:drift/drift.dart' show OrderingTerm;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/data/db/app_database.dart';
import 'package:mobile/data/sync/outbox_writer.dart';

void main() {
  late AppDatabase db;
  late FixedClock clock;
  late OutboxWriter writer;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    clock = FixedClock(DateTime(2026, 10, 7, 18, 42));
    writer = OutboxWriter(db, clock);
  });
  tearDown(() => db.close());

  Future<List<OutboxRow>> rows() =>
      (db.select(db.outbox)..orderBy([(o) => OrderingTerm.asc(o.id)])).get();

  test(
    '05 §6.5: nhiều lần sửa cùng (entity, key) gộp thành một mutation, giữ dữ liệu mới nhất',
    () async {
      await writer.enqueue('account', 'me', SyncOp.upsert, {
        'displayName': 'A',
      });
      final first = (await rows()).single;
      clock.advance(const Duration(minutes: 1));
      await writer.enqueue('account', 'me', SyncOp.upsert, {
        'displayName': 'B',
      });
      final merged = (await rows()).single;
      expect(merged.id, first.id, reason: 'giữ vị trí trong hàng đợi');
      expect(merged.toMutation().data, {'displayName': 'B'});
      expect(merged.clientUpdatedAt, clock.now());
      expect(
        merged.mutationId,
        isNot(first.mutationId),
        reason: 'mutationId mới cho nội dung mới',
      );
    },
  );

  test('05 §6.5: ensure không bao giờ bị gộp', () async {
    await writer.enqueue('day', '2026-10-07', SyncOp.ensure, {'kind': 'rest'});
    await writer.enqueue('day', '2026-10-07', SyncOp.ensure, {'kind': 'rest'});
    await writer.enqueue('day', '2026-10-07', SyncOp.upsert, {
      'kind': 'workout',
    });
    expect(
      [for (final r in await rows()) r.op],
      ['ensure', 'ensure', 'upsert'],
    );
  });

  test(
    'khác key hoặc khác entity → mutation riêng; delete thay upsert đang chờ',
    () async {
      await writer.enqueue('weight', '2026-10-05', SyncOp.upsert, {
        'weightKgX10': 725,
      });
      await writer.enqueue('weight', '2026-10-12', SyncOp.upsert, {
        'weightKgX10': 720,
      });
      await writer.enqueue('account', 'me', SyncOp.upsert, {
        'displayName': 'A',
      });
      await writer.enqueue('weight', '2026-10-05', SyncOp.delete, null);
      final all = await rows();
      expect(all, hasLength(3));
      final deleted = all.first.toMutation();
      expect(
        (deleted.key, deleted.op, deleted.data),
        ('2026-10-05', SyncOp.delete, null),
      );
    },
  );

  test('toMutation đúng hợp đồng 05 §6.6.2', () async {
    await writer.enqueue('account', 'me', SyncOp.upsert, {
      'displayName': 'Minh',
    });
    final m = (await rows()).single.toMutation();
    expect(m.entity, 'account');
    expect(m.key, 'me');
    expect(m.clientUpdatedAt, clock.now());
    expect(RegExp(r'^[0-9a-f-]{36}$').hasMatch(m.mutationId), isTrue);
  });
}
