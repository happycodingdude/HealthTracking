import 'package:api_contract/api_contract.dart';
import 'package:test/test.dart';

import 'support/test_app.dart';

void main() {
  late TestApp app;

  setUp(() async => app = await TestApp.create());
  tearDown(() => app.dispose());

  group('POST /v1/auth/register', () {
    test('201 + TokenPair', () async {
      final res = await app.post('/v1/auth/register', {
        'displayName': 'Minh',
        'phone': '0912 345 678',
        'password': 'matkhau123',
      });
      expect(res.status, 201);
      final pair = TokenPair.fromJson(res.json);
      expect(pair.accessToken, isNotEmpty);
      expect(pair.refreshToken, isNotEmpty);
    });

    test('UX-AC21: trùng số → 409 phone_taken field phone', () async {
      await app.register();
      final res = await app.post('/v1/auth/register', {
        'displayName': 'Lan',
        'phone': '0912345678',
        'password': 'khac12345',
      });
      expect(res.status, 409);
      expect(res.errorCode, 'phone_taken');
      expect(res.errorField, 'phone');
    });

    test(
      'dữ liệu sai → 422 validation_failed theo ô; thân hỏng → field body',
      () async {
        var res = await app.post('/v1/auth/register', {
          'displayName': 'Minh',
          'phone': '0912345678',
          'password': '123',
        });
        expect(
          (res.status, res.errorCode, res.errorField),
          (422, 'validation_failed', 'password'),
        );
        res = await app.post('/v1/auth/register', {
          'displayName': 'Minh',
          'password': '12345678',
        });
        expect((res.status, res.errorField), (422, 'phone'));
        res = await app.post('/v1/auth/register', '{not json');
        expect((res.status, res.errorField), (422, 'body'));
      },
    );
  });

  group('POST /v1/auth/login', () {
    test('đúng → 200; sai mật khẩu → 401 invalid_credentials', () async {
      await app.register();
      final ok = await app.post('/v1/auth/login', {
        'phone': '0912345678',
        'password': 'matkhau123',
      });
      expect(ok.status, 200);
      expect(TokenPair.fromJson(ok.json).accessToken, isNotEmpty);
      final bad = await app.post('/v1/auth/login', {
        'phone': '0912345678',
        'password': 'sai12345',
      });
      expect((bad.status, bad.errorCode), (401, 'invalid_credentials'));
    });

    test(
      'TAC-15: sai 6 lần liên tiếp → lần 6 bị chặn 429 too_many_attempts',
      () async {
        await app.register();
        for (var i = 1; i <= 5; i++) {
          final r = await app.post('/v1/auth/login', {
            'phone': '0912345678',
            'password': 'sai-$i-xx',
          });
          expect(r.errorCode, 'invalid_credentials', reason: 'lần $i');
        }
        final sixth = await app.post('/v1/auth/login', {
          'phone': '0912345678',
          'password': 'matkhau123',
        });
        expect((sixth.status, sixth.errorCode), (429, 'too_many_attempts'));
      },
    );

    test('chặn theo IP lấy từ X-Forwarded-For (sau Caddy)', () async {
      for (var i = 0; i < 5; i++) {
        await app.post(
          '/v1/auth/login',
          {'phone': '090000000$i', 'password': 'x'},
          headers: {'x-forwarded-for': '1.2.3.4, 5.6.7.8'},
        );
      }
      final blocked = await app.post(
        '/v1/auth/login',
        {'phone': '0912345678', 'password': 'x'},
        headers: {'x-forwarded-for': '9.9.9.9, 5.6.7.8'},
      );
      expect(
        blocked.errorCode,
        'too_many_attempts',
        reason: 'IP thật là giá trị cuối do Caddy thêm',
      );
      final other = await app.post(
        '/v1/auth/login',
        {'phone': '0912345678', 'password': 'x'},
        headers: {'x-forwarded-for': '7.7.7.7'},
      );
      expect(other.errorCode, 'invalid_credentials');
    });
  });

  group('POST /v1/auth/refresh', () {
    test('xoay vòng; dùng lại token cũ → 401 và thu hồi cả chuỗi', () async {
      final first = await app.register();
      final r1 = await app.post('/v1/auth/refresh', {
        'refreshToken': first.refreshToken,
      });
      expect(r1.status, 200);
      final second = TokenPair.fromJson(r1.json);
      final reuse = await app.post('/v1/auth/refresh', {
        'refreshToken': first.refreshToken,
      });
      expect((reuse.status, reuse.errorCode), (401, 'unauthorized'));
      final afterReuse = await app.post('/v1/auth/refresh', {
        'refreshToken': second.refreshToken,
      });
      expect(afterReuse.status, 401);
    });

    test('refresh hết hạn (quá 180 ngày) → 401', () async {
      final first = await app.register();
      app.clock.advance(const Duration(days: 181));
      final r = await app.post('/v1/auth/refresh', {
        'refreshToken': first.refreshToken,
      });
      expect((r.status, r.errorCode), (401, 'unauthorized'));
    });
  });

  group('GET /v1/me', () {
    test('cần token: thiếu, sai, hết hạn → 401', () async {
      final pair = await app.register();
      expect((await app.get('/v1/me')).status, 401);
      expect((await app.get('/v1/me', token: 'rac')).status, 401);
      app.clock.advance(const Duration(minutes: 15));
      final expired = await app.get('/v1/me', token: pair.accessToken);
      expect((expired.status, expired.errorCode), (401, 'unauthorized'));
    });

    test(
      'trả tài khoản của token, onboardingState = not_started (VS-01)',
      () async {
        final pair = await app.register(name: ' Minh ', phone: '0912 345 678');
        final res = await app.get('/v1/me', token: pair.accessToken);
        expect(res.status, 200);
        final me = MeResponse.fromJson(res.json);
        expect(me.phone, '0912345678');
        expect(me.displayName, 'Minh');
        expect(me.onboardingState, OnboardingState.notStarted);
        final line = app.log.lines.lastWhere(
          (l) => l.contains('"path":"/v1/me"'),
        );
        expect(line, contains(me.userId), reason: 'log có userId từ token');
      },
    );

    test('TAC-07: token của A chỉ thấy tài khoản A', () async {
      final a = await app.register(phone: '0911111111', name: 'An');
      await app.register(phone: '0922222222', name: 'Bình');
      final me = MeResponse.fromJson(
        (await app.get('/v1/me', token: a.accessToken)).json,
      );
      expect(me.displayName, 'An');
    });
  });

  test('06 §6.4.4: log không chứa mật khẩu, token, số điện thoại', () async {
    final pair = await app.register(password: 'MatKhauBiMat99');
    await app.post('/v1/auth/login', {
      'phone': '0912345678',
      'password': 'MatKhauBiMat99',
    });
    await app.post('/v1/auth/refresh', {'refreshToken': pair.refreshToken});
    await app.get('/v1/me', token: pair.accessToken);
    final all = app.log.lines.join('\n');
    expect(all, isNot(contains('MatKhauBiMat99')));
    expect(all, isNot(contains(pair.refreshToken)));
    expect(all, isNot(contains(pair.accessToken)));
    expect(all, isNot(contains('0912345678')));
  });
}
