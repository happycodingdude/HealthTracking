import 'dart:io';

import 'ai/ai_config.dart';
import 'live_activity/apns_client.dart';

final class ConfigException implements Exception {
  ConfigException(this.message);
  final String message;
  @override
  String toString() => 'ConfigException: $message';
}

/// Cấu hình server đọc từ biến môi trường (05 §6.13.2).
final class ServerConfig {
  const ServerConfig({
    required this.databaseUrl,
    required this.jwtSecret,
    this.bcryptCost = 12,
    this.host = '127.0.0.1',
    this.port = 8080,
    this.trustProxy = false,
    this.migrationsDir = 'migrations',
    this.ai = const AiConfig(),
    this.youtubeApiKey,
    this.videoCheckAt = defaultVideoCheckAt,
    this.sentryDsn,
    this.apns,
    this.liveActivityInterval = const Duration(minutes: 1),
  });

  factory ServerConfig.fromEnvironment(Map<String, String> env) {
    String require(String key) {
      final v = env[key];
      if (v == null || v.isEmpty) {
        throw ConfigException('Thiếu biến môi trường $key');
      }
      return v;
    }

    final port = int.tryParse(env['PORT'] ?? '8080');
    if (port == null || port < 0 || port > 65535) {
      throw ConfigException('PORT không hợp lệ');
    }
    final jwtSecret = require('JWT_SECRET');
    if (jwtSecret.length < 32) {
      throw ConfigException('JWT_SECRET cần tối thiểu 32 ký tự');
    }
    // TD-09: bcrypt cost 12. Chỉ hạ khi chạy integration test cho nhanh.
    final bcryptCost = int.tryParse(env['BCRYPT_COST'] ?? '12');
    if (bcryptCost == null || bcryptCost < 4 || bcryptCost > 15) {
      throw ConfigException('BCRYPT_COST không hợp lệ');
    }
    return ServerConfig(
      databaseUrl: require('DATABASE_URL'),
      jwtSecret: jwtSecret,
      bcryptCost: bcryptCost,
      host: env['HOST']?.isNotEmpty == true ? env['HOST']! : '127.0.0.1',
      port: port,
      trustProxy: env['TRUST_PROXY'] == 'true',
      migrationsDir: env['MIGRATIONS_DIR']?.isNotEmpty == true
          ? env['MIGRATIONS_DIR']!
          : 'migrations',
      ai: AiConfig.fromEnvironment(env),
      youtubeApiKey: env['YOUTUBE_API_KEY']?.isNotEmpty == true
          ? env['YOUTUBE_API_KEY']
          : null,
      videoCheckAt: parseDailyCron(
        env['VIDEO_CHECK_CRON']?.isNotEmpty == true
            ? env['VIDEO_CHECK_CRON']!
            : '30 3 * * *',
      ),
      sentryDsn: env['SENTRY_DSN']?.isNotEmpty == true
          ? env['SENTRY_DSN']
          : null,
      apns: ApnsConfig.fromEnvironment(env),
      liveActivityInterval: parseMinuteCron(
        env['LIVE_ACTIVITY_CRON']?.isNotEmpty == true
            ? env['LIVE_ACTIVITY_CRON']!
            : '* * * * *',
      ),
    );
  }

  /// `LIVE_ACTIVITY_CRON` (05 Bản 3 TD3-12): "* * * * *" (mỗi phút) hoặc
  /// "*/N * * * *" (mỗi N phút). Dạng khác → [ConfigException].
  static Duration parseMinuteCron(String cron) {
    final m = RegExp(
      r'^(\*|\*/(\d{1,2})) \* \* \* \*$',
    ).firstMatch(cron.trim());
    final n = m == null ? null : int.parse(m.group(2) ?? '1');
    if (n == null || n < 1 || n > 59) {
      throw ConfigException(
        'LIVE_ACTIVITY_CRON chỉ nhận "* * * * *" hoặc "*/N * * * *"',
      );
    }
    return Duration(minutes: n);
  }

  /// `VIDEO_CHECK_CRON` dạng "phút giờ * * *" (một lần mỗi ngày, giờ Việt
  /// Nam). Dạng khác → [ConfigException].
  static ({int hour, int minute}) parseDailyCron(String cron) {
    final m = RegExp(r'^(\d{1,2}) (\d{1,2}) \* \* \*$').firstMatch(cron.trim());
    final minute = m == null ? null : int.parse(m.group(1)!);
    final hour = m == null ? null : int.parse(m.group(2)!);
    if (minute == null || hour == null || minute > 59 || hour > 23) {
      throw ConfigException(
        'VIDEO_CHECK_CRON chỉ nhận dạng "phút giờ * * *", ví dụ "30 3 * * *"',
      );
    }
    return (hour: hour, minute: minute);
  }

