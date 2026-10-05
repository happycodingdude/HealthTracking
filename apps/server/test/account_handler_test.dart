import 'package:api_contract/api_contract.dart';
import 'package:server/src/sync/account_handler.dart';
import 'package:server/src/sync/sync_entity_handler.dart';
import 'package:test/test.dart';

void main() {
  const handler = AccountHandler();
  final ctx = SyncContext(userId: 'u', serverNow: DateTime.utc(2026, 10, 7));

  SyncMutation m({String key = 'me', Map<String, Object?>? data}) =>
      SyncMutation(
        mutationId: 'x',
        entity: 'account',
        key: key,
        op: SyncOp.upsert,
        clientUpdatedAt: DateTime.utc(2026, 10, 7),
        data: data,
      );

  test('chỉ cho upsert, key me', () {
    expect(handler.ops, {SyncOp.upsert});
    expect(
      handler
          .validate(m(key: 'other', data: {'displayName': 'An'}), ctx)
          ?.field,
      'key',
    );
  });

  test('UA-21: server kiểm tra lại tên 1–30 ký tự bằng packages/domain', () {
    expect(handler.validate(m(data: {'displayName': 'Minh'}), ctx), isNull);
    expect(
      handler.validate(m(data: {'displayName': '   '}), ctx)?.field,
      'displayName',
    );
    expect(
      handler.validate(m(data: {'displayName': 'a' * 31}), ctx)?.field,
      'displayName',
    );
    expect(
      handler.validate(m(data: {'displayName': 3}), ctx)?.field,
      'displayName',
    );
    expect(handler.validate(m(), ctx)?.field, 'data');
  });
}
