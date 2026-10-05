import 'package:domain/domain.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import 'account/me_routes.dart';
import 'auth/auth_routes.dart';
import 'auth/auth_service.dart';
import 'auth/login_rate_limiter.dart';
import 'auth/token_service.dart';
import 'db/database.dart';
import 'health/health_routes.dart';
import 'http/middleware.dart';
import 'logging/logger.dart';

/// Các thành phần dùng chung của API, tạo một lần khi khởi động.
final class AppDeps {
  AppDeps({
    required this.db,
    required this.logger,
    required this.clock,
    required String jwtSecret,
    this.bcryptCost = 12,
    this.trustProxy = false,
  }) : tokens = TokenService(secret: jwtSecret, clock: clock),
       limiter = LoginRateLimiter(clock) {
    auth = AuthService(
      pool: db.pool,
      tokens: tokens,
      limiter: limiter,
      bcryptCost: bcryptCost,
    );
  }

  final Database db;
  final Logger logger;
  final Clock clock;
  final int bcryptCost;
  final bool trustProxy;
  final TokenService tokens;
  final LoginRateLimiter limiter;
  late final AuthService auth;
}

/// Ghép toàn bộ route và middleware của API.
Handler buildApp(AppDeps deps) {
  final router = Router(notFoundHandler: notFoundHandler)
    ..get('/healthz', healthHandler(deps.db));
  addAuthRoutes(router, deps.auth, trustProxy: deps.trustProxy);
  addMeRoutes(router, deps.db.pool, deps.tokens);
  return const Pipeline()
      .addMiddleware(coreMiddleware(deps.logger))
      .addHandler(router.call);
}
