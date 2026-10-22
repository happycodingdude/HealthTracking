import 'package:api_contract/api_contract.dart';
import 'package:postgres/postgres.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import '../http/json.dart';
import 'auth_middleware.dart';
import 'token_service.dart';

/// `POST /v1/auth/logout` (05 Bản 3 §6.12, TD3-18, TA3-09): thu hồi chuỗi
/// refresh token của phiên gọi và xóa token thẻ màn hình khóa của tài khoản,
/// trong một transaction; 204 kể cả khi đã thu hồi trước đó. Cần access token:
/// một tài khoản không thu hồi được phiên của tài khoản khác.
void addLogoutRoute(Router router, Pool<void> pool, TokenService tokens) {
  router.post(
    '/v1/auth/logout',
    authenticated(tokens, (request, userId) async {
      final req = await readDto(request, LogoutRequest.fromJson);
      await pool.runTx<void>((tx) async {
        await tokens.revokeFamily(tx, userId, req.refreshToken);
        await tx.execute(
          Sql.named('DELETE FROM live_activity_tokens WHERE user_id = @user'),
          parameters: {'user': userId},
        );
      });
      return Response(204);
    }),
  );
}
