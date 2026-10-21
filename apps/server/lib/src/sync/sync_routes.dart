import 'package:api_contract/api_contract.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import '../auth/auth_middleware.dart';
import '../auth/token_service.dart';
import '../http/api_exception.dart';
import '../http/json.dart';
import '../http/request_info.dart';
import 'sync_service.dart';

/// `/v1/sync/*` (05 §6.6.2, §6.6.3).
void addSyncRoutes(Router router, SyncService sync, TokenService tokens) {
  router.get(
    '/v1/sync/pull',
    authenticated(tokens, (Request request, userId) async {
      final query = request.url.queryParameters;
      final cursor = int.tryParse(query['cursor'] ?? '0');
      if (cursor == null || cursor < 0) {
        throw ApiException(ErrorCode.validationFailed, field: 'cursor');
      }
      final limit = int.tryParse(query['limit'] ?? '${PullResponse.maxLimit}');
      if (limit == null || limit < 1 || limit > PullResponse.maxLimit) {
        throw ApiException(ErrorCode.validationFailed, field: 'limit');
      }
      return jsonResponse(
        (await sync.pull(
          userId,
          cursor: cursor,
          limit: limit,
          appVersion: request.info.appVersion,
        )).toJson(),
      );
    }),
  );
  router.post(
    '/v1/sync/push',
    authenticated(tokens, (Request request, userId) async {
      final req = await readDto(request, PushRequest.fromJson);
      return jsonResponse(
        (await sync.push(
          userId,
          req,
          appVersion: request.info.appVersion,
        )).toJson(),
      );
    }),
  );
}
