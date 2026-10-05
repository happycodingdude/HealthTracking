import 'dart:async';

import 'package:api_contract/api_contract.dart';
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

  SyncMutation item(String key, String value, {DateTime? at}) => mutation(
    'test_item',
    key,
    SyncOp.upsert,
    at: at ?? t0,
    data: {'value': value},
  );

  test(
    'pull từ 0: có account với tên hiển thị; cursor kế tiếp; meta.serverTime',
    () async {
      final p = await app.pull(token);
      expect(p.changes, hasLength(1));
      final c = p.changes.single;
      expect((c.entity, c.key, c.deleted), ('account', 'me', false));
      expect(c.data, {'displayName': 'Minh'});
      expect(p.nextCursor, c.serverVersion);
      expect((p.hasMore, p.remaining), (false, 0));
      expect(p.meta.serverTime, app.clock.now().toUtc());

      final again = await app.pull(token, cursor: p.nextCursor);
      expect(again.changes, isEmpty);
      expect(
        again.nextCursor,
        p.nextCursor,
        reason: 'không có gì mới thì giữ cursor',
      );
    },
  );

  test('chỉ trả thay đổi sau cursor, sắp xếp theo server_version', () async {
    final first = await app.pull(token);
    await app.push(token, [item('a', '1'), item('b', '2')]);
    final p = await app.pull(token, cursor: first.nextCursor);
    expect([for (final c in p.changes) c.key], ['a', 'b']);
    final versions = [for (final c in p.changes) c.serverVersion];
    expect(versions, orderedEquals([...versions]..sort()));
  });

  test(
    'pull 1.200 thay đổi qua nhiều trang: không thiếu, không trùng, remaining giảm dần',
    () async {
      for (var batch = 0; batch < 3; batch++) {
        await app.push(token, [
          for (var i = 0; i < 400; i++) item('k${batch * 400 + i}', 'v'),
        ]);
      }
      final seen = <String>[];
      final remaining = <int>[];
      var cursor = 0;
      var pages = 0;
      while (true) {
        final p = await app.pull(token, cursor: cursor);
        pages++;
        seen.addAll([for (final c in p.changes) '${c.entity}/${c.key}']);
        remaining.add(p.remaining);
        cursor = p.nextCursor;
        if (!p.hasMore) break;
      }
      expect(pages, 3);
      expect(seen, hasLength(1201), reason: '1.200 test_item + account');
      expect(seen.toSet(), hasLength(1201), reason: 'không trùng');
      expect(remaining, [701, 201, 0]);
    },
  );

  test('tombstone đến được máy khác', () async {
    await app.push(token, [item('x', 'giá trị')]);
    final deviceB = await app.pull(token);
    expect(deviceB.changes.where((c) => c.key == 'x').single.deleted, isFalse);
    await app.push(token, [
      mutation(
        'test_item',
        'x',
        SyncOp.delete,
        at: t0.add(const Duration(minutes: 1)),
      ),
    ]);
    final later = await app.pull(token, cursor: deviceB.nextCursor);
    final c = later.changes.single;
    expect((c.key, c.deleted, c.data), ('x', true, null));
  });

  test('ED-03: ghi đồng thời không làm cursor bỏ sót thay đổi', () async {
    const writers = 8;
    const perWriter = 25;
    final expected = {
      for (var w = 0; w < writers; w++)
        for (var i = 0; i < perWriter; i++) 'w$w-$i',
    };
    final seen = <String>{};
    var cursor = (await app.pull(token)).nextCursor;
    var done = false;

    final pushes = Future.wait([
      for (var w = 0; w < writers; w++)
        () async {
          for (var i = 0; i < perWriter; i += 5) {
            await app.push(token, [
              for (var j = i; j < i + 5; j++) item('w$w-$j', 'slow'),
            ]);
          }
        }(),
    ]).whenComplete(() => done = true);

    // Một máy khác pull liên tục trong lúc các máy kia đang ghi.
    Future<bool> pullPage() async {
      final p = await app.pull(token, cursor: cursor, limit: 7);
      seen.addAll([for (final c in p.changes) c.key]);
      cursor = p.nextCursor;
      return p.hasMore;
    }

    while (!done) {
      await pullPage();
    }
    await pushes;
    // Ghi xong: pull nốt. Nếu cursor đã vượt qua một version chưa commit thì
    // thay đổi đó mất hẳn và test đỏ.
    while (await pullPage()) {}
    expect(seen, expected, reason: 'pull theo cursor thấy đủ mọi thay đổi');
  });

  test('TAC-07: token của B không đọc được dữ liệu của A', () async {
    await app.push(token, [item('bi-mat', 'của A')]);
    final b = (await app.register(
      phone: '0922222222',
      name: 'Bình',
    )).accessToken;
    final p = await app.pull(b);
    expect(p.changes, hasLength(1));
    expect(p.changes.single.data, {'displayName': 'Bình'});
  });

  test('tham số sai → 422 theo trường; thiếu token → 401', () async {
    for (final (query, field) in [
      ('cursor=-1', 'cursor'),
      ('cursor=x', 'cursor'),
      ('limit=0', 'limit'),
      ('limit=501', 'limit'),
    ]) {
      final res = await app.get('/v1/sync/pull?$query', token: token);
      expect((res.status, res.errorField), (422, field), reason: query);
    }
    expect((await app.get('/v1/sync/pull')).status, 401);
  });
}
