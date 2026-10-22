import 'package:api_contract/api_contract.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/error_reporting.dart';
import '../../../data/api/api_client.dart';
import '../../../data/auth/session_store.dart';
import '../../../data/auth/token_manager.dart';
import '../../../data/connectivity.dart';
import '../../../data/db/app_database.dart';
import '../../../data/device_files.dart';
import '../../../data/local_marks.dart';
import '../../../data/logout_flag.dart';
import '../../../data/notifications/notification_gateway.dart';
import '../../../data/sync/sync_engine.dart';
import '../../../data/sync/sync_providers.dart';

/// Các bước đăng xuất theo thứ tự (06 Bản 3 ED3-10, 05 Bản 3 §6.6.6, TD3-17).
/// Mỗi bước gọi lại được; bị cắt giữa chừng rồi chạy lại cho kết quả như chạy
/// liền (F27-E2).
enum LogoutStep {
  flushOutbox,
  revokeServer,
  setPending,
  closeDb,
  deleteSqlite,
  deleteDishImages,
  clearKeychain,
  clearAppGroup,
  endActivities,
  cancelReminders,
  reloadWidgets,
  clearPending,
}

/// Kết quả phần cần mạng của đăng xuất (bước 1–4 của §6.6.6).
enum LogoutOutcome {
  /// Đã bật `logout_pending` và giao phần xóa cho gốc app.
  done,

  /// F27-R2: không có mạng, chưa làm gì.
  offline,

  /// F27-R3: đồng bộ hoặc thu hồi phiên lỗi; dữ liệu giữ nguyên.
  syncFailed,
}

/// Phần đăng xuất của widget, App Group (VS-39) và thẻ màn hình khóa (VS-41).
abstract interface class LogoutDeviceHooks {
  /// `DELETE /v1/me/live-activity-token` (§6.6.6 bước 3).
  Future<void> deleteActivityToken();

  Future<void> clearAppGroup();

  /// Tắt mọi thẻ màn hình khóa đang hiện.
  Future<void> endActivities();

  /// `reloadAllTimelines`: widget về "Mở app để đăng nhập".
  Future<void> reloadWidgets();
}

/// Chưa có widget và thẻ (tới VS-39, VS-41).
final class NoLogoutDeviceHooks implements LogoutDeviceHooks {
  const NoLogoutDeviceHooks();

  @override
  Future<void> deleteActivityToken() async {}

  @override
  Future<void> clearAppGroup() async {}

  @override
  Future<void> endActivities() async {}

  @override
  Future<void> reloadWidgets() async {}
}

/// Gọi trước mỗi bước; test dùng để cắt giữa chừng (ED3-10).
typedef BeforeLogoutStep = void Function(LogoutStep step);

/// Bước 1–4 (§6.6.6): kiểm mạng → đồng bộ hết outbox → thu hồi phiên trên
/// server → bật `logout_pending` → giao [finish] (gốc app đóng mọi màn hình,
/// chạy [LocalDataEraser] rồi dựng lại app như lần cài mới).
final class Logout {
  Logout({
    required ConnectivityMonitor connectivity,
    required Future<SyncOutcome> Function() flush,
    required Future<void> Function(String refreshToken) revoke,
    required SessionStore session,
    required LogoutDeviceHooks device,
    required LogoutFlag flag,
    required Future<void> Function() finish,
    BeforeLogoutStep? beforeStep,
  }) : _connectivity = connectivity,
       _flush = flush,
       _revoke = revoke,
       _session = session,
       _device = device,
       _flag = flag,
       _finish = finish,
       _beforeStep = beforeStep ?? _noop;

  final ConnectivityMonitor _connectivity;
  final Future<SyncOutcome> Function() _flush;
  final Future<void> Function(String refreshToken) _revoke;
  final SessionStore _session;
  final LogoutDeviceHooks _device;
  final LogoutFlag _flag;
  final Future<void> Function() _finish;
  final BeforeLogoutStep _beforeStep;

  static void _noop(LogoutStep _) {}

