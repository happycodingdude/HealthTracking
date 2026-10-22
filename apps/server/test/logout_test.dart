import 'package:api_contract/api_contract.dart';
import 'package:postgres/postgres.dart';
import 'package:server/testing.dart';
import 'package:test/test.dart';

import 'support/test_app.dart';

/// 06 Bản 3 VS38-T05 (server): `POST /v1/auth/logout` — thu hồi chuỗi, 204 gọi
/// lại được, token cũ bị từ chối, xóa `live_activity_tokens`, không đụng phiên
/// máy khác hay tài khoản khác (TD3-18, TA3-09, TAC3-10).
void main() {
  late TestApp app;

  setUp(() async => app = await TestApp.create());
  tearDown(() => app.dispose());

  Future<TestResponse> logout(TokenPair pair, [String? refreshToken]) =>
      app.post('/v1/auth/logout', {
        'refreshToken': refreshToken ?? pair.refreshToken,
      }, token: pair.accessToken);

  Future<TestResponse> refresh(String refreshToken) =>
      app.post('/v1/auth/refresh', {'refreshToken': refreshToken});

  Future<TokenPair> login(String phone) async {
    final res = await app.post('/v1/auth/login', {
      'phone': phone,
      'password': testPassword,
    });
    expect(res.status, 200);
    return TokenPair.fromJson(res.json);
  }

  Future<String> userId(TokenPair pair) async => MeResponse.fromJson(
    (await app.get('/v1/me', token: pair.accessToken)).json,
  ).userId;

  Future<void> addActivityToken(String user) => app.tdb.pool.execute(
    Sql.named('''
      INSERT INTO live_activity_tokens (user_id, push_to_start_token,
                                        environment, app_version)
      VALUES (@user, @token, 'sandbox', '3.0.0')'''),
    parameters: {'user': user, 'token': randomTestSecret()},
  );

  Future<int> activityTokens(String user) async =>
      (await app.tdb.pool.execute(
            Sql.named(
              'SELECT count(*) FROM live_activity_tokens WHERE user_id = @user',
            ),
            parameters: {'user': user},
          )).single[0]!
          as int;

  test('TAC3-10: 204 → refresh token cũ (và token đã xoay sau đó) bị từ chối, '
      'token thẻ của tài khoản bị xóa', () async {
    final first = await app.register();
    final user = await userId(first);
    await addActivityToken(user);
    // Phiên đã xoay một lần: máy gửi token mới nhất của chuỗi.
    final current = TokenPair.fromJson(
      (await refresh(first.refreshToken)).json,
    );
    final res = await logout(current);
    expect(res.status, 204);
    expect((await refresh(current.refreshToken)).status, 401);
    expect((await refresh(first.refreshToken)).status, 401);
    expect(await activityTokens(user), 0);
  });

  test('gửi token cũ của chuỗi vẫn thu hồi cả chuỗi (máy đã xoay token khi '
      'đang gọi đăng xuất)', () async {
    final first = await app.register();
    final current = TokenPair.fromJson(
      (await refresh(first.refreshToken)).json,
    );
    expect((await logout(current, first.refreshToken)).status, 204);
    expect((await refresh(current.refreshToken)).status, 401);
  });

  test('TD3-18: gọi lại sau khi đã thu hồi → vẫn 204', () async {
    final pair = await app.register();
    expect((await logout(pair)).status, 204);
    expect((await logout(pair)).status, 204);
    expect((await logout(pair, randomTestSecret())).status, 204);
  });

  test('TA3-09: máy khác cùng tài khoản vẫn đăng nhập', () async {
    final a = await app.register();
    final b = await login('0912345678');
    expect((await logout(a)).status, 204);
    final rotated = await refresh(b.refreshToken);
    expect(rotated.status, 200);
  });

  test('truy cập chéo: tài khoản A không thu hồi được phiên của B, không xóa '
      'token thẻ của B', () async {
    final a = await app.register();
    final b = await app.register(phone: '0987654321', name: 'Lan');
    final bUser = await userId(b);
    await addActivityToken(bUser);
    expect((await logout(a, b.refreshToken)).status, 204);
    expect((await refresh(b.refreshToken)).status, 200);
    expect(await activityTokens(bUser), 1);
    // Phiên của A vẫn còn vì A gửi token không phải của mình.
    expect((await refresh(a.refreshToken)).status, 200);
  });

  test('cần access token; thiếu refreshToken → 422', () async {
    final pair = await app.register();
    final noToken = await app.post('/v1/auth/logout', {
      'refreshToken': pair.refreshToken,
    });
    expect((noToken.status, noToken.errorCode), (401, 'unauthorized'));
    final missing = await app.post(
      '/v1/auth/logout',
      <String, Object?>{},
      token: pair.accessToken,
    );
    expect((missing.status, missing.errorCode), (422, 'validation_failed'));
    expect((await refresh(pair.refreshToken)).status, 200);
  });
}
