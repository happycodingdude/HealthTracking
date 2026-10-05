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

/// SQLite trên máy (TD-04). Mỗi slice tăng `schemaVersion` tối đa 1 bước
/// (ED-05, 06 §6.5.2).
@DriftDatabase(tables: [SyncState])
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.executor);

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
      await into(
        syncState,
      ).insert(SyncStateCompanion.insert(id: const Value(1)));
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );
}