  /// 03:30 giờ Việt Nam (05 Bản 2 TD2-17).
  static const defaultVideoCheckAt = (hour: 3, minute: 30);

  final String databaseUrl;
  final String jwtSecret;
  final int bcryptCost;
  final String host;
  final int port;
  final bool trustProxy;
  final String migrationsDir;

  /// AI Gateway (05 §6.9.1).
  final AiConfig ai;

  /// Khóa YouTube Data API (05 Bản 2 §6.13). Không có → job kiểm tra video
  /// không chạy (dev, CI).
  final String? youtubeApiKey;

  /// Giờ chạy job kiểm tra video mỗi ngày (giờ Việt Nam).
  final ({int hour, int minute}) videoCheckAt;

  /// Sentry của server (OPS-6); không có thì cảnh báo chỉ ghi log.
  final String? sentryDsn;

  /// APNs cho thẻ màn hình khóa; null = chưa có khóa, job thẻ không chạy
  /// (06 Bản 3 ED3-15).
  final ApnsConfig? apns;

  /// Nhịp job thẻ màn hình khóa (mặc định mỗi phút, TD3-12).
  final Duration liveActivityInterval;

  /// Biến môi trường của tiến trình, bổ sung bằng file `.env` nếu có
  /// (biến của tiến trình được ưu tiên).
  static Map<String, String> loadEnvironment({String dotEnvPath = '.env'}) {
    final file = File(dotEnvPath);
    final fromFile = file.existsSync()
        ? parseDotEnv(file.readAsStringSync())
        : <String, String>{};
    return {...fromFile, ...Platform.environment};
  }

  static Map<String, String> parseDotEnv(String content) {
    final out = <String, String>{};
    for (final raw in content.split('\n')) {
      final line = raw.trim();
      if (line.isEmpty || line.startsWith('#')) continue;
      final eq = line.indexOf('=');
      if (eq <= 0) continue;
      var value = line.substring(eq + 1).trim();
      if (value.length >= 2 &&
          ((value.startsWith('"') && value.endsWith('"')) ||
              (value.startsWith("'") && value.endsWith("'")))) {
        value = value.substring(1, value.length - 1);
      }
      out[line.substring(0, eq).trim()] = value;
    }
    return out;
  }
}

/// APNs (05 Bản 3 TD3-10, TD3-22): khóa `.p8` nằm trong `secrets/` trên server
/// (quyền 600), chỉ đường dẫn đi qua biến môi trường.
final class ApnsConfig {
  const ApnsConfig({
    required this.keyPath,
    required this.keyId,
    required this.teamId,
    required this.bundleId,
  });

  /// Đủ 4 biến → cấu hình; thiếu → null (job thẻ tắt, ED3-15).
  static ApnsConfig? fromEnvironment(Map<String, String> env) {
    String? v(String key) => env[key]?.isNotEmpty == true ? env[key] : null;
    final keyPath = v('APNS_KEY_PATH');
    final keyId = v('APNS_KEY_ID');
    final teamId = v('APNS_TEAM_ID');
    final bundleId = v('APNS_BUNDLE_ID');
    if (keyPath == null || keyId == null || teamId == null) return null;
    if (bundleId == null) return null;
    return ApnsConfig(
      keyPath: keyPath,
      keyId: keyId,
      teamId: teamId,
      bundleId: bundleId,
    );
  }

  final String keyPath;
  final String keyId;
  final String teamId;

  /// Bundle ID của app nhận thẻ: `com.happycodingdude.ironly`, bản dev
  /// `com.happycodingdude.ironly.dev`.
  final String bundleId;

  /// Đọc khóa từ file (không giữ đường dẫn trong log).
  ApnsCredentials credentials() {
    final file = File(keyPath);
    if (!file.existsSync()) {
      throw ConfigException('Không đọc được file khóa APNS_KEY_PATH');
    }
    return ApnsCredentials(
      keyPem: file.readAsStringSync(),
      keyId: keyId,
      teamId: teamId,
    );
  }
}
