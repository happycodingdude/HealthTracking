import 'dart:math';

final _random = Random.secure();

/// Token APNs giả (64 ký tự hex) sinh ngẫu nhiên mỗi lần chạy test: repo không
/// chứa giá trị token nào, kể cả giá trị giả (GIT RULES §4).
String randomApnsToken() => [
  for (var i = 0; i < 32; i++)
    _random.nextInt(256).toRadixString(16).padLeft(2, '0'),
].join();
