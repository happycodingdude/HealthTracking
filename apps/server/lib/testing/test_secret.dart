import 'dart:convert';
import 'dart:math';

final _random = Random.secure();

/// Khóa ngẫu nhiên cho mỗi lần chạy test (khóa ký JWT, khóa API giả): code
/// không chứa giá trị khóa, kể cả khóa giả. Mặc định 43 ký tự (≥ 32, đủ cho
/// `JWT_SECRET`).
String randomTestSecret([int bytes = 32]) => base64Url
    .encode(List.generate(bytes, (_) => _random.nextInt(256)))
    .replaceAll('=', '');
