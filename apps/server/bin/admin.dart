import 'dart:io';

import 'package:args/args.dart';
import 'package:domain/domain.dart';
import 'package:server/server.dart';
import 'package:server/src/admin/admin_commands.dart';
import 'package:server/src/auth/token_service.dart';

/// Admin CLI (TR-09). Xem docs/runbook.md.
///
///   admin reset-password --phone 0901234567
///   admin budget --show
///   admin library import data/v2__exercises.json [--check-only]
Future<void> main(List<String> args) async {
  final parser = ArgParser()
    ..addCommand(
      'reset-password',
      ArgParser()..addOption('phone', mandatory: true),
    )
    ..addCommand('budget', ArgParser()..addFlag('show', defaultsTo: true))
    ..addCommand(
      'library',
      ArgParser()..addCommand(
        'import',
        ArgParser()..addFlag('check-only', negatable: false),
      ),
    );
  final ArgResults parsed;
  try {
    parsed = parser.parse(args);
    if (parsed.command == null) throw const FormatException('Thiếu lệnh');
    final library = parsed.command!.name == 'library'
        ? parsed.command!.command
        : null;
    if (parsed.command!.name == 'library' &&
        (library == null || library.rest.length != 1)) {
      throw const FormatException('Thiếu lệnh con hoặc đường dẫn file');
    }
  } on FormatException catch (e) {
    stderr
      ..writeln(e.message)
      ..writeln('Dùng: admin reset-password --phone <số điện thoại>')
      ..writeln('      admin budget --show')
      ..writeln(
        '      admin library import <file thư viện .json> [--check-only]',
      );
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
      case 'reset-password':
        final phone = parsed.command!.option('phone')!;
        final temp = await admin.resetPassword(phone);
        stdout
          ..writeln('Mật khẩu tạm của $phone: $temp')
          ..writeln('Đã thu hồi mọi phiên đăng nhập của tài khoản này.')
          ..writeln('Báo mật khẩu tạm cho chủ tài khoản qua kênh riêng.');
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
