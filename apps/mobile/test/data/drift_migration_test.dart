import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/data/db/app_database.dart';

import '../generated_migrations/schema.dart';
import '../generated_migrations/schema_v1.dart' as v1;
import '../generated_migrations/schema_v2.dart' as v2;
import '../generated_migrations/schema_v3.dart' as v3;
import '../generated_migrations/schema_v4.dart' as v4;

void main() {
  late SchemaVerifier verifier;

  setUpAll(() => verifier = SchemaVerifier(GeneratedHelper()));

  test(
    'ED-05: Drift v1 → v5 (outbox, account, hồ sơ, cân, nháp, lịch, thực đơn) đúng schema, giữ dữ liệu sync_state',
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
      await verifier.migrateAndValidate(db, 5);
      final state = await db.select(db.syncState).getSingle();
      expect(state.cursor, 42);
      expect(await db.select(db.outbox).get(), isEmpty);
    },
  );

  test(
    'ED-05: Drift v2 → v5 giữ tên hiển thị và thay đổi chờ gửi của VS-02',
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
      await verifier.migrateAndValidate(db, 5);
      expect((await db.select(db.account).getSingle()).displayName, 'Minh');
      expect((await db.select(db.outbox).getSingle()).mutationId, 'm1');
      expect(await db.select(db.profiles).get(), isEmpty);
    },
  );

  test('ED-05: Drift v3 → v5 giữ hồ sơ, cân và nháp thiết lập của VS-03', () async {
    final schema = await verifier.schemaAt(3);
    final old = v3.DatabaseAtV3(schema.newConnection());
    await old.customStatement(
      'INSERT INTO sync_state (id, cursor) VALUES (1, 9)',
    );
    await old.customStatement(
      "INSERT INTO profiles (key, onboarding_step, height_cm) VALUES ('me', 3, 175)",
    );
    await old.customStatement(
      "INSERT INTO weights (week_start, weight_kg_x10) VALUES ('2026-10-05', 725)",
    );
    await old.customStatement(
      "INSERT INTO onboarding_draft (id, height) VALUES (1, '17')",
    );
    await old.close();

    final db = AppDatabase(schema.newConnection());
    addTearDown(db.close);
    await verifier.migrateAndValidate(db, 5);
    expect((await db.select(db.profiles).getSingle()).heightCm, 175);
    expect((await db.select(db.weights).getSingle()).weightKgX10, 725);
    final draft = await db.select(db.onboardingDraft).getSingle();
    expect((draft.height, draft.template), ('17', null));
    expect(await db.select(db.days).get(), isEmpty);
  });

  test('ED-05: Drift v4 → v5 giữ lịch, cursor đồng bộ; có bảng thực đơn và '
      'ngân sách AI rỗng (VS-12)', () async {
    final schema = await verifier.schemaAt(4);
    final old = v4.DatabaseAtV4(schema.newConnection());
    await old.customStatement(
      'INSERT INTO sync_state (id, cursor) VALUES (1, 77)',
    );
    await old.customStatement(
      "INSERT INTO weekly_templates (key, days, content_hash) VALUES ('me', '{}', 'h')",
    );
    await old.close();

    final db = AppDatabase(schema.newConnection());
    addTearDown(db.close);
    await verifier.migrateAndValidate(db, 5);
    final state = await db.select(db.syncState).getSingle();
    expect((state.cursor, state.aiBudget), (77, null));
    expect((await db.select(db.weeklyTemplates).getSingle()).contentHash, 'h');
    expect(await db.select(db.menus).get(), isEmpty);
    expect(await db.select(db.aiDailyUsage).get(), isEmpty);
  });

  test('tạo mới thẳng ở v5 khớp schema đã lưu', () async {
    final schema = await verifier.schemaAt(5);
    final db = AppDatabase(schema.newConnection());
    addTearDown(db.close);
    await verifier.migrateAndValidate(db, 5);
  });
}
