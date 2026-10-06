import 'package:api_contract/api_contract.dart';
import 'package:domain/domain.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import '../auth/auth_middleware.dart';
import '../auth/token_service.dart';
import '../http/api_exception.dart';
import '../http/json.dart';
import 'menu_service.dart';

/// `POST /v1/ai/menus`, `GET /v1/ai/menus/{date}` (05 §6.8.2, §6.9.2).
void addMenuRoutes(Router router, MenuService menus, TokenService tokens) {
  router.post(
    '/v1/ai/menus',
    authenticated(tokens, (Request request, userId) async {
      final req = await readDto(request, GenerateMenuRequest.fromJson);
      return jsonResponse((await menus.generate(userId, req)).toJson());
    }),
  );
  router.get(
    '/v1/ai/menus/<date>',
    authenticated(tokens, (Request request, userId) async {
      final date = LocalDate.tryParse(request.params['date'] ?? '');
      if (date == null) {
        throw ApiException(ErrorCode.validationFailed, field: 'date');
      }
      return jsonResponse((await menus.status(userId, date)).toJson());
    }),
  );
}
