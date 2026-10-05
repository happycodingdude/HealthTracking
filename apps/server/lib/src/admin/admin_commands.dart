import 'dart:math';

import 'package:domain/domain.dart';
import 'package:postgres/postgres.dart';

import '../auth/token_service.dart';

final class AdminException implements Exception {
  AdminException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Lệnh quản trị trên server (TR-09, 05 §6.8.4). Không có màn hình quản trị trong app.
final class AdminCommands {
  AdminCommands(this._pool, this._tokens, {int bcryptCost = 12})
    : _cost = bcryptCost;

  final Pool<void> _pool;
  final TokenService _tokens;
  final int _cost;

  /// Bỏ các ký tự dễ nhầm (0/O, 1/l/I) để đọc mật khẩu tạm qua điện thoại.
  static const _alphabet =
      'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnpqrstuvwxyz23456789';
  static final _random = Random.secure();

  static String generateTempPassword({int length = 12}) => List.generate(
    length,
    (_) => _alphabet[_random.nextInt(_alphabet.length)],
  ).join();

  /// Đặt mật khẩu tạm cho tài khoản có số [phone], thu hồi mọi phiên của tài
  /// khoản. Trả mật khẩu tạm để in ra màn hình.
  Future<String> resetPassword(String phone) async {
    if (!AccountValidators.isValidPhone(phone)) {
      throw AdminException(
        'Số điện thoại không đúng định dạng (10 chữ số, bắt đầu bằng 0).',
      );
    }
    final temp = generateTempPassword();
    await _pool.runTx((tx) async {
      final rows = await tx.execute(
        Sql.named('''
          UPDATE users SET password_hash = crypt(@password, gen_salt('bf', @cost::int)), updated_at = now()
          WHERE phone = @phone
          RETURNING id'''),
        parameters: {
          'password': temp,
          'cost': _cost,
          'phone': AccountValidators.normalizePhone(phone),
        },
      );
      if (rows.isEmpty) {
        throw AdminException('Không có tài khoản nào dùng số $phone.');
      }
      await _tokens.revokeAll(tx, rows.first[0]! as String);
    });
    return temp;
  }
}
