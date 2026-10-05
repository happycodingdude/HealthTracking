import 'package:api_contract/api_contract.dart';
import 'package:test/test.dart';

void main() {
  final t = DateTime.utc(2026, 10, 7, 11, 42, 10);

  test('SyncMutation khứ hồi JSON theo ví dụ 05 §6.6.2', () {
    final m = SyncMutation(
      mutationId: '8f1c0000-0000-4000-8000-000000000001',
      entity: 'account',
      key: 'me',
      op: SyncOp.upsert,
      clientUpdatedAt: t,
      data: {'displayName': 'Minh'},
    );
    final json = m.toJson();
    expect(json['op'], 'upsert');
    expect(json['clientUpdatedAt'], '2026-10-07T11:42:10.000Z');
    final back = SyncMutation.fromJson(json);
    expect(back.toJson(), json);
    final parsed = SyncMutation.fromJson({
      ...json,
      'clientUpdatedAt': '2026-10-07T18:42:10+07:00',
    });
    expect(parsed.clientUpdatedAt, t);
  });

  test('delete không có data; op lạ bị từ chối kèm tên trường', () {
    final d = SyncMutation(
      mutationId: 'x',
      entity: 'weight',
      key: '2026-10-05',
      op: SyncOp.delete,
      clientUpdatedAt: t,
    );
    expect(d.toJson().containsKey('data'), isFalse);
    expect(SyncMutation.fromJson(d.toJson()).data, isNull);
    expect(
      () => PushRequest.fromJson({
        'mutations': [
          {...d.toJson(), 'op': 'merge'},
        ],
      }),
      throwsA(
        isA<ContractFormatException>().having(
          (e) => e.field,
          'field',
          'mutations[0].op',
        ),
      ),
    );
  });

  test('PushRequest giới hạn 500 mutation', () {
    final m = SyncMutation(
      mutationId: 'x',
      entity: 'account',
      key: 'me',
      op: SyncOp.upsert,
      clientUpdatedAt: t,
      data: {},
    );
    expect(
      PushRequest.fromJson(PushRequest(List.filled(500, m)).toJson()).mutations,
      hasLength(500),
    );
    expect(
      () => PushRequest.fromJson(PushRequest(List.filled(501, m)).toJson()),
      throwsA(
        isA<ContractFormatException>().having(
          (e) => e.field,
          'field',
          'mutations',
        ),
      ),
    );
  });

  test(
    'PushResponse khứ hồi: applied, ignored_stale kèm current, rejected kèm mã',
    () {
      const change = SyncChange(
        entity: 'account',
        key: 'me',
        deleted: false,
        serverVersion: 1042,
        data: {'displayName': 'An'},
      );
      const res = PushResponse([
        PushResult(mutationId: 'a', status: PushStatus.applied),
        PushResult(
          mutationId: 'b',
          status: PushStatus.ignoredStale,
          current: change,
        ),
        PushResult(
          mutationId: 'c',
          status: PushStatus.rejected,
          code: ErrorCode.validationFailed,
          field: 'displayName',
        ),
      ]);
      final json = res.toJson();
      expect(
        (json['results']! as List)[1],
        containsPair('status', 'ignored_stale'),
      );
      final back = PushResponse.fromJson(json);
      expect(back.toJson(), json);
      expect(back.results[2].code, ErrorCode.validationFailed);
      expect(back.results[1].current!.serverVersion, 1042);
    },
  );

  test(
    'PullResponse khứ hồi theo ví dụ 05 §6.6.3, tombstone không có data',
    () {
      final p = PullResponse(
        changes: const [
          SyncChange(
            entity: 'account',
            key: 'me',
            deleted: false,
            serverVersion: 7,
            data: {'displayName': 'Minh'},
          ),
          SyncChange(
            entity: 'weight',
            key: '2026-10-05',
            deleted: true,
            serverVersion: 8,
          ),
        ],
        nextCursor: 8,
        hasMore: false,
        remaining: 0,
        meta: SyncMeta(serverTime: t),
      );
      final back = PullResponse.fromJson(p.toJson());
      expect(back.toJson(), p.toJson());
      expect(back.changes[1].deleted, isTrue);
      expect(back.changes[1].data, isNull);
      expect(back.meta.serverTime, t);
    },
  );

  test(
    'AccountCodec: encode/decode, thiếu displayName → lỗi có tên trường',
    () {
      const codec = AccountCodec();
      expect(codec.encode(const AccountData(displayName: 'Minh')), {
        'displayName': 'Minh',
      });
      expect(
        codec.decode({'displayName': 'Minh'}),
        const AccountData(displayName: 'Minh'),
      );
      expect(
        () => codec.decode({}),
        throwsA(
          isA<ContractFormatException>().having(
            (e) => e.field,
            'field',
            'data.displayName',
          ),
        ),
      );
      expect(SyncEntities.codecs[SyncEntities.account], isA<AccountCodec>());
    },
  );
}
