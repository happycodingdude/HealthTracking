import 'package:api_contract/api_contract.dart' show AppVersion;
import 'package:domain/domain.dart' show SystemClock;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:package_info_plus/package_info_plus.dart';

import 'app/app_root.dart';
import 'app/env.dart';
import 'app/providers.dart';
import 'app/router.dart';
import 'core/error_reporting.dart';
import 'data/auth/session_store.dart';
import 'data/db/app_database.dart';
import 'data/db/open_database.dart';
import 'data/device_files.dart';
import 'data/local_marks.dart';
import 'data/logout_flag.dart';
import 'data/notifications/notification_gateway.dart';
import 'features/account/application/logout.dart';
import 'features/auth/application/auth_controller.dart';
import 'features/me/data/profile_repository.dart';
import 'features/native/native_bridge.dart';
import 'features/native/native_logout_hooks.dart';
import 'features/onboarding/application/setup_state.dart';

Future<void> main() => runIronlyApp();

/// Khởi động app. [overrides], [database] chỉ dùng cho integration test (ví
/// dụ đồng hồ, database trống như iPhone mới); [database] chỉ dùng cho lần
/// khởi động đầu, sau đăng xuất app mở database mới.
Future<void> runIronlyApp({
  List<Override> overrides = const [],
  AppDatabase? database,
}) async {
  WidgetsFlutterBinding.ensureInitialized();
  final env = AppEnv.fromEnvironment();
  await runWithErrorReporting(env, () async {
    final version = AppVersion.parse(
      (await PackageInfo.fromPlatform()).version,
    );
    final reporter = env.sentryDsn.isEmpty
        ? const DebugErrorReporter()
        : const SentryErrorReporter();
    final logoutFlag = PrefsLogoutFlag();

    Future<AppStart> boot({required bool afterLogout}) async {
      final db = afterLogout
          ? openAppDatabase()
          : database ?? openAppDatabase();
      final sessionStore = SecureSessionStore();
      // Đọc phiên trước khi vẽ màn hình đầu: có phiên thì vào thẳng app (UA-23).
      final session = await sessionStore.read();
      // Thiết lập dở thì mở đúng bước còn dở (OB-3).
      final profile = await ProfileRepository(db).get();
      final setup = SetupState.of(profile);
      return (
        db: db,
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
          errorReporterProvider.overrideWithValue(reporter),
          logoutFlagProvider.overrideWithValue(logoutFlag),
          logoutDeviceHooksProvider.overrideWith(
            (ref) => NativeLogoutHooks(
              ref.watch(nativeBridgeProvider),
              ref.watch(clockProvider),
            ),
          ),
          // Đăng xuất xong: màn Đăng nhập như lần cài mới (05 Bản 3 §6.6.6).
          if (afterLogout) initialLocationProvider.overrideWithValue(loginPath),
          ...overrides,
        ],
      );
    }

    LocalDataEraser eraser() => LocalDataEraser(
      files: const AppDeviceFiles(),
      session: SecureSessionStore(),
      marks: SecureLocalMarks(),
      notifications: LocalNotificationGateway(),
      device: const NativeLogoutHooks(ChannelNativeBridge(), SystemClock()),
      flag: logoutFlag,
      reporter: reporter,
    );

    // Cờ đăng xuất còn bật (tắt app giữa lúc xóa): xóa nốt trước (F27-E2).
    final pending = await logoutFlag.isPending();
    runApp(
      AppRoot(
        boot: boot,
        eraser: eraser,
        initial: pending ? null : await boot(afterLogout: false),
      ),
    );
  });
}
