import 'package:api_contract/api_contract.dart';
import 'package:postgres/postgres.dart';
import 'package:server/testing.dart';
import 'package:test/test.dart';

import '../support/test_app.dart';

/// 06 Bản 3 VS40-T03, T08: `PUT` / `DELETE /v1/me/live-activity-token`
/// (TD3-11): chỉ giữ token mới nhất, kiểm tra dữ liệu, TAC3-13 truy cập chéo.
void main() {
  late TestApp app;

  setUp(() async => app = await TestApp.create());
  tearDown(() => app.dispose());

  Future<TestResponse> put(String token, Map<String, Object?> body) =>
      app.send('PUT', '/v1/me/live-activity-token', body: body, token: token);

  Map<String, Object?> body({String? start, String? update, String? date}) => {
    'pushToStartToken': start ?? randomApnsToken(),
    'activityPushToken': ?update,
    'activityDate': ?date,
    'environment': 'sandbox',
    'appVersion': '3.0.0',
  };

  Future<List<List<Object?>>> rows() async => [
    for (final r in await app.tdb.pool.execute(
      Sql.named('''
        SELECT u.phone, t.push_to_start_token, t.activity_push_token,
               to_char(t.activity_date, 'YYYY-MM-DD'), t.environment
        FROM live_activity_tokens t JOIN users u ON u.id = t.user_id
        ORDER BY u.phone'''),
    ))
      r.toList(),
  ];

  test('PUT 204, gọi lại thì chỉ giữ token mới nhất (TA3-12)', () async {
    final pair = await app.register();
    final first = randomApnsToken();
    final second = randomApnsToken();
    final update = randomApnsToken();
    expect((await put(pair.accessToken, body(start: first))).status, 204);
    expect(
      (await put(
        pair.accessToken,
        body(start: second, update: update, date: '2026-10-12'),
      )).status,
      204,
    );
    expect(await rows(), [
      ['0912345678', second, update, '2026-10-12', 'sandbox'],
    ]);
  });

  test('DELETE 204, gọi lại vẫn 204', () async {
    final pair = await app.register();
    await put(pair.accessToken, body());
    for (var i = 0; i < 2; i++) {
      final res = await app.send(
        'DELETE',
        '/v1/me/live-activity-token',
        token: pair.accessToken,
      );
      expect(res.status, 204);
    }
    expect(await rows(), isEmpty);
  });

  test('dữ liệu sai → 422; thiếu access token → 401', () async {
    final pair = await app.register();
    for (final bad in [
      {...body(), 'environment': 'staging'},
      {...body(), 'pushToStartToken': '${randomApnsToken()}_không_phải_hex'},
      {...body(), 'activityDate': '12/10/2026'},
      {...body(), 'appVersion': ''},
    ]) {
      final res = await put(pair.accessToken, bad);
      expect(
        (res.status, res.errorCode),
        (422, 'validation_failed'),
        reason: '$bad',
      );
    }
    final noAuth = await app.send(
      'PUT',
      '/v1/me/live-activity-token',
      body: body(),
    );
    expect(noAuth.status, 401);
    expect(await rows(), isEmpty);
  });

  test('TAC3-13: tài khoản A ghi / xóa chỉ đụng token của A', () async {
    final a = await app.register();
    final b = await app.register(phone: '0987654321', name: 'Lan');
    final bToken = randomApnsToken();
    await put(b.accessToken, body(start: bToken));
    await put(a.accessToken, body());
    await app.send(
      'DELETE',
      '/v1/me/live-activity-token',
      token: a.accessToken,
    );
    expect(await rows(), [
      ['0987654321', bToken, null, null, 'sandbox'],
    ]);
  });

  test('contract: toJson ↔ fromJson', () {
    final r = LiveActivityTokenRequest.fromJson(
      body(update: randomApnsToken(), date: '2026-10-12'),
    );
    expect(LiveActivityTokenRequest.fromJson(r.toJson()).toJson(), r.toJson());
  });
}
