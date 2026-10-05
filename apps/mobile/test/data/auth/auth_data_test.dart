import 'package:api_contract/api_contract.dart';
import 'package:domain/domain.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/data/api/api_client.dart';
import 'package:mobile/data/auth/auth_interceptor.dart';
import 'package:mobile/data/auth/auth_repository.dart';
import 'package:mobile/data/auth/session_store.dart';
import 'package:mobile/data/auth/token_manager.dart';

import '../../support/fake_server.dart';

void main() {
  late FakeServer server;
  late FixedClock clock;
  late MemorySessionStore store;
  late TokenManager tokens;
  late ApiClient api;
  late AuthRepository repo;
  var refreshCount = 0;
  var validAccess = 'A1';

  Map<String, Object?> pair(String access, String refresh) => TokenPair(
    accessToken: access,
    refreshToken: refresh,
    accessTokenExpiresAt: clock.now().toUtc().add(const Duration(minutes: 15)),
  ).toJson();

  setUp(() {
    server = FakeServer();
    clock = FixedClock(DateTime.utc(2026, 10, 7, 10));
    store = MemorySessionStore();
    refreshCount = 0;
    validAccess = 'A1';
    api = server.client();
    tokens = TokenManager(
      store: store,
      clock: clock,
      refreshCall: (rt) => AuthRepository.refreshWith(api, rt),
    );
    api.dio.interceptors.add(AuthInterceptor(api.dio, tokens));
    repo = AuthRepository(api: api, tokens: tokens, store: store);

    server
      ..on('POST', '/v1/auth/register', (_) => (201, pair('A1', 'R1')))
      ..on('POST', '/v1/auth/login', (_) => (200, pair('A1', 'R1')))
      ..on('POST', '/v1/auth/refresh', (req) async {
        refreshCount++;
        await Future<void>.delayed(const Duration(milliseconds: 10));
        final rt = (req.body! as Map)['refreshToken'];
        if (rt != 'R$refreshCount') return (401, unauthorizedBody());
        validAccess = 'A${refreshCount + 1}';
        return (200, pair(validAccess, 'R${refreshCount + 1}'));
      })
      ..on('GET', '/v1/me', (req) {
        if (req.authorization != 'Bearer $validAccess') {
          return (401, unauthorizedBody());
        }
        return (
          200,
          {
            'userId': 'u1',
            'phone': '0912345678',
            'displayName': 'Minh',
            'onboardingState': 'not_started',
          },
        );
      });
  });

  test(
    'register: lưu phiên (userId, số, refresh token); endpoint auth không gửi Authorization',
    () async {
      final me = await repo.register(
        const RegisterRequest(
          displayName: 'Minh',
          phone: '0912345678',
          password: 'matkhau123',
        ),
      );
      expect(me.userId, 'u1');
      expect(store.session!.userId, 'u1');
      expect(store.session!.phone, '0912345678');
      expect(store.session!.refreshToken, 'R1');
      expect(
        server.calls('POST', '/v1/auth/register').single.authorization,
        isNull,
      );
      expect(server.calls('GET', '/v1/me').single.authorization, 'Bearer A1');
      expect(refreshCount, 0);
    },
  );

  test(
    'VS01-T08: nhiều request cùng 401 → chỉ làm mới token một lần, tất cả gửi lại thành công',
    () async {
      await repo.login(
        const LoginRequest(phone: '0912345678', password: 'matkhau123'),
      );
      validAccess = 'đã đổi'; // token A1 bị server từ chối
      final results = await Future.wait([
        repo.fetchMe(),
        repo.fetchMe(),
        repo.fetchMe(),
      ]);
      expect(results.map((m) => m.userId), everyElement('u1'));
      expect(refreshCount, 1);
      expect(
        store.session!.refreshToken,
        'R2',
        reason: 'refresh token mới được lưu',
      );
    },
  );

  test(
    'UA-23: mở lại app chỉ có refresh token → tự làm mới một lần rồi gọi API',
    () async {
      store.session = const StoredSession(
        userId: 'u1',
        phone: '0912345678',
        refreshToken: 'R1',
      );
      final results = await Future.wait([repo.fetchMe(), repo.fetchMe()]);
      expect(results, hasLength(2));
      expect(refreshCount, 1);
    },
  );

  test('access token sắp hết hạn → làm mới trước khi gọi', () async {
    await repo.login(
      const LoginRequest(phone: '0912345678', password: 'matkhau123'),
    );
    clock.advance(const Duration(minutes: 14, seconds: 45));
    await repo.fetchMe();
    expect(refreshCount, 1);
    expect(server.calls('GET', '/v1/me').last.authorization, 'Bearer A2');
  });

  test(
    'TA-10: refresh bị từ chối → phiên hết hạn: báo onExpired, bỏ refresh token, giữ userId',
    () async {
      store.session = const StoredSession(
        userId: 'u1',
        phone: '0912345678',
        refreshToken: 'R-cu',
      );
      final expired = tokens.onExpired.first;
      await expectLater(
        repo.fetchMe(),
        throwsA(
          isA<ServerFailure>().having(
            (f) => f.error.code,
            'code',
            ErrorCode.unauthorized,
          ),
        ),
      );
      await expired;
      expect(store.session!.refreshToken, isNull);
      expect(store.session!.userId, 'u1');
    },
  );

  test('mất mạng khi làm mới → NetworkFailure, phiên vẫn giữ', () async {
    store.session = const StoredSession(
      userId: 'u1',
      phone: '0912345678',
      refreshToken: 'R1',
    );
    server.offline = true;
    await expectLater(repo.fetchMe(), throwsA(isA<NetworkFailure>()));
    expect(store.session!.refreshToken, 'R1');
  });

  test(
    'chưa từng đăng nhập → request cần đăng nhập bị unauthorized, không gọi refresh',
    () async {
      await expectLater(repo.fetchMe(), throwsA(isA<ServerFailure>()));
      expect(server.calls('POST', '/v1/auth/refresh'), isEmpty);
    },
  );
}
