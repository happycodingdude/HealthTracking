import 'package:api_contract/api_contract.dart';

import '../ai/menu_service.dart';
import 'sync_entity_handler.dart';

/// Entity `menu`, key = ngày (06 §6.5.1, VS12-T03).
final class MenuHandler extends PullOnlyHandler {
  const MenuHandler();

  @override
  String get entity => SyncEntities.menu;

  @override
  String get pullSql => MenuQueries.pullSql;
}

/// Entity `ai_daily_usage`, key `YYYY-MM-DD:menu`.
final class AiDailyUsageHandler extends PullOnlyHandler {
  const AiDailyUsageHandler();

  @override
  String get entity => SyncEntities.aiDailyUsage;

  @override
  String get pullSql => MenuQueries.usagePullSql;
}
