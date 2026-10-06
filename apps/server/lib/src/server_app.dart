import 'dart:async';
import 'dart:io';

import 'package:domain/domain.dart';

import 'package:shelf/shelf_io.dart' as shelf_io;

import 'ai/ai_cleanup.dart';
import 'ai/anthropic_provider.dart';
import 'ai/fake_ai_provider.dart';
import 'app.dart';
import 'config.dart';
import 'db/database.dart';
import 'db/migrator.dart';
import 'jobs/job_scheduler.dart';
import 'jobs/maintenance.dart';
import 'logging/logger.dart';

/// Vòng đời server: migration → mở HTTP → job định kỳ → tắt an toàn.
final class ServerApp {
  ServerApp._(this._http, this._db, this._jobs, this._logger)
    : port = _http.port;

  static Future<ServerApp> start(ServerConfig config, {Logger? logger}) async {
    final log = logger ?? Logger.stdout();
    final db = Database.open(config.databaseUrl);
    try {
      await Migrator(db.pool, Directory(config.migrationsDir), log).migrate();
    } catch (e) {
      await db.close();
      rethrow;
    }
    final jobs = JobScheduler(log);
    final deps = AppDeps(
      db: db,
      logger: log,
      clock: const SystemClock(),
      jwtSecret: config.jwtSecret,
      bcryptCost: config.bcryptCost,
      trustProxy: config.trustProxy,
      aiConfig: config.ai,
      aiProvider: config.ai.provider == 'anthropic'
          ? AnthropicProvider(
              apiKey: config.ai.apiKey!,
              model: config.ai.model,
              timeout: config.ai.timeout,
            )
          : FakeAiProvider(delay: config.ai.fakeDelay),
    );
    jobs.every(
      'login_limiter_sweep',
      const Duration(minutes: 15),
      () async => deps.limiter.sweep(),
    );
    final maintenance = Maintenance(db.pool, deps.clock);
    Future<void> cleanup() async {
      final removed = await maintenance.dailyCleanup();
      log.info('daily_cleanup', {
        'mutations': removed.mutations,
        'refreshTokens': removed.refreshTokens,
      });
    }

    jobs.every('daily_cleanup', const Duration(days: 1), cleanup);
    // 06 VS12-T08: dọn yêu cầu AI treo.
    final aiCleanup = AiCleanup(db.pool, deps.clock);
    jobs.every('ai_cleanup', const Duration(minutes: 5), () async {
      final r = await aiCleanup.run();
      if (r.requests > 0 || r.menus > 0) {
        log.info('ai_cleanup', {'requests': r.requests, 'menus': r.menus});
      }
    });
    // Chạy một lần khi khởi động để không phụ thuộc server chạy liền 24 giờ.
    unawaited(jobs.runNow('daily_cleanup', cleanup));
    final handler = buildApp(deps);
    final http = await shelf_io.serve(handler, config.host, config.port);
    http.autoCompress = false;
    log.info('server_started', {
      'host': config.host,
      'port': http.port,
      'aiProvider': config.ai.provider,
    });
    return ServerApp._(http, db, jobs, log);
  }

  final HttpServer _http;
  final Database _db;
  final JobScheduler _jobs;
  final Logger _logger;
  Future<void>? _stopping;

  /// Cổng đang lắng nghe (giữ lại cả sau khi dừng).
  final int port;

  JobScheduler get jobs => _jobs;

  /// Ngừng nhận kết nối mới, chờ request đang xử lý, dừng job, đóng database.
  Future<void> stop() => _stopping ??= () async {
    _logger.info('server_stopping');
    await _http.close();
    await _jobs.stop();
    await _db.close();
    _logger.info('server_stopped');
  }();
}
