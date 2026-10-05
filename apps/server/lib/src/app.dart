import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import 'db/database.dart';
import 'health/health_routes.dart';
import 'http/middleware.dart';
import 'logging/logger.dart';

/// Ghép toàn bộ route và middleware của API.
Handler buildApp({required Database db, required Logger logger}) {
  final router = Router(notFoundHandler: notFoundHandler)
    ..get('/healthz', healthHandler(db));
  return const Pipeline()
      .addMiddleware(coreMiddleware(logger))
      .addHandler(router.call);
}
