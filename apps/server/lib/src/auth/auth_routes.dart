import 'package:api_contract/api_contract.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import '../http/client_ip.dart';
import '../http/json.dart';
import 'auth_service.dart';

/// `/v1/auth/*` (05 §6.8.2).
void addAuthRoutes(
  Router router,
  AuthService auth, {
  required bool trustProxy,
}) {
  router
    ..post('/v1/auth/register', (Request request) async {
      final req = await readDto(request, RegisterRequest.fromJson);
      return jsonResponse((await auth.register(req)).toJson(), status: 201);
    })
    ..post('/v1/auth/login', (Request request) async {
      final req = await readDto(request, LoginRequest.fromJson);
      final pair = await auth.login(
        req,
        ip: clientIp(request, trustProxy: trustProxy),
      );
      return jsonResponse(pair.toJson());
    })
    ..post('/v1/auth/refresh', (Request request) async {
      final req = await readDto(request, RefreshRequest.fromJson);
      return jsonResponse((await auth.refresh(req)).toJson());
    });
}
