import 'dart:convert';
import 'dart:math';

import '../account/account_validators.dart';

final _random = Random.secure();

/// Khóa hoặc token ngẫu nhiên cho mỗi lần chạy test (khóa ký JWT, khóa API,
/// access/refresh token giả): code không chứa giá trị credential, kể cả giá
/// trị giả. Mặc định 43 ký tự (≥ 32, đủ cho `JWT_SECRET`).
String randomTestSecret([int bytes = 32]) => base64Url
    .encode(List.generate(bytes, (_) => _random.nextInt(256)))
    .replaceAll('=', '');

const _passwordChars = 'abcdefghijkmnopqrstuvwxyz23456789';
const _vietnameseChars = 'ăâđêôơưàảãáạằẳẵắặầẩẫấậèẻẽéẹềểễếệìỉĩíịòỏõóọồổỗốộ';

/// Mật khẩu tài khoản thử ngẫu nhiên, đúng [length] ký tự (mặc định 10, hợp lệ
/// vì ≥ [AccountValidators.passwordMin]); [vietnamese]: chỉ gồm chữ có dấu.
String randomTestPassword({int length = 10, bool vietnamese = false}) {
  final chars = vietnamese ? _vietnameseChars : _passwordChars;
  return String.fromCharCodes(
    List.generate(
      length,
      (_) => chars.codeUnitAt(_random.nextInt(chars.length)),
    ),
  );
}
