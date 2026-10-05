import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Phiên đăng nhập lưu trên máy.
final class StoredSession {
  const StoredSession({
    required this.userId,
    required this.phone,
    this.refreshToken,
  });

  final String userId;
  final String phone;

  /// null = phiên đã hết hạn (cần đăng nhập lại), vẫn giữ [userId] để biết
  /// lần sau có phải cùng tài khoản không (05 §6.6.6).
  final String? refreshToken;
}

/// Nơi lưu phiên: refresh token chỉ nằm trong Keychain (05 §6.8.4).
abstract interface class SessionStore {
  Future<StoredSession?> read();
  Future<void> write(StoredSession session);
  Future<void> updateRefreshToken(String refreshToken);

  /// Phiên hết hạn: bỏ refresh token, giữ userId và số điện thoại.
  Future<void> expire();
}

/// Keychain của iPhone. `first_unlock_this_device`: không chép sang máy khác
/// qua bản sao lưu; app đọc được sau lần mở khóa đầu tiên kể từ khi bật máy.
final class SecureSessionStore implements SessionStore {
  SecureSessionStore([FlutterSecureStorage? storage])
    : _s =
          storage ??
          const FlutterSecureStorage(
            iOptions: IOSOptions(
              accessibility: KeychainAccessibility.first_unlock_this_device,
            ),
          );

  final FlutterSecureStorage _s;

  static const _userId = 'session.userId';
  static const _phone = 'session.phone';
  static const _refresh = 'session.refreshToken';

  @override
  Future<StoredSession?> read() async {
    final userId = await _s.read(key: _userId);
    final phone = await _s.read(key: _phone);
    if (userId == null || phone == null) return null;
    return StoredSession(
      userId: userId,
      phone: phone,
      refreshToken: await _s.read(key: _refresh),
    );
  }

  @override
  Future<void> write(StoredSession session) async {
    await _s.write(key: _userId, value: session.userId);
    await _s.write(key: _phone, value: session.phone);
    if (session.refreshToken == null) {
      await _s.delete(key: _refresh);
    } else {
      await _s.write(key: _refresh, value: session.refreshToken);
    }
  }

  @override
  Future<void> updateRefreshToken(String refreshToken) =>
      _s.write(key: _refresh, value: refreshToken);

  @override
  Future<void> expire() => _s.delete(key: _refresh);
}

/// Dùng trong test.
final class MemorySessionStore implements SessionStore {
  MemorySessionStore([this.session]);

  StoredSession? session;

  @override
  Future<StoredSession?> read() async => session;

  @override
  Future<void> write(StoredSession s) async => session = s;

  @override
  Future<void> updateRefreshToken(String refreshToken) async {
    final s = session;
    if (s != null) {
      session = StoredSession(
        userId: s.userId,
        phone: s.phone,
        refreshToken: refreshToken,
      );
    }
  }

  @override
  Future<void> expire() async {
    final s = session;
    if (s != null) session = StoredSession(userId: s.userId, phone: s.phone);
  }
}
