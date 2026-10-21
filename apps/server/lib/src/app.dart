import 'package:domain/domain.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import 'account/me_routes.dart';
import 'ai/ai_config.dart';
import 'ai/ai_provider.dart';
import 'ai/fake_ai_provider.dart';
import 'ai/menu_routes.dart';
import 'ai/menu_service.dart';
import 'auth/auth_routes.dart';
import 'auth/auth_service.dart';
import 'auth/login_rate_limiter.dart';
import 'auth/token_service.dart';
import 'db/database.dart';
import 'health/health_routes.dart';
import 'http/middleware.dart';
import 'logging/logger.dart';
import 'sync/account_handler.dart';
import 'sync/exercise_unit_note_handlers.dart';
import 'sync/lift_log_handler.dart';
import 'sync/menu_handlers.dart';
import 'sync/profile_handler.dart';
import 'sync/schedule_handlers.dart';
import 'sync/shared_handlers.dart';
import 'sync/sync_entity_handler.dart';
import 'sync/sync_routes.dart';
import 'sync/sync_service.dart';
import 'sync/weight_handler.dart';

/// Entity đồng bộ (06 §6.5.1, 06 Bản 2 §6.5.1). Slice sau thêm handler vào
/// đây.
const defaultSyncHandlers = <SyncEntityHandler>[
  AccountHandler(),
  ProfileHandler(),
  WeightHandler(),
  WeeklyTemplateHandler(),
  MonthPlanHandler(),
  DayHandler(),
  MenuHandler(),
  AiDailyUsageHandler(),
  // Bản 2: dòng dùng chung, chỉ pull (VS20-T08).
  ExerciseHandler(),
  DishImageHandler(),
  // Bản 2: mức tạ, push + pull (VS26-T05).
  LiftLogHandler(),
  // Bản 3: đơn vị của bài, ghi chú bài theo buổi, push + pull (VS32-T04).
  ExerciseUnitHandler(),
  ExerciseNoteHandler(),
];

/// Các thành phần dùng chung của API, tạo một lần khi khởi động.
final class AppDeps {
  AppDeps({
    required this.db,
    required this.logger,
    required this.clock,
    required String jwtSecret,
    this.bcryptCost = 12,
    this.trustProxy = false,
    List<SyncEntityHandler> syncHandlers = defaultSyncHandlers,
    this.aiConfig = const AiConfig(),
    AiProvider? aiProvider,
  }) : tokens = TokenService(secret: jwtSecret, clock: clock),
       limiter = LoginRateLimiter(clock) {
    auth = AuthService(
      pool: db.pool,
      tokens: tokens,
      limiter: limiter,
      bcryptCost: bcryptCost,
    );
    sync = SyncService(
      pool: db.pool,
      clock: clock,
      handlers: syncHandlers,
      logger: logger,
      budgetCapVnd: aiConfig.capVnd,
    );
    // ED-11: mặc định dùng nhà cung cấp giả.
    menus = MenuService(
      pool: db.pool,
      clock: clock,
      provider: aiProvider ?? FakeAiProvider(),
      config: aiConfig,
      logger: logger,
    );
  }

  final Database db;
  final Logger logger;
  final Clock clock;
  final int bcryptCost;
  final bool trustProxy;
  final TokenService tokens;
  final LoginRateLimiter limiter;
  final AiConfig aiConfig;
  late final AuthService auth;
  late final SyncService sync;
  late final MenuService menus;
}

/// Ghép toàn bộ route và middleware của API.
Handler buildApp(AppDeps deps) {
  final router = Router(notFoundHandler: notFoundHandler)
    ..get('/healthz', healthHandler(deps.db));
  addAuthRoutes(router, deps.auth, trustProxy: deps.trustProxy);
  addMeRoutes(router, deps.db.pool, deps.tokens);
  addSyncRoutes(router, deps.sync, deps.tokens);
  addMenuRoutes(router, deps.menus, deps.tokens);
  return const Pipeline()
      .addMiddleware(coreMiddleware(deps.logger))
      .addHandler(router.call);
}
