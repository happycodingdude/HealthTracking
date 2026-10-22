import 'package:api_contract/api_contract.dart';
import 'package:postgres/postgres.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import '../auth/auth_middleware.dart';
import '../auth/token_service.dart';
import '../http/json.dart';

/// `PUT` / `DELETE /v1/me/live-activity-token` (05 Bản 3 §6.12, TD3-11): token
/// thẻ màn hình khóa là dữ liệu thiết bị, không qua sync; mỗi tài khoản chỉ giữ
/// bản mới nhất (TA3-12). Chỉ đụng dòng của tài khoản gọi (TAC3-13).
void addLiveActivityTokenRoutes(
  Router router,
  Pool<void> pool,
  TokenService tokens,
) {
  router
    ..put(
      '/v1/me/live-activity-token',
      authenticated(tokens, (request, userId) async {
        final req = await readDto(request, LiveActivityTokenRequest.fromJson);
        await pool.execute(
          Sql.named('''
            INSERT INTO live_activity_tokens (user_id, push_to_start_token,
              activity_push_token, activity_date, environment, app_version,
              updated_at)
            VALUES (@user, @start, @update, @date::date, @env, @version, now())
            ON CONFLICT (user_id) DO UPDATE SET
              push_to_start_token = EXCLUDED.push_to_start_token,
              activity_push_token = EXCLUDED.activity_push_token,
              activity_date = EXCLUDED.activity_date,
              environment = EXCLUDED.environment,
              app_version = EXCLUDED.app_version,
              updated_at = now()'''),
          parameters: {
            'user': userId,
            'start': req.pushToStartToken,
            'update': req.activityPushToken,
            'date': req.activityDate == null
                ? null
                : DateCodec.encode(req.activityDate!),
            'env': req.environment.name,
            'version': req.appVersion,
          },
        );
        return Response(204);
      }),
    )
    ..delete(
      '/v1/me/live-activity-token',
      authenticated(tokens, (request, userId) async {
        await pool.execute(
          Sql.named('DELETE FROM live_activity_tokens WHERE user_id = @user'),
          parameters: {'user': userId},
        );
        return Response(204);
      }),
    );
}
