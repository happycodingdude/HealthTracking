import 'package:domain/domain.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/error_reporting.dart';
import '../data/api/api_client.dart';
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

final apiClientProvider = Provider<ApiClient>(
  (ref) => ApiClient.create(ref.watch(envProvider).apiBaseUrl),
);

final connectivityProvider = Provider<ConnectivityMonitor>(
  (ref) => DeviceConnectivity(),
);

final errorReporterProvider = Provider<ErrorReporter>(
  (ref) => const DebugErrorReporter(),
);
