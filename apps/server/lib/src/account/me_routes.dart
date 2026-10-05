import 'package:api_contract/api_contract.dart';
import 'package:postgres/postgres.dart';
import 'package:shelf_router/shelf_router.dart';

import '../auth/auth_middleware.dart';
import '../auth/token_service.dart';
import '../http/api_exception.dart';
import '../http/json.dart';

/// `GET /v1/me`: thông tin tài khoản + `onboardingState` suy ra từ `profiles`
/// (OB-6, 06 VS03-T05).
void addMeRoutes(Router router, Pool<void> pool, TokenService tokens) {
  router.get(
    '/v1/me',
    authenticated(tokens, (request, userId) async {
      final rows = await pool.execute(
        Sql.named('''
          SELECT u.phone, u.display_name, p.onboarding_step, p.onboarding_completed_at
          FROM users u LEFT JOIN profiles p ON p.user_id = u.id AND NOT p.deleted
          WHERE u.id = @id'''),
        parameters: {'id': userId},
      );
      if (rows.isEmpty) throw ApiException(ErrorCode.unauthorized);
      final row = rows.single;
      final step = row[2] as int?;
      // Chưa có hồ sơ = chưa bấm "Tôi đã hiểu" ở bước 1.
      final state = step == null
          ? OnboardingState.notStarted
          : row[3] == null
          ? OnboardingState.inProgress
          : OnboardingState.completed;
      return jsonResponse(
        MeResponse(
          userId: userId,
          phone: row[0]! as String,
          displayName: row[1]! as String,
          onboardingState: state,
          onboardingStep: state == OnboardingState.inProgress ? step : null,
        ).toJson(),
      );
    }),
  );
}
