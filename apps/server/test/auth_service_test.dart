import 'package:api_contract/api_contract.dart';
import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import 'package:domain/domain.dart';
import 'package:postgres/postgres.dart';
import 'package:server/server.dart';
import 'package:server/src/auth/auth_service.dart';
import 'package:server/src/auth/login_rate_limiter.dart';
import 'package:server/src/auth/token_service.dart';
import 'package:server/testing.dart';
import 'package:test/test.dart';

const secret = 'test-secret-test-secret-test-secret-123';

void main() {
  late TestDatabase tdb;
  late FixedClock clock;
  late TokenService tokens;
  late AuthService auth;

  setUpAll(() async => tdb = await TestDatabase.create());
  tearDownAll(() => tdb.dispose());

  setUp(() async {
    await tdb.pool.execute('TRUNCATE users CASCADE');
    clock = FixedClock(DateTime.utc(2026, 10, 7, 10));
    tokens = TokenService(secret: secret, clock: clock);
    auth = AuthService(
      pool: tdb.pool,
      tokens: tokens,
      limiter: LoginRateLimiter(clock),
      bcryptCost: 4,
    );
  });

  const minh = RegisterRequest(
    displayName: ' Minh ',
    phone: '0912 345 678',
    password: 'matkhau123',
  );

  Matcher apiError(ErrorCode code, [String? field]) => isA<ApiException>()
      .having((e) => e.code, 'code', code)
      .having((e) => e.field, 'field', field);

  group('register', () {
    test('tạo tài khoản, chuẩn hóa tên và số, trả cặp token', () async {
      final pair = await auth.register(minh);
      final userId = tokens.verifyAccessToken(pair.accessToken);
      expect(userId, isNotNull);
      final row = (await tdb.pool.execute(
        Sql.named(
          'SELECT phone, display_name, password_hash FROM users WHERE id = @id',
        ),
        parameters: {'id': userId},
      )).single;
      expect(row[0], '0912345678');
      expect(row[1], 'Minh');
      expect(row[2], startsWith(r'$2a$04$'));
      expect(row[2], isNot(contains('matkhau123')));
      expect(
        pair.accessTokenExpiresAt,
        clock.now().add(const Duration(minutes: 15)),
      );
    });

    test('TD-09: bcrypt cost 12', () async {
      final strict = AuthService(
        pool: tdb.pool,
        tokens: tokens,
        limiter: LoginRateLimiter(clock),
        bcryptCost: 12,
      );
      await strict.register(minh);
      final hash = (await tdb.pool.execute(
        "SELECT password_hash FROM users WHERE phone = '0912345678'",
      )).single[0];
      expect(hash, startsWith(r'$2a$12$'));
    });

    test('UX-AC21: số đã có tài khoản → phone_taken (field phone)', () async {
      await auth.register(minh);
      await expectLater(
        auth.register(
          const RegisterRequest(
            displayName: 'Lan',
            phone: '0912345678',
            password: 'khac12345',
          ),
        ),
        throwsA(apiError(ErrorCode.phoneTaken, 'phone')),
      );
    });

    test(
      'server kiểm tra lại UA-19/20/21 → validation_failed theo ô',
      () async {
        await expectLater(
          auth.register(
            const RegisterRequest(
              displayName: '',
              phone: '0912345678',
              password: 'matkhau123',
            ),
          ),
          throwsA(apiError(ErrorCode.validationFailed, 'displayName')),
        );
        await expectLater(
          auth.register(
            const RegisterRequest(
              displayName: 'Minh',
              phone: '912345678',
              password: 'matkhau123',
            ),
          ),
          throwsA(apiError(ErrorCode.validationFailed, 'phone')),
        );
        await expectLater(
          auth.register(
            const RegisterRequest(
              displayName: 'Minh',
              phone: '0912345678',
              password: '1234567',
            ),
          ),
          throwsA(apiError(ErrorCode.validationFailed, 'password')),
        );
      },
    );
  });

  group('login', () {
    test('đúng mật khẩu (nhận cả số có khoảng trắng) → cặp token', () async {
      await auth.register(minh);
      final pair = await auth.login(
        const LoginRequest(phone: '0912 345 678', password: 'matkhau123'),
        ip: '1.1.1.1',
      );
      expect(tokens.verifyAccessToken(pair.accessToken), isNotNull);
    });

    test(
      'sai mật khẩu hoặc số chưa đăng ký → cùng invalid_credentials',
      () async {
        await auth.register(minh);
        await expectLater(
          auth.login(
            const LoginRequest(phone: '0912345678', password: 'sai'),
            ip: '1.1.1.1',
          ),
          throwsA(apiError(ErrorCode.invalidCredentials)),
        );
        await expectLater(
          auth.login(
            const LoginRequest(phone: '0999999999', password: 'matkhau123'),
            ip: '1.1.1.1',
          ),
          throwsA(apiError(ErrorCode.invalidCredentials)),
        );
      },
    );

    test(
      'TAC-15: sai 6 lần liên tiếp → lần 6 bị chặn, kể cả khi đúng mật khẩu; 15 phút sau mở lại',
      () async {
        await auth.register(minh);
        for (var i = 1; i <= 5; i++) {
          await expectLater(
            auth.login(
              LoginRequest(phone: '0912345678', password: 'sai-$i'),
              ip: '1.1.1.1',
            ),
            throwsA(apiError(ErrorCode.invalidCredentials)),
          );
        }
        await expectLater(
          auth.login(
            const LoginRequest(phone: '0912345678', password: 'sai-6'),
            ip: '1.1.1.1',
          ),
          throwsA(apiError(ErrorCode.tooManyAttempts)),
        );
        await expectLater(
          auth.login(
            const LoginRequest(phone: '0912345678', password: 'matkhau123'),
            ip: '8.8.8.8',
          ),
          throwsA(apiError(ErrorCode.tooManyAttempts)),
        );
        clock.advance(const Duration(minutes: 15));
        expect(
          await auth.login(
            const LoginRequest(phone: '0912345678', password: 'matkhau123'),
            ip: '8.8.8.8',
          ),
          isA<TokenPair>(),
        );
      },
    );
  });

  group('access token (JWT HS256, 15 phút)', () {
    test('hết hạn sau 15 phút', () async {
      final pair = await auth.register(minh);
      clock.advance(const Duration(minutes: 14, seconds: 59));
      expect(tokens.verifyAccessToken(pair.accessToken), isNotNull);
      clock.advance(const Duration(seconds: 1));
      expect(tokens.verifyAccessToken(pair.accessToken), isNull);
    });

    test('chữ ký sai, khóa khác, alg none → không hợp lệ', () async {
      final pair = await auth.register(minh);
      final parts = pair.accessToken.split('.');
      expect(tokens.verifyAccessToken('${parts[0]}.${parts[1]}.AAAA'), isNull);
      final other = TokenService(
        secret: 'another-secret-another-secret-123456',
        clock: clock,
      );
      expect(other.verifyAccessToken(pair.accessToken), isNull);
      final none = JWT({
        'sub': 'x',
        'exp': 9999999999,
      }).sign(SecretKey('x'), algorithm: JWTAlgorithm.HS512);
      expect(tokens.verifyAccessToken(none), isNull);
      expect(tokens.verifyAccessToken('rác'), isNull);
    });
  });

  group('refresh token (TD-10)', () {
    test('xoay vòng: token cũ bị thu hồi, token mới dùng được', () async {
      final first = await auth.register(minh);
      final second = await auth.refresh(
        RefreshRequest(refreshToken: first.refreshToken),
      );
      expect(second.refreshToken, isNot(first.refreshToken));
      final third = await auth.refresh(
        RefreshRequest(refreshToken: second.refreshToken),
      );
      expect(tokens.verifyAccessToken(third.accessToken), isNotNull);
      final rows = await tdb.pool.execute(
        'SELECT count(*) FILTER (WHERE revoked_at IS NULL), count(DISTINCT family_id) FROM refresh_tokens',
      );
      expect(rows.single[0], 1);
      expect(rows.single[1], 1);
    });

    test('dùng lại token đã xoay → unauthorized và thu hồi cả chuỗi', () async {
      final first = await auth.register(minh);
      final second = await auth.refresh(
        RefreshRequest(refreshToken: first.refreshToken),
      );
      await expectLater(
        auth.refresh(RefreshRequest(refreshToken: first.refreshToken)),
        throwsA(apiError(ErrorCode.unauthorized)),
      );
      await expectLater(
        auth.refresh(RefreshRequest(refreshToken: second.refreshToken)),
        throwsA(apiError(ErrorCode.unauthorized)),
      );
    });

    test(
      'TA-10: 180 ngày kể từ lần dùng cuối; quá hạn → unauthorized',
      () async {
        final first = await auth.register(minh);
        clock.advance(const Duration(days: 179));
        final second = await auth.refresh(
          RefreshRequest(refreshToken: first.refreshToken),
        );
        clock.advance(const Duration(days: 179));
        final third = await auth.refresh(
          RefreshRequest(refreshToken: second.refreshToken),
        );
        clock.advance(const Duration(days: 180));
        await expectLater(
          auth.refresh(RefreshRequest(refreshToken: third.refreshToken)),
          throwsA(apiError(ErrorCode.unauthorized)),
        );
      },
    );

    test('token lạ → unauthorized; chỉ lưu SHA-256 32 byte', () async {
      final pair = await auth.register(minh);
      await expectLater(
        auth.refresh(const RefreshRequest(refreshToken: 'khong-ton-tai')),
        throwsA(apiError(ErrorCode.unauthorized)),
      );
      final stored =
          (await tdb.pool.execute(
                'SELECT token_hash FROM refresh_tokens',
              )).single[0]!
              as List<int>;
      expect(stored, hasLength(32));
      expect(stored, TokenService.hashRefreshToken(pair.refreshToken));
    });

    test('revokeAll thu hồi mọi phiên của tài khoản', () async {
      final pair = await auth.register(minh);
      final userId = tokens.verifyAccessToken(pair.accessToken)!;
      await tdb.pool.runTx((tx) => tokens.revokeAll(tx, userId));
      await expectLater(
        auth.refresh(RefreshRequest(refreshToken: pair.refreshToken)),
        throwsA(apiError(ErrorCode.unauthorized)),
      );
    });
  });
}
