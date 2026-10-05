import 'package:domain/domain.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/error_reporting.dart';
import '../data/api/api_client.dart';
import '../data/auth/auth_interceptor.dart';
import '../data/auth/auth_repository.dart';
import '../data/auth/session_store.dart';
import '../data/auth/token_manager.dart';
import '../data/connectivity.dart';
import '../data/db/app_database.dart';
import 'env.dart';

/// Phụ thuộc nền của app. `main.dart` override bằng giá trị thật; test override
/// bằng giá trị giả (FixedClock, Drift trong bộ nhớ, ApiClient giả).

final envProvider = Provider<AppEnv>((ref) => AppEnv.fromEnvironment());

/// Nguồn thời gian duy nhất (IS-5).
final clockProvider = Provider<Clock>((ref) => const SystemClock());

final databaseProvider = Provider<AppDatabase>(
  (ref) => throw UnimplementedError(
    'databaseProvider must be overridden at startup',
  ),
);

/// Refresh token nằm trong Keychain (05 §6.8.4).
final sessionStoreProvider = Provider<SessionStore>(
  (ref) => SecureSessionStore(),
);

final Provider<TokenManager> tokenManagerProvider = Provider<TokenManager>((
  ref,
) {
  final tokens = TokenManager(
    store: ref.watch(sessionStoreProvider),
    clock: ref.watch(clockProvider),
    // Đọc ApiClient lúc gọi để tránh phụ thuộc vòng khi khởi tạo.
    refreshCall: (refreshToken) =>
        AuthRepository.refreshWith(ref.read(apiClientProvider), refreshToken),
  );
  ref.onDispose(tokens.dispose);
  return tokens;
});

/// ApiClient có interceptor gắn access token và tự làm mới token (VS01-T08).
final Provider<ApiClient> apiClientProvider = Provider<ApiClient>((ref) {
  final api = ApiClient.create(ref.watch(envProvider).apiBaseUrl);
  api.dio.interceptors.add(
    AuthInterceptor(api.dio, ref.watch(tokenManagerProvider)),
  );
  return api;
});

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(
    api: ref.watch(apiClientProvider),
    tokens: ref.watch(tokenManagerProvider),
    store: ref.watch(sessionStoreProvider),
  ),
);

final connectivityProvider = Provider<ConnectivityMonitor>(
  (ref) => DeviceConnectivity(),
);

final errorReporterProvider = Provider<ErrorReporter>(
  (ref) => const DebugErrorReporter(),
);
