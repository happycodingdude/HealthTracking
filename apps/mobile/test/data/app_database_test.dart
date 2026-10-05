import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/data/db/app_database.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  test(
    'schemaVersion 1: tạo sync_state một dòng, cursor 0, chưa đồng bộ',
    () async {
      expect(db.schemaVersion, 2);
      final rows = await db.select(db.syncState).get();
      expect(rows, hasLength(1));
      expect(rows.single.id, 1);
      expect(rows.single.cursor, 0);
      expect(rows.single.lastSyncedAt, isNull);
    },
  );

  test('sync_state chỉ có dòng id = 1', () async {
    await expectLater(
      db
          .into(db.syncState)
          .insert(SyncStateCompanion.insert(id: const Value(2))),
      throwsA(isA<SqliteException>()),
    );
  });

  test('DateTime lưu dạng text giữ mili giây', () async {
    final t = DateTime.utc(2026, 10, 7, 11, 42, 10, 123);
    await db
        .update(db.syncState)
        .write(SyncStateCompanion(lastSyncedAt: Value(t)));
    final row = await db.select(db.syncState).getSingle();
    expect(row.lastSyncedAt!.toUtc(), t);
  });
}
