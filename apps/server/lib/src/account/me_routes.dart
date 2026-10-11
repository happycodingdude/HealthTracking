import 'package:api_contract/api_contract.dart';
import 'package:postgres/postgres.dart';
import 'package:shelf_router/shelf_router.dart';

import '../auth/auth_middleware.dart';
import '../auth/token_service.dart';
import '../http/api_exception.dart';
import '../http/json.dart';
import '../http/request_info.dart';

/// `GET /v1/me`: thông tin tài khoản + `onboardingState` suy ra từ `profiles`
/// (OB-6, 06 VS03-T05).
///
/// Bản 2 (05 Bản 2 §6.6.6, TD2-04): tài khoản đã hoàn tất thiết lập nhưng chưa
/// có lịch tuần ("Để sau") mà request không có `X-App-Version` ≥ 2.0.0 (app
/// Bản 1, không biết "Để sau") → trả "đang thiết lập, bước 4" để app đó hiện
/// bước lịch tuần.
void addMeRoutes(Router router, Pool<void> pool, TokenService tokens) {
  router.get(
    '/v1/me',
    authenticated(tokens, (request, userId) async {
      final rows = await pool.execute(
        Sql.named('''
          SELECT u.phone, u.display_name, p.onboarding_step, p.onboarding_completed_at,
                 EXISTS (SELECT 1 FROM weekly_templates w
                         WHERE w.user_id = u.id AND NOT w.deleted) AS has_schedule
          FROM users u LEFT JOIN profiles p ON p.user_id = u.id AND NOT p.deleted
          WHERE u.id = @id'''),
        parameters: {'id': userId},
      );
      if (rows.isEmpty) throw ApiException(ErrorCode.unauthorized);
      final row = rows.single;
      var step = row[2] as int?;
      // Chưa có hồ sơ = chưa bấm "Tôi đã hiểu" ở bước 1.
      var state = step == null
          ? OnboardingState.notStarted
          : row[3] == null
          ? OnboardingState.inProgress
          : OnboardingState.completed;
      final version = request.info.appVersion;
      if (state == OnboardingState.completed &&
          row[4] == false &&
          (version == null || version < AppVersion.v2)) {
        state = OnboardingState.inProgress;
        step = 4;
      }
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
