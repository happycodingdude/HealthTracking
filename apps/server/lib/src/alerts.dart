import 'package:sentry/sentry.dart';

import 'logging/logger.dart';

/// Cảnh báo vận hành gửi tới Bạn (05 Bản 2 TD2-17, §6.15: sự kiện Sentry mức
/// cảnh báo → Bạn nhận email). Chỉ chứa mã kỹ thuật (mã bài, mã video, lý
/// do), không có dữ liệu cá nhân (05 §6.12.1).
abstract interface class Alerts {
  Future<void> warning(String message, Map<String, String> tags);
}

/// Gửi qua Sentry (khi có `SENTRY_DSN`), đồng thời ghi log.
final class SentryAlerts implements Alerts {
  SentryAlerts(this._log);

  final Logger _log;

  /// Bật Sentry cho server với [dsn] (gọi một lần lúc khởi động).
  static Future<void> init(String dsn) => Sentry.init((o) {
    o.dsn = dsn;
    o.sendDefaultPii = false;
  });

  @override
  Future<void> warning(String message, Map<String, String> tags) async {
    _log.warn('alert', {'message': message, ...tags});
    await Sentry.captureMessage(
      message,
      level: SentryLevel.warning,
      withScope: (scope) {
        for (final t in tags.entries) {
          scope.setTag(t.key, t.value);
        }
      },
    );
  }
}

/// Chưa cấu hình Sentry (dev, test): chỉ ghi log.
final class LogAlerts implements Alerts {
  LogAlerts(this._log);

  final Logger _log;

  @override
  Future<void> warning(String message, Map<String, String> tags) async =>
      _log.warn('alert', {'message': message, ...tags});
}
