import 'dart:async';
import 'dart:io';

import 'package:domain/domain.dart';

import 'package:shelf/shelf_io.dart' as shelf_io;

import 'app.dart';
import 'config.dart';
import 'db/database.dart';
import 'db/migrator.dart';
import 'jobs/job_scheduler.dart';
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
    );
    jobs.every(
      'login_limiter_sweep',
      const Duration(minutes: 15),
      () async => deps.limiter.sweep(),
    );
    final handler = buildApp(deps);
    final http = await shelf_io.serve(handler, config.host, config.port);
    http.autoCompress = false;
    log.info('server_started', {'host': config.host, 'port': http.port});
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
