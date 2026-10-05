import 'package:api_contract/api_contract.dart';
import 'package:postgres/postgres.dart';
import 'package:test/test.dart';

import 'support/test_app.dart';

void main() {
  late TestApp app;
  late String token;
  final t0 = DateTime.utc(2026, 10, 7, 9, 59);

  setUp(() async {
    app = await TestApp.create(withTestItems: true);
    token = (await app.register()).accessToken;
  });
  tearDown(() => app.dispose());

  SyncMutation rename(String name, DateTime at, {String? id}) => mutation(
    'account',
    'me',
    SyncOp.upsert,
    at: at,
    data: {'displayName': name},
    id: id,
  );

  Future<(String, int)> serverName() async {
    final row = (await app.tdb.pool.execute(
      "SELECT display_name, server_version FROM users WHERE phone = '0912345678'",
    )).single;
    return (row[0]! as String, row[1]! as int);
  }

  test('đổi tên: applied, tên được chuẩn hóa, server_version tăng', () async {
    final (_, before) = await serverName();
    final res = await app.push(token, [rename(' Minh Anh ', t0)]);
    expect(res.results.single.status, PushStatus.applied);
    final (name, after) = await serverName();
    expect(name, 'Minh Anh');
    expect(after, greaterThan(before));
  });

  test(
    'TAC-03: gửi lại cùng mutation 2 lần → server chỉ ghi 1 lần, trả lại kết quả cũ',
    () async {
      final m = rename('Lan', t0);
      final first = await app.push(token, [m]);
      final (_, v1) = await serverName();
      final second = await app.push(token, [m]);
      final (name, v2) = await serverName();
      expect(second.results.single.status, first.results.single.status);
      expect(name, 'Lan');
      expect(v2, v1, reason: 'không ghi lần 2');
      final count = await app.tdb.pool.execute(
        Sql.named(
          'SELECT count(*) FROM processed_mutations WHERE mutation_id = @id::uuid',
        ),
        parameters: {'id': m.mutationId},
      );
      expect(count.single[0], 1);
    },
  );

  test(
    'TA-11: bản cũ hơn bản trên server → ignored_stale kèm bản server',
    () async {
      await app.push(token, [
        rename('Mới', t0.add(const Duration(minutes: 5))),
      ]);
      final res = await app.push(token, [rename('Cũ', t0)]);
      final r = res.results.single;
      expect(r.status, PushStatus.ignoredStale);
      expect(r.current!.data, {'displayName': 'Mới'});
      expect((await serverName()).$1, 'Mới');
    },
  );

  test(
    'TA-11: lần sửa đầu tiên luôn được nhận, kể cả khi đồng hồ iPhone chậm hơn server',
    () async {
      // Đăng ký lúc 10:00 giờ server; đồng hồ máy chậm 30 phút.
      final res = await app.push(token, [
        rename(
          'Đổi ngay sau đăng ký',
          app.clock.now().toUtc().subtract(const Duration(minutes: 30)),
        ),
      ]);
      expect(res.results.single.status, PushStatus.applied);
      expect((await serverName()).$1, 'Đổi ngay sau đăng ký');
    },
  );

  test(
    '05 §6.6.2: clientUpdatedAt lớn hơn giờ server quá 10 phút → rejected',
    () async {
      final now = app.clock.now().toUtc();
      final ok = await app.push(token, [
        rename('Đúng hạn', now.add(const Duration(minutes: 10))),
      ]);
      expect(ok.results.single.status, PushStatus.applied);
      final res = await app.push(token, [
        rename('Tương lai', now.add(const Duration(minutes: 10, seconds: 1))),
      ]);
      final r = res.results.single;
      expect(
        (r.status, r.code, r.field),
        (PushStatus.rejected, ErrorCode.validationFailed, 'clientUpdatedAt'),
      );
      expect(r.current!.data, {
        'displayName': 'Đúng hạn',
      }, reason: 'TA-12: kèm bản server');
    },
  );

  test(
    'server kiểm tra lại bằng packages/domain: tên sai → rejected kèm bản server',
    () async {
      final res = await app.push(token, [rename('a' * 31, t0)]);
      final r = res.results.single;
      expect((r.status, r.field), (PushStatus.rejected, 'displayName'));
      expect(r.current!.data, {'displayName': 'Minh'});
    },
  );

  test(
    'entity lạ, op không cho phép, mutationId không phải UUID → rejected',
    () async {
      final res = await app.push(token, [
        mutation('ghost', 'x', SyncOp.upsert, at: t0, data: {}),
        mutation('account', 'me', SyncOp.delete, at: t0),
        rename('X', t0, id: 'khong-phai-uuid'),
      ]);
      expect(
        [for (final r in res.results) (r.status, r.field)],
        [
          (PushStatus.rejected, 'entity'),
          (PushStatus.rejected, 'op'),
          (PushStatus.rejected, 'mutationId'),
        ],
      );
    },
  );

  test(
    'savepoint: một mutation bị CHECK của database chặn không ảnh hưởng mutation khác',
    () async {
      final res = await app.push(token, [
        mutation('test_item', 'a', SyncOp.upsert, at: t0, data: {'value': '1'}),
        mutation(
          'test_item',
          'b',
          SyncOp.upsert,
          at: t0,
          data: {'value': 'boom'},
        ),
        mutation('test_item', 'c', SyncOp.upsert, at: t0, data: {'value': '3'}),
      ]);
      expect(
        [for (final r in res.results) r.status],
        [PushStatus.applied, PushStatus.rejected, PushStatus.applied],
      );
      final keys = await app.tdb.pool.execute(
        'SELECT key FROM test_items ORDER BY key',
      );
      expect([for (final r in keys) r[0]], ['a', 'c']);
    },
  );

  test(
    'ensure: chỉ tạo khi chưa có; đã có → ignored_stale, không ghi đè',
    () async {
      final created = await app.push(token, [
        mutation('test_item', 'd', SyncOp.ensure, at: t0, data: {'value': 'A'}),
      ]);
      expect(created.results.single.status, PushStatus.applied);
      final again = await app.push(token, [
        mutation(
          'test_item',
          'd',
          SyncOp.ensure,
          at: t0.add(const Duration(minutes: 1)),
          data: {'value': 'B'},
        ),
      ]);
      expect(again.results.single.status, PushStatus.ignoredStale);
      expect(again.results.single.current!.data, {'value': 'A'});
    },
  );

  test(
    'delete: tombstone; xóa bản ghi chưa có → applied (không ghi)',
    () async {
      await app.push(token, [
        mutation('test_item', 'e', SyncOp.upsert, at: t0, data: {'value': 'x'}),
      ]);
      final res = await app.push(token, [
        mutation(
          'test_item',
          'e',
          SyncOp.delete,
          at: t0.add(const Duration(seconds: 1)),
        ),
        mutation('test_item', 'khong-co', SyncOp.delete, at: t0),
      ]);
      expect(
        [for (final r in res.results) r.status],
        [PushStatus.applied, PushStatus.applied],
      );
      final row = (await app.tdb.pool.execute(
        "SELECT deleted, value FROM test_items WHERE key = 'e'",
      )).single;
      expect(row[0], isTrue);
      expect(row[1], isNull);
    },
  );

  test('kết quả theo đúng thứ tự gửi', () async {
    final ms = [
      for (var i = 0; i < 5; i++)
        mutation(
          'test_item',
          'k$i',
          SyncOp.upsert,
          at: t0,
          data: {'value': '$i'},
        ),
    ];
    final res = await app.push(token, ms);
    expect(
      [for (final r in res.results) r.mutationId],
      [for (final m in ms) m.mutationId],
    );
  });

  group('TAC-07: truy cập chéo tài khoản', () {
    test('token của B chỉ đổi tên của B', () async {
      final b = (await app.register(
        phone: '0922222222',
        name: 'Bình',
      )).accessToken;
      await app.push(b, [rename('Bình mới', t0)]);
      expect((await serverName()).$1, 'Minh', reason: 'tài khoản A không đổi');
    });

    test(
      'B dùng lại mutationId của A → rejected, không lộ kết quả của A',
      () async {
        final m = rename('Của A', t0);
        await app.push(token, [m]);
        final b = (await app.register(
          phone: '0922222222',
          name: 'Bình',
        )).accessToken;
        final res = await app.push(b, [rename('Của B', t0, id: m.mutationId)]);
        final r = res.results.single;
        expect((r.status, r.field), (PushStatus.rejected, 'mutationId'));
        expect(r.current, isNull);
        expect((await serverName()).$1, 'Của A');
      },
    );

    test('B ghi test_item cùng key với A → hai bản ghi riêng', () async {
      await app.push(token, [
        mutation('test_item', 'k', SyncOp.upsert, at: t0, data: {'value': 'A'}),
      ]);
      final b = (await app.register(
        phone: '0922222222',
        name: 'Bình',
      )).accessToken;
      await app.push(b, [
        mutation('test_item', 'k', SyncOp.upsert, at: t0, data: {'value': 'B'}),
      ]);
      final rows = await app.tdb.pool.execute(
        "SELECT value FROM test_items WHERE key = 'k' ORDER BY value",
      );
      expect([for (final r in rows) r[0]], ['A', 'B']);
    });
  });

  test('cần đăng nhập; thân sai → 422', () async {
    final noAuth = await app.post('/v1/sync/push', {'mutations': <Object>[]});
    expect(noAuth.status, 401);
    final bad = await app.post('/v1/sync/push', {
      'mutations': 'x',
    }, token: token);
    expect((bad.status, bad.errorField), (422, 'mutations'));
  });
}
