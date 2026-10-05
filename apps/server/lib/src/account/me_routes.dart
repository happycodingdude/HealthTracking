import 'package:api_contract/api_contract.dart';
import 'package:postgres/postgres.dart';
import 'package:shelf_router/shelf_router.dart';

import '../auth/auth_middleware.dart';
import '../auth/token_service.dart';
import '../http/api_exception.dart';
import '../http/json.dart';

/// `GET /v1/me`: thông tin tài khoản + `onboardingState` (OB-6).
void addMeRoutes(Router router, Pool<void> pool, TokenService tokens) {
  router.get(
    '/v1/me',
    authenticated(tokens, (request, userId) async {
      final rows = await pool.execute(
        Sql.named('SELECT phone, display_name FROM users WHERE id = @id'),
        parameters: {'id': userId},
      );
      if (rows.isEmpty) throw ApiException(ErrorCode.unauthorized);
      final row = rows.single;
      return jsonResponse(
        MeResponse(
          userId: userId,
          phone: row[0]! as String,
          displayName: row[1]! as String,
          // VS-03 suy ra từ bảng profiles; trước đó luôn chưa thiết lập.
          onboardingState: OnboardingState.notStarted,
        ).toJson(),
      );
    }),
  );
}
