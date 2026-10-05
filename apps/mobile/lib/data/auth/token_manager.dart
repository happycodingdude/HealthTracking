import 'dart:async';

import 'package:api_contract/api_contract.dart';
import 'package:domain/domain.dart';

import '../api/api_client.dart';
import 'session_store.dart';

/// Phiên hết hạn: refresh token bị server từ chối. App về S-01b, giữ dữ liệu
/// trên máy (TA-10, 05 §6.6.6).
final class SessionExpired implements Exception {
  const SessionExpired();
}

/// Giữ access token trong bộ nhớ, refresh token trong [SessionStore] (05 §6.8.4).
/// Làm mới token **một lần duy nhất** khi nhiều request cùng cần (VS01-T08).
final class TokenManager {
  TokenManager({
    required SessionStore store,
    required Clock clock,
    required Future<TokenPair> Function(String refreshToken) refreshCall,
  }) : _store = store,
       _clock = clock,
       _refreshCall = refreshCall;

  final SessionStore _store;
  final Clock _clock;
  final Future<TokenPair> Function(String refreshToken) _refreshCall;
  final _expired = StreamController<void>.broadcast();

  String? _accessToken;
  DateTime? _accessExpiresAt;
  String? _refreshToken;
  bool _loaded = false;
  Future<String>? _refreshing;

  /// Phát khi phiên hết hạn.
  Stream<void> get onExpired => _expired.stream;

  String? get currentAccessToken => _accessToken;

  /// Ghi nhận cặp token vừa nhận khi đăng ký/đăng nhập.
  void setPair(TokenPair pair) {
    _accessToken = pair.accessToken;
    _accessExpiresAt = pair.accessTokenExpiresAt;
    _refreshToken = pair.refreshToken;
    _loaded = true;
  }

  /// Access token còn hạn ít nhất 30 giây; nếu không thì làm mới.
  Future<String> validAccessToken() async {
    final token = _accessToken;
    final expiresAt = _accessExpiresAt;
    if (token != null &&
        expiresAt != null &&
        _clock
            .now()
            .toUtc()
            .add(const Duration(seconds: 30))
            .isBefore(expiresAt)) {
      return token;
    }
    return refresh(failedToken: token);
  }

  /// Làm mới token. [failedToken] là token vừa bị 401: nếu đã có token khác
  /// (một request khác vừa làm mới xong) thì dùng luôn, không gọi server.
  Future<String> refresh({String? failedToken}) {
    final current = _accessToken;
    if (current != null && failedToken != null && current != failedToken) {
      return Future.value(current);
    }
    return _refreshing ??= _doRefresh().whenComplete(() => _refreshing = null);
  }

  Future<String> _doRefresh() async {
    if (!_loaded) {
      _refreshToken = (await _store.read())?.refreshToken;
      _loaded = true;
    }
    final refreshToken = _refreshToken;
    if (refreshToken == null) throw const SessionExpired();
    final TokenPair pair;
    try {
      pair = await _refreshCall(refreshToken);
    } on ServerFailure catch (e) {
      if (e.error.code == ErrorCode.unauthorized) {
        await _expire();
        throw const SessionExpired();
      }
      rethrow;
    }
    // Lưu refresh token mới trước khi dùng, để tắt app giữa chừng vẫn còn phiên.
    await _store.updateRefreshToken(pair.refreshToken);
    setPair(pair);
    return pair.accessToken;
  }

  Future<void> _expire() async {
    _accessToken = null;
    _accessExpiresAt = null;
    _refreshToken = null;
    await _store.expire();
    _expired.add(null);
  }

  Future<void> dispose() => _expired.close();
}
