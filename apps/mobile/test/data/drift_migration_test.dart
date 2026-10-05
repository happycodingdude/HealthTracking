import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/data/db/app_database.dart';

import '../generated_migrations/schema.dart';
import '../generated_migrations/schema_v1.dart' as v1;

void main() {
  late SchemaVerifier verifier;

  setUpAll(() => verifier = SchemaVerifier(GeneratedHelper()));

  test(
    'ED-05: Drift v1 → v2 (outbox, account) đúng schema, giữ dữ liệu sync_state',
    () async {
      final schema = await verifier.schemaAt(1);
      final old = v1.DatabaseAtV1(schema.newConnection());
      // Bản v1 thật có sẵn dòng sync_state (onCreate của v1).
      await old.customStatement(
        'INSERT INTO sync_state (id, cursor) VALUES (1, 42)',
      );
      await old.close();

      final db = AppDatabase(schema.newConnection());
      addTearDown(db.close);
      await verifier.migrateAndValidate(db, 2);
      final state = await db.select(db.syncState).getSingle();
      expect(state.cursor, 42);
      expect(await db.select(db.outbox).get(), isEmpty);
    },
  );

  test('tạo mới thẳng ở v2 khớp schema đã lưu', () async {
    final schema = await verifier.schemaAt(2);
    final db = AppDatabase(schema.newConnection());
    addTearDown(db.close);
    await verifier.migrateAndValidate(db, 2);
  });
}
