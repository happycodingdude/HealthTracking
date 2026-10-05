import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'app/env.dart';
import 'app/providers.dart';
import 'core/error_reporting.dart';
import 'data/db/open_database.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final env = AppEnv.fromEnvironment();
  await runWithErrorReporting(env, () {
    final db = openAppDatabase();
    runApp(
      ProviderScope(
        // Không tự thử lại provider lỗi; lỗi được xử lý tường minh.
        retry: (_, _) => null,
        overrides: [
          envProvider.overrideWithValue(env),
          databaseProvider.overrideWithValue(db),
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
