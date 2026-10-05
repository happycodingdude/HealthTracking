import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'app/env.dart';
import 'app/providers.dart';
import 'core/error_reporting.dart';
import 'data/auth/session_store.dart';
import 'data/db/open_database.dart';
import 'features/auth/application/auth_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final env = AppEnv.fromEnvironment();
  await runWithErrorReporting(env, () async {
    final db = openAppDatabase();
    final sessionStore = SecureSessionStore();
    // Đọc phiên trước khi vẽ màn hình đầu: có phiên thì vào thẳng app (UA-23).
    final session = await sessionStore.read();
    runApp(
      ProviderScope(
        // Không tự thử lại provider lỗi; lỗi được xử lý tường minh.
        retry: (_, _) => null,
        overrides: [
          envProvider.overrideWithValue(env),
          databaseProvider.overrideWithValue(db),
          sessionStoreProvider.overrideWithValue(sessionStore),
          initialSessionProvider.overrideWithValue(session),
          errorReporterProvider.overrideWithValue(
            env.sentryDsn.isEmpty
                ? const DebugErrorReporter()
                : const SentryErrorReporter(),
          ),
        ],
        child: const HealthApp(),
      ),
    );
  });
}
