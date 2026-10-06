import 'dart:convert';

import 'package:api_contract/api_contract.dart';
import 'package:domain/domain.dart';
import 'package:drift/drift.dart';

import '../../../data/db/app_database.dart';

/// Bản sao trên máy của entity chỉ pull `menu`, `ai_daily_usage` và
/// `meta.aiBudget` (VS-12). Chỉ server ghi: app ghi lại đúng bản server trả.
final class MenuRepository {
  MenuRepository(this._db);

  final AppDatabase _db;

  static const _codec = MenuCodec();

  Future<void> put(LocalDate date, MenuData menu) {
    final data = _codec.encode(menu);
    return _db
        .into(_db.menus)
        .insertOnConflictUpdate(
          MenusCompanion.insert(
            date: date.toKey(),
            payload: Value(
              data['payload'] == null ? null : jsonEncode(data['payload']),
            ),
            targetKcal: menu.targetKcal,
            usedSafetyFloor: menu.usedSafetyFloor,
            totalKcal: Value(menu.totalKcal),
            lastAttemptStatus: data['lastAttemptStatus']! as String,
            lastErrorCode: Value(menu.lastErrorCode?.wire),
            generatedAt: Value(menu.generatedAt),
          ),
        );
  }

  Future<void> delete(LocalDate date) =>
      (_db.delete(_db.menus)..where((m) => m.date.equals(date.toKey()))).go();

  /// Thực đơn của [date] (F08-R11: xem lại không cần mạng).
  Stream<MenuData?> watch(LocalDate date) =>
      (_db.select(_db.menus)..where((m) => m.date.equals(date.toKey())))
          .watchSingleOrNull()
          .map((r) => r == null ? null : _menu(r));

  Future<MenuData?> get(LocalDate date) async {
    final r = await (_db.select(
      _db.menus,
    )..where((m) => m.date.equals(date.toKey()))).getSingleOrNull();
    return r == null ? null : _menu(r);
  }

  Future<void> putUsage(String key, int successCount) => _db
      .into(_db.aiDailyUsage)
      .insertOnConflictUpdate(
        AiDailyUsageCompanion.insert(key: key, successCount: successCount),
      );

  Future<void> deleteUsage(String key) =>
      (_db.delete(_db.aiDailyUsage)..where((u) => u.key.equals(key))).go();

  /// Số lần tạo thành công của [date] (F08-R2).
  Stream<int> watchUsage(LocalDate date) =>
      (_db.select(_db.aiDailyUsage)
            ..where((u) => u.key.equals(AiDailyUsageCodec.key(date))))
          .watchSingleOrNull()
          .map((r) => r?.successCount ?? 0);

  /// `meta.aiBudget` của lần pull gần nhất (ED-04).
  Stream<AiBudgetMeta?> watchBudget() =>
      _db.select(_db.syncState).watchSingleOrNull().map((s) {
        final raw = s?.aiBudget;
        return raw == null ? null : AiBudgetMeta.fromJson(jsonDecode(raw));
      });

  static MenuData _menu(MenuRow r) => _codec.decode({
    'payload': r.payload == null ? null : jsonDecode(r.payload!),
    'targetKcal': r.targetKcal,
    'usedSafetyFloor': r.usedSafetyFloor,
    'totalKcal': r.totalKcal,
    'lastAttemptStatus': r.lastAttemptStatus,
    'lastErrorCode': r.lastErrorCode,
    'generatedAt': r.generatedAt == null
        ? null
        : InstantCodec.encode(r.generatedAt!),
  });
}
