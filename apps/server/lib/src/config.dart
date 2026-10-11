import 'dart:io';

import 'ai/ai_config.dart';

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
    );
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
