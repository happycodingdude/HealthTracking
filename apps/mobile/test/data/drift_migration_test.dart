import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/data/db/app_database.dart';

import '../generated_migrations/schema.dart';
import '../generated_migrations/schema_v1.dart' as v1;
import '../generated_migrations/schema_v2.dart' as v2;

void main() {
  late SchemaVerifier verifier;

  setUpAll(() => verifier = SchemaVerifier(GeneratedHelper()));

  test(
    'ED-05: Drift v1 → v3 (outbox, account, profiles, weights, onboarding_draft) đúng schema, giữ dữ liệu sync_state',
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
      await verifier.migrateAndValidate(db, 3);
      final state = await db.select(db.syncState).getSingle();
      expect(state.cursor, 42);
      expect(await db.select(db.outbox).get(), isEmpty);
    },
  );

  test(
    'ED-05: Drift v2 → v3 giữ tên hiển thị và thay đổi chờ gửi của VS-02',
    () async {
      final schema = await verifier.schemaAt(2);
      final old = v2.DatabaseAtV2(schema.newConnection());
      await old.customStatement(
        'INSERT INTO sync_state (id, cursor) VALUES (1, 7)',
      );
      await old.customStatement(
        "INSERT INTO account (key, display_name) VALUES ('me', 'Minh')",
      );
      await old.customStatement(
        'INSERT INTO outbox (mutation_id, entity, key, op, payload, client_updated_at) '
        """VALUES ('m1', 'account', 'me', 'upsert', '{"displayName":"Minh"}', '2026-10-07T18:42:00.000+07:00')""",
      );
      await old.close();

      final db = AppDatabase(schema.newConnection());
      addTearDown(db.close);
      await verifier.migrateAndValidate(db, 3);
      expect((await db.select(db.account).getSingle()).displayName, 'Minh');
      expect((await db.select(db.outbox).getSingle()).mutationId, 'm1');
      expect(await db.select(db.profiles).get(), isEmpty);
    },
  );

  test('tạo mới thẳng ở v3 khớp schema đã lưu', () async {
    final schema = await verifier.schemaAt(3);
    final db = AppDatabase(schema.newConnection());
    addTearDown(db.close);
    await verifier.migrateAndValidate(db, 3);
  });
}
