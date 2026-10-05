import 'dart:convert';
import 'dart:io';

import 'package:postgres/postgres.dart' show ServerException;

/// Log JSON một dòng mỗi sự kiện ra stdout (05 §6.14).
///
/// Chỉ ghi metadata. Không bao giờ ghi mật khẩu, token, số cân hay nội dung
/// hồ sơ (05 §6.12.1): nơi gọi chỉ truyền các trường an toàn.
final class Logger {
  Logger(this._sink);

  factory Logger.stdout() => Logger(stdout.writeln);

  final void Function(String line) _sink;

  void info(String event, [Map<String, Object?> fields = const {}]) =>
      _write('info', event, fields);

  void warn(String event, [Map<String, Object?> fields = const {}]) =>
      _write('warn', event, fields);

  void error(
    String event, {
    Object? error,
    StackTrace? stack,
    Map<String, Object?> fields = const {},
  }) {
    _write('error', event, {
      ...fields,
      if (error != null) ...describeError(error),
      if (stack != null) 'stack': stack.toString(),
    });
  }

  void _write(String level, String event, Map<String, Object?> fields) {
    _sink(
      jsonEncode({
        'ts': DateTime.now().toUtc().toIso8601String(),
        'level': level,
        'event': event,
        ...fields,
      }),
    );
  }

  /// Mô tả lỗi mà không lộ dữ liệu: với lỗi PostgreSQL chỉ lấy mã SQLSTATE và
  /// câu lỗi, bỏ `detail` (có thể chứa giá trị của dòng dữ liệu).
  static Map<String, Object?> describeError(Object error) {
    if (error is ServerException) {
      return {
        'errorType': 'ServerException',
        'sqlState': error.code,
        'error': error.message,
      };
    }
    return {'errorType': error.runtimeType.toString(), 'error': '$error'};
  }
}
