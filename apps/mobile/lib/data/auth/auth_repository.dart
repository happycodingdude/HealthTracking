import 'package:api_contract/api_contract.dart';

import '../api/api_client.dart';
import 'session_store.dart';
import 'token_manager.dart';

/// Đăng ký, đăng nhập, đọc tài khoản (F-09, S-01a, S-01b). Cần mạng (UA-16).
final class AuthRepository {
  AuthRepository({
    required ApiClient api,
    required TokenManager tokens,
    required SessionStore store,
  }) : _api = api,
       _tokens = tokens,
       _store = store;

  final ApiClient _api;
  final TokenManager _tokens;
  final SessionStore _store;

  Future<MeResponse> register(RegisterRequest request) async => _signedIn(
    TokenPair.fromJson(
      await _api.postJson('/v1/auth/register', request.toJson(), auth: false),
    ),
  );

  Future<MeResponse> login(LoginRequest request) async => _signedIn(
    TokenPair.fromJson(
      await _api.postJson('/v1/auth/login', request.toJson(), auth: false),
    ),
  );

  Future<MeResponse> fetchMe() async =>
      MeResponse.fromJson(await _api.getJson('/v1/me'));

  /// Đăng xuất (05 Bản 3 §6.6.6 bước 3): server thu hồi chuỗi của
  /// [refreshToken] và xóa token thẻ màn hình khóa (TD3-18).
  Future<void> logout(String refreshToken) => _api.postJson(
    '/v1/auth/logout',
    LogoutRequest(refreshToken: refreshToken).toJson(),
  );

  /// Gọi `POST /v1/auth/refresh` (dùng cho [TokenManager]).
  static Future<TokenPair> refreshWith(
    ApiClient api,
    String refreshToken,
  ) async => TokenPair.fromJson(
    await api.postJson(
      '/v1/auth/refresh',
      RefreshRequest(refreshToken: refreshToken).toJson(),
      auth: false,
    ),
  );

  Future<MeResponse> _signedIn(TokenPair pair) async {
    _tokens.setPair(pair);
    final me = await fetchMe();
    await _store.write(
      StoredSession(
        userId: me.userId,
        phone: me.phone,
        refreshToken: pair.refreshToken,
      ),
    );
    return me;
  }
}
