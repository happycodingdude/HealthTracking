import 'package:api_contract/api_contract.dart';
import 'package:domain/domain.dart';
import 'package:postgres/postgres.dart';

import '../http/api_exception.dart';
import 'login_rate_limiter.dart';
import 'token_service.dart';

/// Đăng ký, đăng nhập, làm mới phiên (05 §6.8.4).
final class AuthService {
  AuthService({
    required Pool<void> pool,
    required TokenService tokens,
    required LoginRateLimiter limiter,
    required int bcryptCost,
  }) : _pool = pool,
       _tokens = tokens,
       _limiter = limiter,
       _cost = bcryptCost;

  final Pool<void> _pool;
  final TokenService _tokens;
  final LoginRateLimiter _limiter;
  final int _cost;

  /// Kiểm tra lại UA-19/20/21 bằng `packages/domain`; mật khẩu hash bcrypt
  /// (TD-09). Số đã có tài khoản → `phone_taken`.
  Future<TokenPair> register(RegisterRequest req) async {
    final invalid = AccountValidators.validateRegistration(
      displayName: req.displayName,
      phone: req.phone,
      password: req.password,
      passwordConfirm: req.password,
    );
    if (invalid.isNotEmpty) {
      throw ApiException(ErrorCode.validationFailed, field: invalid.first.name);
    }
    try {
      return await _pool.runTx((tx) async {
        final rows = await tx.execute(
          Sql.named('''
            INSERT INTO users (phone, password_hash, display_name)
            VALUES (@phone, crypt(@password, gen_salt('bf', @cost::int)), @name)
            RETURNING id'''),
          parameters: {
            'phone': AccountValidators.normalizePhone(req.phone),
            'password': req.password,
            'cost': _cost,
            'name': AccountValidators.normalizeDisplayName(req.displayName),
          },
        );
        return (await _tokens.issuePair(tx, rows.first[0]! as String)).pair;
      });
    } on ServerException catch (e) {
      if (e.code == '23505') {
        throw ApiException(ErrorCode.phoneTaken, field: 'phone');
      }
      rethrow;
    }
  }

  /// Sai số điện thoại hoặc mật khẩu → `invalid_credentials`, không nói ô nào
  /// sai. Đang bị chặn (TAC-15) → `too_many_attempts`.
  Future<TokenPair> login(LoginRequest req, {required String ip}) async {
    final phone = AccountValidators.normalizePhone(req.phone);
    if (_limiter.isBlocked(phone: phone, ip: ip)) {
      throw ApiException(ErrorCode.tooManyAttempts);
    }
    final rows = await _pool.execute(
      Sql.named(
        'SELECT id, password_hash = crypt(@password, password_hash) FROM users WHERE phone = @phone',
      ),
      parameters: {'phone': phone, 'password': req.password},
    );
    final ok = rows.isNotEmpty && rows.first[1] == true;
    if (rows.isEmpty) {
      // Tốn thời gian như khi số có tồn tại, để không đoán được số nào có tài khoản.
      await _pool.execute(
        Sql.named("SELECT crypt(@password, gen_salt('bf', @cost::int))"),
        parameters: {'password': req.password, 'cost': _cost},
      );
    }
    if (!ok) {
      _limiter.recordFailure(phone: phone, ip: ip);
      throw ApiException(ErrorCode.invalidCredentials);
    }
    _limiter.recordSuccess(phone: phone);
    final userId = rows.first[0]! as String;
    return _pool.runTx(
      (tx) async => (await _tokens.issuePair(tx, userId)).pair,
    );
  }

  Future<TokenPair> refresh(RefreshRequest req) =>
      _tokens.rotate(_pool, req.refreshToken);
}
