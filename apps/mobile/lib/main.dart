import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;

import 'app/app.dart';
import 'app/env.dart';
import 'app/providers.dart';
import 'core/error_reporting.dart';
import 'data/auth/session_store.dart';
import 'data/db/open_database.dart';
import 'features/auth/application/auth_controller.dart';
import 'features/me/data/profile_repository.dart';
import 'features/onboarding/application/setup_state.dart';

Future<void> main() => runHealthApp();

/// Khởi động app. [overrides] chỉ dùng cho integration test (ví dụ đồng hồ).
Future<void> runHealthApp({List<Override> overrides = const []}) async {
  WidgetsFlutterBinding.ensureInitialized();
  final env = AppEnv.fromEnvironment();
  await runWithErrorReporting(env, () async {
    final db = openAppDatabase();
    final sessionStore = SecureSessionStore();
    // Đọc phiên trước khi vẽ màn hình đầu: có phiên thì vào thẳng app (UA-23).
    final session = await sessionStore.read();
    // Thiết lập dở thì mở đúng bước còn dở (OB-3).
    final setup = SetupState.of(await ProfileRepository(db).get());
    runApp(
      ProviderScope(
        // Không tự thử lại provider lỗi; lỗi được xử lý tường minh.
        retry: (_, _) => null,
        overrides: [
          envProvider.overrideWithValue(env),
          databaseProvider.overrideWithValue(db),
          sessionStoreProvider.overrideWithValue(sessionStore),
          initialSessionProvider.overrideWithValue(session),
          initialSetupProvider.overrideWithValue(setup),
          errorReporterProvider.overrideWithValue(
            env.sentryDsn.isEmpty
                ? const DebugErrorReporter()
                : const SentryErrorReporter(),
          ),
          ...overrides,
        ],
        child: const HealthApp(),
      ),
    );
  });
}
