import 'package:api_contract/api_contract.dart';
import 'package:shelf/shelf.dart';

import '../http/api_exception.dart';
import '../http/request_info.dart';
import 'token_service.dart';

/// Handler cần đăng nhập: nhận `userId` lấy **chỉ** từ access token (05 §6.8.4).
typedef AuthedHandler =
    Future<Response> Function(Request request, String userId);

/// Bọc [handler]: kiểm `Authorization: Bearer <access token>`, sai → 401
/// `unauthorized` (app tự làm mới token). Đặt `userId` vào log của request.
Handler authenticated(TokenService tokens, AuthedHandler handler) {
  return (request) async {
    final header = request.headers['authorization'];
    const prefix = 'Bearer ';
    final userId = header != null && header.startsWith(prefix)
        ? tokens.verifyAccessToken(header.substring(prefix.length).trim())
        : null;
    if (userId == null) throw ApiException(ErrorCode.unauthorized);
    request.info.userId = userId;
    return handler(request, userId);
  };
}
