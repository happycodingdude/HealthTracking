import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:api_contract/api_contract.dart';
import 'package:crypto/crypto.dart';
import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import 'package:domain/domain.dart';
import 'package:postgres/postgres.dart';

import '../http/api_exception.dart';

/// Token đăng nhập (TD-10, 05 §6.8.4):
/// - Access: JWT HS256 chứa `sub` (user id), 15 phút.
/// - Refresh: 32 byte ngẫu nhiên, server chỉ lưu SHA-256; 180 ngày, gia hạn mỗi
///   lần dùng (TA-10); xoay vòng; dùng lại token đã thu hồi → thu hồi cả chuỗi.
final class TokenService {
  TokenService({
    required String secret,
    required Clock clock,
    this.accessTtl = const Duration(minutes: 15),
    this.refreshTtl = const Duration(days: 180),
  }) : _key = SecretKey(secret),
       _clock = clock {
    if (secret.length < 32) {
      throw ArgumentError('JWT_SECRET cần tối thiểu 32 ký tự');
    }
  }

  final SecretKey _key;
  final Clock _clock;
  final Duration accessTtl;
  final Duration refreshTtl;
  static final _random = Random.secure();

  DateTime _now() => _clock.now().toUtc();

  /// Ký access token cho [userId]. Trả token và thời điểm hết hạn.
  ({String token, DateTime expiresAt}) issueAccessToken(String userId) {
    final now = _now();
    final expiresAt = now.add(accessTtl);
    final token = JWT({
      'sub': userId,
      'iat': now.millisecondsSinceEpoch ~/ 1000,
      'exp': expiresAt.millisecondsSinceEpoch ~/ 1000,
    }).sign(_key, algorithm: JWTAlgorithm.HS256, noIssueAt: true);
    return (token: token, expiresAt: expiresAt);
  }

  /// Trả user id nếu access token hợp lệ và chưa hết hạn, ngược lại null.
  String? verifyAccessToken(String token) {
    try {
      final jwt = JWT.verify(
        token,
        _key,
        checkExpiresIn: false,
        checkNotBefore: false,
      );
      if (jwt.header?['alg'] != 'HS256') return null;
      final payload = jwt.payload;
      if (payload is! Map) return null;
      final sub = payload['sub'];
      final exp = payload['exp'];
      if (sub is! String || exp is! int) return null;
      if (_now().millisecondsSinceEpoch ~/ 1000 >= exp) return null;
      return sub;
    } on JWTException {
      return null;
    } on FormatException {
      return null;
    }
  }

  static String newRefreshToken() {
    final bytes = Uint8List.fromList(
      List.generate(32, (_) => _random.nextInt(256)),
    );
    return base64Url.encode(bytes).replaceAll('=', '');
  }

  static Uint8List hashRefreshToken(String token) =>
      Uint8List.fromList(sha256.convert(utf8.encode(token)).bytes);

  /// Cấp cặp token mới; refresh token mới thuộc chuỗi [familyId] (mới nếu null).
  Future<({TokenPair pair, String refreshId})> issuePair(
    Session tx,
    String userId, {
    String? familyId,
  }) async {
    final access = issueAccessToken(userId);
    final refresh = newRefreshToken();
    final rows = await tx.execute(
      Sql.named('''
        INSERT INTO refresh_tokens (user_id, token_hash, family_id, expires_at, created_at)
        VALUES (@user, @hash:bytea, COALESCE(@family::uuid, gen_random_uuid()), @expires, @now)
        RETURNING id'''),
      parameters: {
        'user': userId,
        'hash': hashRefreshToken(refresh),
        'family': familyId,
        'expires': _now().add(refreshTtl),
        'now': _now(),
      },
    );
    return (
      pair: TokenPair(
        accessToken: access.token,
        refreshToken: refresh,
        accessTokenExpiresAt: access.expiresAt,
      ),
      refreshId: rows.first[0]! as String,
    );
  }

  /// Đổi refresh token lấy cặp mới (xoay vòng). Sai, hết hạn hoặc đã thu hồi →
  /// `unauthorized`; nếu token đã thu hồi được dùng lại thì thu hồi cả chuỗi.
  Future<TokenPair> rotate(Pool<void> pool, String refreshToken) async {
    final result = await pool.runTx<TokenPair?>((tx) async {
      final rows = await tx.execute(
        Sql.named('''
          SELECT t.id, t.user_id, t.family_id, t.expires_at, t.revoked_at
          FROM refresh_tokens t
          WHERE t.token_hash = @hash:bytea
          FOR UPDATE'''),
        parameters: {'hash': hashRefreshToken(refreshToken)},
      );
      if (rows.isEmpty) return null;
      final row = rows.first.toColumnMap();
      final now = _now();
      if (row['revoked_at'] != null) {
        await tx.execute(
          Sql.named(
            'UPDATE refresh_tokens SET revoked_at = @now WHERE family_id = @family AND revoked_at IS NULL',
          ),
          parameters: {'now': now, 'family': row['family_id']},
        );
        return null;
      }
      if (!(row['expires_at']! as DateTime).isAfter(now)) return null;
      final issued = await issuePair(
        tx,
        row['user_id']! as String,
        familyId: row['family_id']! as String,
      );
      await tx.execute(
        Sql.named(
          'UPDATE refresh_tokens SET revoked_at = @now, replaced_by = @next WHERE id = @id',
        ),
        parameters: {'now': now, 'next': issued.refreshId, 'id': row['id']},
      );
      return issued.pair;
    });
    if (result == null) throw ApiException(ErrorCode.unauthorized);
    return result;
  }

  /// Đăng xuất (05 Bản 3 TD3-18): thu hồi cả chuỗi của [refreshToken] nếu
  /// token thuộc [userId]. Token lạ, của tài khoản khác hoặc chuỗi đã thu hồi
  /// → không đổi gì (gọi lại được). Chuỗi khác của cùng tài khoản (máy khác)
  /// giữ nguyên (TA3-09).
  Future<void> revokeFamily(Session tx, String userId, String refreshToken) =>
      tx.execute(
        Sql.named('''
          UPDATE refresh_tokens SET revoked_at = @now
          WHERE revoked_at IS NULL AND family_id = (
            SELECT family_id FROM refresh_tokens
            WHERE token_hash = @hash:bytea AND user_id = @user)'''),
        parameters: {
          'now': _now(),
          'hash': hashRefreshToken(refreshToken),
          'user': userId,
        },
      );

  /// Thu hồi mọi phiên của tài khoản (admin đặt lại mật khẩu, VS01-T07).
  Future<void> revokeAll(Session tx, String userId) => tx.execute(
    Sql.named(
      'UPDATE refresh_tokens SET revoked_at = @now WHERE user_id = @user AND revoked_at IS NULL',
    ),
    parameters: {'now': _now(), 'user': userId},
  );
}
