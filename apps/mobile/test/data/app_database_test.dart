import 'package:domain/domain.dart' show MuscleRegion;
import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/data/db/app_database.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  test(
    'schemaVersion 2 (Bản 3): tạo sync_state một dòng, cursor 0, chưa đồng bộ',
    () async {
      expect(db.schemaVersion, 2);
      final rows = await db.select(db.syncState).get();
      expect(rows, hasLength(1));
      expect(rows.single.id, 1);
      expect(rows.single.cursor, 0);
      expect(rows.single.lastSyncedAt, isNull);
      expect(rows.single.knownEntities, isNull);
    },
  );

  test('VS32-T05: bảng Bản 2, Bản 3 có sẵn; 19 vùng cơ nạp sẵn đúng thứ tự '
      '(05 Bản 3 §6.10.3)', () async {
    final regions = await (db.select(
      db.muscleRegions,
    )..orderBy([(r) => OrderingTerm.asc(r.sortOrder)])).get();
    expect(
      [for (final r in regions) r.id],
      [for (final r in MuscleRegion.values) r.id],
    );
    expect(regions.first.muscleGroup, 'chest');
    expect(regions[8].view, 'back');
    expect(await db.select(db.exercises).get(), isEmpty);
    expect(await db.select(db.liftLogs).get(), isEmpty);
    expect(await db.select(db.dishImages).get(), isEmpty);
    expect(await db.select(db.exerciseUnits).get(), isEmpty);
    expect(await db.select(db.exerciseNotes).get(), isEmpty);
  });

  test('đăng nhập tài khoản khác (wipe) giữ vùng cơ nạp sẵn', () async {
    await db.wipe();
    expect(await db.select(db.muscleRegions).get(), hasLength(19));
  });

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
