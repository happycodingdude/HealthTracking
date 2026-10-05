import 'package:drift/drift.dart';

part 'app_database.g.dart';

/// Trạng thái đồng bộ (05 §6.5): cursor của lần pull cuối và thời điểm đồng
/// bộ thành công gần nhất. Một dòng duy nhất, `id = 1`.
@DataClassName('SyncStateRow')
class SyncState extends Table {
  @override
  String get tableName => 'sync_state';

  IntColumn get id => integer().check(const CustomExpression<bool>('id = 1'))();
  IntColumn get cursor => integer().withDefault(const Constant(0))();
  DateTimeColumn get lastSyncedAt => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// Hàng đợi thay đổi chưa gửi (05 §6.5). Còn dòng = "Chưa đồng bộ" (F09-E1).
@DataClassName('OutboxRow')
class Outbox extends Table {
  @override
  String get tableName => 'outbox';

  /// Thứ tự gửi.
  IntColumn get id => integer().autoIncrement()();
  TextColumn get mutationId => text().unique()();
  TextColumn get entity => text()();
  TextColumn get entityKey => text().named('key')();

  /// `upsert` / `ensure` / `delete`.
  TextColumn get op => text()();

  /// `data` dạng JSON; null với `delete`.
  TextColumn get payload => text().nullable()();
  DateTimeColumn get clientUpdatedAt => dateTime()();
  IntColumn get attempts => integer().withDefault(const Constant(0))();
  TextColumn get lastError => text().nullable()();
}

/// Bản sao entity `account` (key `me`): tên hiển thị (VS-02).
@DataClassName('AccountRow')
class Account extends Table {
  @override
  String get tableName => 'account';

  TextColumn get key => text()();
  TextColumn get displayName => text()();

  @override
  Set<Column<Object>> get primaryKey => {key};
}

/// SQLite trên máy (TD-04). Mỗi slice tăng `schemaVersion` tối đa 1 bước
/// (ED-05, 06 §6.5.2).
@DriftDatabase(tables: [SyncState, Outbox, Account])
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.executor);

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
      await into(
        syncState,
      ).insert(SyncStateCompanion.insert(id: const Value(1)));
    },
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        // VS-02: outbox và account.
        await m.createTable(outbox);
        await m.createTable(account);
      }
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );
}
