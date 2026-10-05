import 'dart:io';

import 'package:args/args.dart';
import 'package:domain/domain.dart';
import 'package:server/server.dart';
import 'package:server/src/admin/admin_commands.dart';
import 'package:server/src/auth/token_service.dart';

/// Admin CLI (TR-09). Xem docs/runbook.md.
///
///   admin reset-password --phone 0901234567
Future<void> main(List<String> args) async {
  final parser = ArgParser()
    ..addCommand(
      'reset-password',
      ArgParser()..addOption('phone', mandatory: true),
    );
  final ArgResults parsed;
  try {
    parsed = parser.parse(args);
    if (parsed.command == null) throw const FormatException('Thiếu lệnh');
  } on FormatException catch (e) {
    stderr
      ..writeln(e.message)
      ..writeln('Dùng: admin reset-password --phone <số điện thoại>');
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
    }
  } on AdminException catch (e) {
    stderr.writeln(e.message);
    exitCode = 1;
  } finally {
    await db.close();
  }
}
