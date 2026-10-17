import 'dart:async';

import 'package:api_contract/api_contract.dart' show AppVersion;
import 'package:domain/domain.dart';
import 'package:domain/testing.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/app/env.dart';
import 'package:mobile/app/providers.dart';
import 'package:mobile/data/api/app_version_interceptor.dart';
import 'package:mobile/data/auth/auth_interceptor.dart';
import 'package:mobile/data/auth/session_store.dart';
import 'package:mobile/data/connectivity.dart';
import 'package:mobile/data/db/app_database.dart';
import 'package:mobile/data/local_marks.dart';
import 'package:mobile/data/notifications/notification_gateway.dart';
import 'package:mobile/data/sync/sync_providers.dart';
import 'package:mobile/features/auth/application/auth_controller.dart';
import 'package:mobile/features/me/application/calorie_updates.dart';
import 'package:mobile/features/me/application/reminders.dart';
import 'package:mobile/features/onboarding/application/setup_state.dart';

import 'fake_notifications.dart';
import 'fake_server.dart';
import 'fake_sync.dart';

/// Phiên thử đã đăng nhập (refresh token ngẫu nhiên mỗi lần chạy test).
final signedInSession = StoredSession(
  userId: 'u1',
  phone: '0912345678',
  refreshToken: randomTestSecret(),
);

/// Access token mà server giả trả về khi làm mới phiên mặc định.
final refreshedAccessToken = randomTestSecret();

/// Mặc định của [appOverrides] `session` (đã đăng nhập, [signedInSession]);
/// truyền `null` = chưa đăng nhập.
const _signedInByDefault = StoredSession(userId: '', phone: '');

/// Override chung cho test dựng cả app: không chạm Keychain, mạng thật hay file.
List<Override> appOverrides({
  StoredSession? session = _signedInByDefault,
  FakeServer? server,
  AppDatabase? db,
  String flavor = 'prod',
  FakeScheduler? scheduler,
  FakeConnectivity? connectivity,
  Clock? clock,
  bool onboarded = true,
  SetupState? initialSetup,
  NotificationGateway? notifications,
  LocalMarks? marks,
}) {
  final initial = identical(session, _signedInByDefault)
      ? signedInSession
      : session;
  final store = MemorySessionStore(initial);
  final database = db ?? AppDatabase(NativeDatabase.memory());
  addTearDown(database.close);
  final fake = server ?? FakeServer();
  // Làm mới token mặc định thành công (phiên thử chỉ có refresh token).
  fake.routes.putIfAbsent(
    'POST /v1/auth/refresh',
    () =>
        (_) => (
          200,
          {
            'accessToken': refreshedAccessToken,
            'refreshToken': randomTestSecret(),
            'accessTokenExpiresAt': '2099-01-01T00:00:00.000Z',
          },
        ),
  );
  // Đồng bộ mặc định thành công, không có thay đổi mới (test cần thì ghi đè).
  fake.routes.putIfAbsent(
    'POST /v1/sync/push',
    () => (req) {
      final mutations = (req.body! as Map)['mutations']! as List;
      return (
        200,
        {
          'results': [
            for (final m in mutations)
              {'mutationId': (m as Map)['mutationId'], 'status': 'applied'},
          ],
        },
      );
    },
  );
  fake.routes.putIfAbsent(
    'GET /v1/sync/pull',
    () =>
        (req) => (
          200,
          {
            'changes': <Object>[],
            'nextCursor': int.parse(req.query['cursor'] as String? ?? '0'),
            'hasMore': false,
            'remaining': 0,
            'meta': {'serverTime': '2026-10-07T11:42:00.000Z'},
          },
        ),
  );
  return [
    envProvider.overrideWithValue(
      AppEnv(flavor: flavor, apiBaseUrl: 'http://server.test'),
    ),
    sessionStoreProvider.overrideWithValue(store),
    initialSessionProvider.overrideWithValue(initial),
    // Đã đăng nhập: mặc định coi như đã thiết lập xong (test các tab). Test
    // thiết lập lần đầu truyền `onboarded: false` để đọc trạng thái thật từ
    // database.
    if (onboarded && initial != null) ...[
      initialSetupProvider.overrideWithValue(SetupState.completed),
      setupStateProvider.overrideWith(
        (ref) => Stream.value(SetupState.completed),
      ),
    ] else if (initialSetup != null)
      initialSetupProvider.overrideWithValue(initialSetup),
    databaseProvider.overrideWithValue(database),
    syncSchedulerProvider.overrideWithValue(scheduler ?? FakeScheduler()),
    notificationGatewayProvider.overrideWithValue(
      notifications ?? FakeNotificationGateway(),
    ),
    connectivityProvider.overrideWithValue(connectivity ?? FakeConnectivity()),
    localMarksProvider.overrideWithValue(marks ?? MemoryLocalMarks()),
    clockProvider.overrideWithValue(
      clock ?? FixedClock(DateTime(2026, 10, 7, 18, 42)),
    ),
    appVersionProvider.overrideWithValue(AppVersion.v2),
    publicApiClientProvider.overrideWith(
      (ref) => fake.client()
        ..dio.interceptors.add(
          AppVersionInterceptor(ref.watch(appVersionProvider)),
        ),
    ),
    apiClientProvider.overrideWith((ref) {
      final api = fake.client();
      api.dio.interceptors
        ..add(AppVersionInterceptor(ref.watch(appVersionProvider)))
        ..add(AuthInterceptor(api.dio, ref.watch(tokenManagerProvider)));
      return api;
    }),
  ];
}

/// Mạng giả: test bật/tắt bằng [setOnline].
final class FakeConnectivity implements ConnectivityMonitor {
  final _changes = StreamController<bool>.broadcast();
  bool online = true;

  void setOnline(bool value) {
    online = value;
    _changes.add(value);
  }

  @override
  Future<bool> isOnline() async => online;

  @override
  Stream<bool> get changes => _changes.stream;
}