  /// [onSyncing]: đã có mạng, bắt đầu đồng bộ (hộp "Đang đồng bộ…", UA3-04).
  Future<LogoutOutcome> call({void Function()? onSyncing}) async {
    if (!await _connectivity.isOnline()) return LogoutOutcome.offline;
    onSyncing?.call();
    _beforeStep(LogoutStep.flushOutbox);
    // Phiên hết hạn giữa chừng cũng không xóa gì: còn dữ liệu chưa gửi được.
    if (await _flush() != SyncOutcome.synced) return LogoutOutcome.syncFailed;
    _beforeStep(LogoutStep.revokeServer);
    try {
      await _device.deleteActivityToken();
      final refreshToken = (await _session.read())?.refreshToken;
      if (refreshToken != null) await _revoke(refreshToken);
    } on SessionExpired {
      // 401: phiên đã hết hạn = đã thu hồi, tiếp tục.
    } on ServerFailure catch (e) {
      if (e.error.code != ErrorCode.unauthorized) {
        return LogoutOutcome.syncFailed;
      }
    } on ApiFailure {
      return LogoutOutcome.syncFailed;
    }
    _beforeStep(LogoutStep.setPending);
    await _flag.set();
    await _finish();
    return LogoutOutcome.done;
  }
}

/// Bước 5–6 (TD3-17): đóng Drift → xóa file SQLite → xóa `dish_images` → xóa
/// Keychain → xóa App Group → tắt thẻ → hủy nhắc → `reloadAllTimelines` → tắt
/// `logout_pending`. Chạy ở gốc app khi mọi màn hình đã đóng, và lúc mở app nếu
/// cờ còn bật (F27-E2). Một bước lỗi thì báo lỗi, làm tiếp các bước sau và giữ
/// cờ để lần mở app sau xóa lại.
final class LocalDataEraser {
  LocalDataEraser({
    required DeviceFiles files,
    required SessionStore session,
    required LocalMarks marks,
    required NotificationGateway notifications,
    required LogoutDeviceHooks device,
    required LogoutFlag flag,
    required ErrorReporter reporter,
    BeforeLogoutStep? beforeStep,
  }) : _files = files,
       _session = session,
       _marks = marks,
       _notifications = notifications,
       _device = device,
       _flag = flag,
       _reporter = reporter,
       _beforeStep = beforeStep ?? Logout._noop;

  final DeviceFiles _files;
  final SessionStore _session;
  final LocalMarks _marks;
  final NotificationGateway _notifications;
  final LogoutDeviceHooks _device;
  final LogoutFlag _flag;
  final ErrorReporter _reporter;
  final BeforeLogoutStep _beforeStep;

  /// [db]: database đang mở (null khi mở app mà cờ còn bật: chưa mở database).
  Future<void> run(AppDatabase? db) async {
    var failed = false;
    Future<void> step(LogoutStep s, Future<void> Function() action) async {
      _beforeStep(s);
      try {
        await action();
      } on Object catch (e, st) {
        failed = true;
        await _reporter.report(e, st, reason: 'logout_${s.name}');
      }
    }

    await step(LogoutStep.closeDb, () async => db?.close());
    await step(LogoutStep.deleteSqlite, _files.deleteDatabase);
    await step(LogoutStep.deleteDishImages, _files.deleteDishImages);
    await step(LogoutStep.clearKeychain, () async {
      await _session.clear();
      await _marks.clear();
    });
    await step(LogoutStep.clearAppGroup, _device.clearAppGroup);
    await step(LogoutStep.endActivities, _device.endActivities);
    await step(LogoutStep.cancelReminders, _notifications.cancelAll);
    await step(LogoutStep.reloadWidgets, _device.reloadWidgets);
    _beforeStep(LogoutStep.clearPending);
    if (!failed) await _flag.clear();
  }
}

/// Cờ `logout_pending` (gốc app thay bằng bản dùng chung với [LocalDataEraser]).
final logoutFlagProvider = Provider<LogoutFlag>((ref) => PrefsLogoutFlag());

final logoutDeviceHooksProvider = Provider<LogoutDeviceHooks>(
  (ref) => const NoLogoutDeviceHooks(),
);

/// Gốc app (`AppRoot`) cung cấp: đóng mọi màn hình, xóa dữ liệu trên máy, dựng
/// lại app ở màn Đăng nhập (NAV-19).
final logoutFinisherProvider = Provider<Future<void> Function()>(
  (ref) => throw UnimplementedError(
    'logoutFinisherProvider must be overridden by AppRoot',
  ),
);

final logoutProvider = Provider<Logout>(
  (ref) => Logout(
    connectivity: ref.watch(connectivityProvider),
    flush: ref.watch(syncEngineProvider).flush,
    revoke: ref.watch(authRepositoryProvider).logout,
    session: ref.watch(sessionStoreProvider),
    device: ref.watch(logoutDeviceHooksProvider),
    flag: ref.watch(logoutFlagProvider),
    finish: ref.watch(logoutFinisherProvider),
  ),
);
