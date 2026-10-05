import 'package:domain/domain.dart';

/// Chặn dò mật khẩu (05 §6.8.4, TAC-15): tối đa 5 lần sai trong 15 phút theo
/// mỗi số điện thoại và theo mỗi IP; vượt thì tạm chặn 15 phút. Lưu trong bộ nhớ
/// vì chỉ có một instance server (05 §6.15).
final class LoginRateLimiter {
  LoginRateLimiter(
    this._clock, {
    this.maxFailures = 5,
    this.window = const Duration(minutes: 15),
    this.blockFor = const Duration(minutes: 15),
  });

  final Clock _clock;
  final int maxFailures;
  final Duration window;
  final Duration blockFor;
  final _entries = <String, _Entry>{};

  static String _phoneKey(String phone) => 'phone:$phone';
  static String _ipKey(String ip) => 'ip:$ip';

  /// Đang bị chặn theo số điện thoại hoặc theo IP.
  bool isBlocked({required String phone, required String ip}) {
    final now = _clock.now();
    return _blocked(_phoneKey(phone), now) || _blocked(_ipKey(ip), now);
  }

  void recordFailure({required String phone, required String ip}) {
    final now = _clock.now();
    for (final key in [_phoneKey(phone), _ipKey(ip)]) {
      final e = _entries.putIfAbsent(key, _Entry.new);
      e.failures
        ..removeWhere((t) => !t.isAfter(now.subtract(window)))
        ..add(now);
      if (e.failures.length >= maxFailures) {
        e.blockedUntil = now.add(blockFor);
        e.failures.clear();
      }
    }
  }

  /// Đăng nhập đúng: xóa đếm sai của số điện thoại. Đếm theo IP được giữ để một
  /// tài khoản hợp lệ không dùng được để "xóa" đếm khi dò tài khoản khác.
  void recordSuccess({required String phone}) =>
      _entries.remove(_phoneKey(phone));

  /// Dọn các mục đã hết hạn (gọi định kỳ).
  void sweep() {
    final now = _clock.now();
    _entries.removeWhere(
      (_, e) =>
          (e.blockedUntil == null || !e.blockedUntil!.isAfter(now)) &&
          e.failures.every((t) => !t.isAfter(now.subtract(window))),
    );
  }

  int get trackedKeys => _entries.length;

  bool _blocked(String key, DateTime now) {
    final until = _entries[key]?.blockedUntil;
    return until != null && until.isAfter(now);
  }
}

final class _Entry {
  final failures = <DateTime>[];
  DateTime? blockedUntil;
}
