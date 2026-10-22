import 'dart:io';

import 'package:args/args.dart';
import 'package:domain/domain.dart';
import 'package:server/server.dart';
import 'package:server/src/admin/admin_commands.dart';
import 'package:server/src/auth/token_service.dart';

/// Admin CLI (TR-09). Xem docs/runbook.md.
///
///   admin migrate
///   admin reset-password --phone 0901234567
///   admin budget --show
///   admin library import data/v3__exercises.json [--check-only]
///   admin library purge --dry-run | --apply --confirm-count=N
///   admin library check-videos
Future<void> main(List<String> args) async {
  final parser = ArgParser()
    ..addCommand('migrate')
    ..addCommand(
      'reset-password',
      ArgParser()..addOption('phone', mandatory: true),
    )
    ..addCommand('budget', ArgParser()..addFlag('show', defaultsTo: true))
    ..addCommand(
      'library',
      ArgParser()
        ..addCommand(
          'import',
          ArgParser()..addFlag('check-only', negatable: false),
        )
        ..addCommand(
          'purge',
          ArgParser()
            ..addFlag('dry-run', negatable: false)
            ..addFlag('apply', negatable: false)
            ..addOption('confirm-count'),
        )
        ..addCommand('check-videos'),
    );
  final ArgResults parsed;
  try {
    parsed = parser.parse(args);
    if (parsed.command == null) throw const FormatException('Thiếu lệnh');
    final library = parsed.command!.name == 'library'
        ? parsed.command!.command
        : null;
    if (parsed.command!.name == 'library' &&
        (library == null ||
            library.rest.length != (library.name == 'import' ? 1 : 0))) {
      throw const FormatException('Thiếu lệnh con hoặc đường dẫn file');
    }
    if (library?.name == 'purge' &&
        (library!.flag('dry-run') == library.flag('apply') ||
            (library.flag('apply') &&
                int.tryParse(library.option('confirm-count') ?? '') == null))) {
      throw const FormatException(
        'library purge: chọn --dry-run, hoặc --apply kèm --confirm-count',
      );
    }
  } on FormatException catch (e) {
    stderr
      ..writeln(e.message)
      ..writeln('Dùng: admin migrate')
      ..writeln('      admin reset-password --phone <số điện thoại>')
      ..writeln('      admin budget --show')
      ..writeln(
        '      admin library import <file thư viện .json> [--check-only]',
      )
      ..writeln(
        '      admin library purge --dry-run | --apply --confirm-count=<tổng>',
      )
      ..writeln('      admin library check-videos');
    exitCode = 64;
    return;
  }

  final config = ServerConfig.fromEnvironment(ServerConfig.loadEnvironment());
  final db = Database.open(config.databaseUrl);
  try {
    final admin = AdminCommands(
      db.pool,
      TokenService(secret: config.jwtSecret, clock: const SystemClock()),
      bcryptCost: config.bcryptCost,
    );
    switch (parsed.command!.name) {
      case 'migrate':
        // Như lúc server khởi động (05 Bản 3 TR3-05); dùng cho database dev
        // và test (tool/reset_dev_db.sh, tool/integration_test.sh).
        final applied = await Migrator(
          db.pool,
          Directory(config.migrationsDir),
          Logger.stdout(),
        ).migrate();
        stdout.writeln(
          applied.isEmpty
              ? 'Không có migration mới.'
              : 'Đã chạy: ${applied.join(', ')}',
        );
      case 'reset-password':
        final phone = parsed.command!.option('phone')!;
        final temp = await admin.resetPassword(phone);
        stdout
          ..writeln('Mật khẩu tạm của $phone: $temp')
          ..writeln('Đã thu hồi mọi phiên đăng nhập của tài khoản này.')
          ..writeln('Báo mật khẩu tạm cho chủ tài khoản qua kênh riêng.');
      case 'library' when parsed.command!.command!.name == 'check-videos':
        // 05 Bản 2 §6.10.3: cùng logic với job hằng ngày.
        final key = config.youtubeApiKey;
        if (key == null) {
          stderr.writeln('Thiếu YOUTUBE_API_KEY trong .env của server.');
          exitCode = 1;
          return;
        }
        final log = Logger.stdout();
        final dsn = config.sentryDsn;
        if (dsn != null) await SentryAlerts.init(dsn);
        final result = await VideoCheckJob(
          db: db.pool,
          api: YouTubeDataApiClient(apiKey: key),
          alerts: dsn == null ? LogAlerts(log) : SentryAlerts(log),
          logger: log,
        ).run();
        (result.failed ? stderr : stdout).writeln(result.describe());
        if (result.failed) exitCode = 1;
      case 'library' when parsed.command!.command!.name == 'purge':
        // 05 Bản 3 §6.11: --dry-run in bảng để gửi Bạn; --apply chỉ sau khi
        // Bạn trả lời "Đồng ý", với tổng của bảng đó (TA3-07).
        final cmd = parsed.command!.command!;
        final purge = LibraryPurge(db.pool, const SystemClock());
        if (cmd.flag('dry-run')) {
          final report = await purge.dryRun();
          stdout
            ..writeln(report.table())
            ..writeln()
            ..writeln(_purgeSummary(report, done: false));
          return;
        }
        try {
          final report = await purge.apply(
            confirmCount: int.parse(cmd.option('confirm-count')!),
          );
          stdout.writeln(
            report.nothingToDo
                ? 'Không có gì để xóa.'
                : '${report.table()}\n\n${_purgeSummary(report, done: true)}',
          );
        } on PurgeRefused catch (e) {
          stderr.writeln(e.message);
          exitCode = 1;
        }
      case 'library':
        // 05 Bản 2 §6.10.2. File không đọc được → in lỗi, mã thoát 1.
        final cmd = parsed.command!.command!;
        final LibraryFile file;
        try {
          file = LibraryFile.parse(File(cmd.rest.single).readAsStringSync());
        } on LibraryFileException catch (e) {
          stderr
            ..writeln('File thư viện sai lược đồ:')
            ..writeln(e.issues.map((i) => '  - $i').join('\n'));
          exitCode = 1;
          return;
        }
        final report = await LibraryImporter(
          db.pool,
        ).run(file, checkOnly: cmd.flag('check-only'));
        (report.ok ? stdout : stderr).writeln(report.describe());
        if (!report.ok) exitCode = 1;
      case 'budget':
        stdout.write(
          await admin.budgetReport(
            DateTime.now().toUtc(),
            capVnd: config.ai.capVnd,
          ),
        );
    }
  } on AdminException catch (e) {
    stderr.writeln(e.message);
    exitCode = 1;
  } finally {
    await db.close();
  }
}

String _purgeSummary(PurgeReport r, {required bool done}) => [
  done
      ? 'Đã xóa ${r.total} bản ghi (${r.liftLogs} mức tạ, ${r.notes} ghi chú); '
            '${r.exercisesLeft} bài bỏ rời thư viện.'
      : 'Sẽ xóa ${r.total} bản ghi (${r.liftLogs} mức tạ, ${r.notes} ghi '
            'chú); ${r.exercisesLeft}/14 bài bỏ còn trong thư viện. Chưa đổi '
            'gì.',
  '${done ? 'Đơn vị đã tạo' : 'Đơn vị sẽ tạo'} cho bài giữ đã ghi: '
      '${r.stepsUnits} nấc máy, ${r.kgUnits} kg.',
  if (!done) 'Áp dụng: admin library purge --apply --confirm-count=${r.total}',
].join('\n');
