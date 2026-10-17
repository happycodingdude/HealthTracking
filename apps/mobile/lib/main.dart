import 'package:api_contract/api_contract.dart' show AppVersion;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:package_info_plus/package_info_plus.dart';

import 'app/app.dart';
import 'app/env.dart';
import 'app/providers.dart';
import 'core/error_reporting.dart';
import 'data/auth/session_store.dart';
import 'data/db/app_database.dart';
import 'data/db/open_database.dart';
import 'features/auth/application/auth_controller.dart';
import 'features/me/data/profile_repository.dart';
import 'features/onboarding/application/setup_state.dart';

Future<void> main() => runIronlyApp();

/// Khởi động app. [overrides], [database] chỉ dùng cho integration test (ví
/// dụ đồng hồ, database trống như iPhone mới).
Future<void> runIronlyApp({
  List<Override> overrides = const [],
  AppDatabase? database,
}) async {
  WidgetsFlutterBinding.ensureInitialized();
  final env = AppEnv.fromEnvironment();
  await runWithErrorReporting(env, () async {
    final db = database ?? openAppDatabase();
    final version = AppVersion.parse(
      (await PackageInfo.fromPlatform()).version,
    );
    final sessionStore = SecureSessionStore();
    // Đọc phiên trước khi vẽ màn hình đầu: có phiên thì vào thẳng app (UA-23).
    final session = await sessionStore.read();
    // Thiết lập dở thì mở đúng bước còn dở (OB-3).
    final profile = await ProfileRepository(db).get();
    final setup = SetupState.of(profile);
    runApp(
      ProviderScope(
        // Không tự thử lại provider lỗi; lỗi được xử lý tường minh.
        retry: (_, _) => null,
        overrides: [
          envProvider.overrideWithValue(env),
          appVersionProvider.overrideWithValue(version),
          databaseProvider.overrideWithValue(db),
          sessionStoreProvider.overrideWithValue(sessionStore),
          initialSessionProvider.overrideWithValue(session),
          initialSetupProvider.overrideWithValue(setup),
          // Có phiên mà máy chưa có hồ sơ: cài lại app hoặc tắt app giữa lúc
          // khôi phục → khôi phục trước (S-07).
          initialRestoreProvider.overrideWithValue(
            session != null && profile == null,
          ),
          errorReporterProvider.overrideWithValue(
            env.sentryDsn.isEmpty
                ? const DebugErrorReporter()
                : const SentryErrorReporter(),
          ),
          ...overrides,
        ],
        child: const IronlyApp(),
      ),
    );
  });
}
