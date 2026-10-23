import 'package:api_contract/api_contract.dart';
import 'package:domain/domain.dart';
import 'package:postgres/postgres.dart';
import 'package:server/server.dart';
import 'package:server/testing.dart';
import 'package:test/test.dart';

import 'support/test_app.dart';

/// 06 Bản 3 VS32-T10: nền Bản 3 phía server — migration (TAC3-12, ED3-02),
/// CHECK của bảng mới, pull hai entity mới (khung TAC3-13), `exercise` theo
/// phiên bản app (TD3-21).
void main() {
  final violates = throwsA(
    isA<ServerException>().having((e) => e.code, 'code', '23514'),
  );

  group('TAC3-12: cấu trúc từ migration khớp schema.sql sinh ra', () {
    Future<List<String>> structure(Pool<void> pool) async {
      final out = <String>[];
      for (final sql in [
        '''SELECT table_name || '.' || column_name || ' ' || udt_name || ' '
                  || is_nullable || ' ' || coalesce(column_default, '')
           FROM information_schema.columns
           WHERE table_schema = 'public' AND table_name <> 'schema_migrations'
           ORDER BY 1''',
        '''SELECT conrelid::regclass::text || ' ' || conname || ' '
                  || pg_get_constraintdef(oid)
           FROM pg_constraint
           WHERE connamespace = 'public'::regnamespace
             AND conrelid <> 'schema_migrations'::regclass
           ORDER BY 1''',
        '''SELECT indexdef FROM pg_indexes
           WHERE schemaname = 'public' AND tablename <> 'schema_migrations'
           ORDER BY 1''',
        '''SELECT t.typname || ' ' || string_agg(e.enumlabel, ',' ORDER BY e.enumsortorder)
           FROM pg_enum e JOIN pg_type t ON t.oid = e.enumtypid
           GROUP BY t.typname ORDER BY 1''',
        '''SELECT id || ' ' || muscle_group || ' ' || view || ' ' || sort_order
           FROM muscle_regions ORDER BY sort_order''',
      ]) {
        out.addAll([for (final r in await pool.execute(sql)) r[0]! as String]);
      }
      return out;
    }

    test('database từ 0001 + 0002 và từ schema.sql giống nhau', () async {
      final fromMigrations = await TestDatabase.create();
      final fromSchema = await TestDatabase.create(schema: false);
      addTearDown(fromMigrations.dispose);
      addTearDown(fromSchema.dispose);
      for (final segment in SqlScript.segments(
        serverSchemaFile().readAsStringSync(),
      )) {
        await fromSchema.pool.execute(segment, queryMode: QueryMode.simple);
      }
      // Hai bên cùng có bảng schema_migrations (bỏ qua khi so).
      await fromSchema.pool.execute(
        'CREATE TABLE schema_migrations (version text PRIMARY KEY)',
      );
      final a = await structure(fromMigrations.pool);
      final b = await structure(fromSchema.pool);
      expect(a, b);
      expect(a, contains(startsWith('exercise_units.unit text NO')));
      expect(
        a,
        contains('muscle_group chest,triceps,shoulders,abs,back,biceps,legs'),
      );
    });
  });

  group('ED3-02: chạy từ bản trước (0001 + dữ liệu Bản 2 + 0002)', () {
    late TestDatabase tdb;
    setUp(() async => tdb = await TestDatabase.create(schema: false));
    tearDown(() => tdb.dispose());

    test('v2DataSet còn nguyên sau 0002; cột, bảng Bản 3 có sẵn', () async {
      await tdb.pool.execute(
        repoFile('apps/server/migrations/0001_baseline.sql').readAsStringSync(),
        queryMode: QueryMode.simple,
      );
      final user = await V2DataSet.load(tdb.pool);
      final applied = await Migrator(
        tdb.pool,
        serverMigrationsDir(),
        Logger((_) {}),
      ).migrate();
      expect(applied, ['0002_v3']);

      final lifts = await tdb.pool.execute(
        Sql.named(
          'SELECT exercise_id, start_kg_x10, end_kg_x10 FROM lift_logs '
          'WHERE user_id = @u AND NOT deleted ORDER BY date, exercise_id',
        ),
        parameters: {'u': user},
      );
      expect(
        lifts,
        hasLength(V2DataSet.keptLifts.length + V2DataSet.removedLifts.length),
      );
      final ex = await tdb.pool.execute(
        'SELECT count(*), count(equipment), bool_and(NOT deleted), '
        'bool_and(sort_in_group = 0) FROM exercises',
      );
      expect(ex.single.toList(), [29, 29, true, true]);
      for (final table in [
        'exercise_units',
        'exercise_notes',
        'live_activity_tokens',
        'live_activity_sessions',
      ]) {
        final n = await tdb.pool.execute('SELECT count(*) FROM $table');
        expect(n.single[0], 0, reason: table);
      }
    });

    test('F03-AC42, F03-R42: cập nhật lên Bản 3 theo thứ tự phát hành (0002 '
        '→ purge → import 28 bài) → lịch tuần, lịch tháng, các ngày y như '
        'trước; không có ngày Chân', () async {
      await tdb.pool.execute(
        repoFile('apps/server/migrations/0001_baseline.sql').readAsStringSync(),
        queryMode: QueryMode.simple,
      );
      final user = await V2DataSet.load(tdb.pool);
      final hash = 'a' * 64;
      await tdb.pool.execute(
        Sql.named('''
          INSERT INTO weekly_templates (user_id, days, content_hash,
                                        server_version, client_updated_at)
          VALUES (@u, @days::jsonb, @h, nextval('sync_version_seq'), now())'''),
        parameters: {
          'u': user,
          'h': hash,
          'days':
              '{"1": {"enabled": true, "time": "18:00", '
              '"muscles": ["chest", "triceps"]}, "3": {"enabled": true, '
              '"time": "18:00", "muscles": ["back", "biceps"]}}',
        },
      );
      await tdb.pool.execute(
        Sql.named('''
          INSERT INTO month_plans (user_id, month, start_date, template_hash,
                                   generated_at, server_version,
                                   client_updated_at)
          VALUES (@u, '2026-11', '2026-11-01', @h, now(),
                  nextval('sync_version_seq'), now())'''),
        parameters: {'u': user, 'h': hash},
      );
      Future<List<List<Object?>>> schedule() async => [
        for (final sql in [
          'SELECT days::text, content_hash, server_version, deleted '
              'FROM weekly_templates',
          'SELECT month, start_date::text, template_hash, server_version, '
              'deleted FROM month_plans',
          'SELECT date::text, kind::text, time::text, muscles::text, mark::text, '
              'actual_muscles::text, server_version, deleted FROM days '
              'ORDER BY date',
        ])
          for (final r in await tdb.pool.execute(sql)) r.toList(),
      ];
      final before = await schedule();

      expect(
        await Migrator(
          tdb.pool,
          serverMigrationsDir(),
          Logger((_) {}),
        ).migrate(),
        ['0002_v3'],
      );
      final purge = LibraryPurge(
        tdb.pool,
        FixedClock(DateTime.utc(2026, 11, 12, 10)),
      );
      await purge.apply(confirmCount: (await purge.dryRun()).total);
      expect((await LibraryImporter(tdb.pool).run(library28())).ok, isTrue);

      expect(await schedule(), before);
      final legs = await tdb.pool.execute(
        "SELECT count(*) FROM days WHERE 'legs' = ANY(muscles)",
      );
      expect(legs.single[0], 0);
    });
  });

  group('CHECK bảng Bản 3', () {
    late TestDatabase tdb;
    late String user;
    setUp(() async {
      tdb = await TestDatabase.create();
      user = await V2DataSet.load(tdb.pool);
    });
    tearDown(() => tdb.dispose());

    Future<void> unit(String value) => tdb.pool.execute(
      Sql.named(
        '''
        INSERT INTO exercise_units (user_id, exercise_id, unit, changed_on,
                                    client_updated_at, server_version)
        VALUES (@u, 'chest-mid-machine-pec-deck', @unit, '2026-11-12', now(), 1)
        ON CONFLICT (user_id, exercise_id) DO UPDATE SET unit = EXCLUDED.unit''',
      ),
      parameters: {'u': user, 'unit': value},
    );

    Future<void> note(String text) => tdb.pool.execute(
      Sql.named(
        '''
        INSERT INTO exercise_notes (user_id, date, exercise_id, text, logged_at,
                                    client_updated_at, server_version)
        VALUES (@u, '2026-11-02', 'chest-mid-machine-pec-deck', @t, now(), now(), 1)
        ON CONFLICT (user_id, date, exercise_id) DO UPDATE SET text = EXCLUDED.text''',
      ),
      parameters: {'u': user, 't': text},
    );

    test('exercise_units.unit chỉ kg / steps', () async {
      await unit('kg');
      await unit('steps');
      await expectLater(unit('plates'), violates);
    });

    test(
      'exercise_notes.text tối đa 200 ký tự; ghi chú cần buổi có thật',
      () async {
        await note('a' * 200);
        await expectLater(note('a' * 201), throwsA(isA<ServerException>()));
        await expectLater(
          tdb.pool.execute(
            Sql.named(
              '''
            INSERT INTO exercise_notes (user_id, date, exercise_id, text, logged_at,
                                        client_updated_at, server_version)
            VALUES (@u, '2026-11-03', 'chest-mid-machine-pec-deck', 'x', now(), now(), 1)''',
            ),
            parameters: {'u': user},
          ),
          throwsA(isA<ServerException>()),
        );
      },
    );
  });

  group('pull Bản 3 (VS32-T04)', () {
    late TestApp app;
    setUp(() async {
      app = await TestApp.create(now: DateTime.utc(2026, 11, 12, 11));
      await insertV2Library(app.tdb.pool);
    });
    tearDown(() => app.dispose());

    Future<void> addV3Rows() async {
      // Dòng kiểu nạp từ Bản 3 (không `equipment`) và một bài Chân.
      await app.tdb.pool.execute(
        '''
        UPDATE exercises SET equipment = NULL, sort_in_group = 1,
               server_version = nextval('sync_version_seq')
        WHERE id = 'chest-mid-machine-pec-deck';
        INSERT INTO exercises (id, muscle_group, muscle_region, logs_weight, name_vi,
                               youtube_video_id, video_channel, video_duration_s,
                               guide_steps, guide_safety, approved_at, sort_in_group,
                               sort_order, library_version, server_version)
        VALUES ('legs-quads-leg-press', 'legs', 'quads', true, 'Nằm máy đạp chân',
                'abcdefghijk', 'Kênh', 40, ARRAY['a','b','c'], ARRAY['a','b'],
                '2026-10-21', 1, 701, 2, nextval('sync_version_seq'));
        UPDATE exercises SET deleted = true, active = false,
               server_version = nextval('sync_version_seq')
        WHERE id = 'biceps-free-weight-dumbbell-biceps-curl';''',
        queryMode: QueryMode.simple,
      );
    }

    test('TD3-21: app < 3.0.0 (và không có header) chỉ nhận dòng đọc được, '
        'dạng Bản 2; cursor vẫn tiến qua dòng bị lọc', () async {
      await addV3Rows();
      final token = (await app.register()).accessToken;
      final max =
          (await app.tdb.pool.execute(
                'SELECT max(server_version) FROM exercises',
              )).single[0]!
              as int;
      for (final version in [null, AppVersion.v2]) {
        final page = await app.pull(token, appVersion: version);
        final exercises = {
          for (final c in page.changes)
            if (c.entity == SyncEntities.exercise) c.key: c,
        };
        expect(exercises.keys, isNot(contains('legs-quads-leg-press')));
        expect(exercises.keys, isNot(contains('chest-mid-machine-pec-deck')));
        expect(
          exercises['biceps-free-weight-dumbbell-biceps-curl']!.deleted,
          isTrue,
        );
        expect(exercises, hasLength(28));
        final kept = exercises['lats-machine-lat-pulldown']!.data!;
        expect(kept['equipment'], 'machine');
        expect(kept.containsKey('sortInGroup'), isFalse);
        expect(page.nextCursor, greaterThanOrEqualTo(max));
        expect(page.hasMore, isFalse);
        expect(page.changes.any((c) => c.entity == '-'), isFalse);
      }
    });

    test('TD3-21: app 3.0.0 nhận mọi dòng, dạng Bản 3', () async {
      await addV3Rows();
      final token = (await app.register()).accessToken;
      final page = await app.pull(token);
      final exercises = {
        for (final c in page.changes)
          if (c.entity == SyncEntities.exercise) c.key: c,
      };
      expect(exercises, hasLength(30));
      final legs = const ExerciseCodec().decode(
        'legs-quads-leg-press',
        exercises['legs-quads-leg-press']!.data!,
      );
      expect(
        (legs.group, legs.region, legs.sortInGroup),
        (MuscleGroup.legs, MuscleRegion.quads, 1),
      );
      expect(
        exercises['legs-quads-leg-press']!.data!.containsKey('equipment'),
        isFalse,
      );
      expect(
        exercises['biceps-free-weight-dumbbell-biceps-curl']!.deleted,
        isTrue,
      );
    });

    test('exercise_unit, exercise_note: push cấu trúc, pull về đúng tài khoản '
        '(khung TAC3-13)', () async {
      app.clock.set(DateTime.utc(2026, 11, 12, 11, 35));
      final a = (await app.register()).accessToken;
      final b = (await app.register(phone: '0912345679')).accessToken;
      final userA =
          (await app.tdb.pool.execute(
                "SELECT id FROM users WHERE phone = '0912345678'",
              )).single[0]!
              as String;
      await app.tdb.pool.execute(
        Sql.named(
          '''
          INSERT INTO days (user_id, date, kind, time, muscles, server_version, client_updated_at)
          VALUES (@u, '2026-11-12', 'workout', '18:00', ARRAY['chest']::muscle_group[], 1, now())''',
        ),
        parameters: {'u': userA},
      );
      await app.tdb.pool.execute(
        Sql.named('''
          INSERT INTO profiles (user_id, height_cm, birth_year, sex, activity_level, setup_date,
                                onboarding_step, disclaimer_accepted_at, onboarding_completed_at,
                                calorie_mode, calorie_kcal, timezone, server_version,
                                client_updated_at)
          VALUES (@u, 172, 1994, 'male', 'moderate', '2026-11-01', 5, now(), now(), 'auto',
                  2210, 'Asia/Ho_Chi_Minh', 1, now())'''),
        parameters: {'u': userA},
      );
      // 18:30 giờ Việt Nam: trong cửa sổ ghi tạ của buổi 18:00 (ghi chú,
      // VS-35).
      final at = DateTime.utc(2026, 11, 12, 11, 30);
      final pushed = await app.push(a, [
        mutation(
          SyncEntities.exerciseUnit,
          'chest-mid-machine-pec-deck',
          SyncOp.upsert,
          at: at,
          data: const ExerciseUnitCodec().encode(
            ExerciseUnit(
              exerciseId: 'chest-mid-machine-pec-deck',
              unit: LiftUnit.steps,
              changedOn: LocalDate(2026, 11, 12),
            ),
          ),
        ),
        mutation(
          SyncEntities.exerciseNote,
          '2026-11-12:chest-mid-machine-pec-deck',
          SyncOp.upsert,
          at: at,
          data: const ExerciseNoteCodec().encode(
            ExerciseNote(
              date: LocalDate(2026, 11, 12),
              exerciseId: 'chest-mid-machine-pec-deck',
              text: 'máy 2 hỏng, tập máy 5',
            ),
          ),
        ),
        mutation(
          SyncEntities.exerciseUnit,
          'chest-mid-machine-pec-deck',
          SyncOp.upsert,
          at: at,
          data: const {
            'exerciseId': 'chest-mid-machine-pec-deck',
            'unit': 'plates',
            'changedOn': '2026-11-12',
          },
        ),
      ]);
      expect(pushed.results.map((r) => r.status), [
        PushStatus.applied,
        PushStatus.applied,
        PushStatus.rejected,
      ]);
      expect(pushed.results.last.field, 'unit');

      final mine = (await app.pull(a)).changes;
      final unit = mine.singleWhere(
        (c) => c.entity == SyncEntities.exerciseUnit,
      );
      expect(
        const ExerciseUnitCodec().decode(unit.key, unit.data!).unit,
        LiftUnit.steps,
      );
      final note = mine.singleWhere(
        (c) => c.entity == SyncEntities.exerciseNote,
      );
      expect(note.data!['text'], 'máy 2 hỏng, tập máy 5');

      final theirs = (await app.pull(b)).changes;
      expect(
        theirs.where(
          (c) =>
              c.entity == SyncEntities.exerciseUnit ||
              c.entity == SyncEntities.exerciseNote,
        ),
        isEmpty,
      );

      final deleted = await app.push(a, [
        mutation(
          SyncEntities.exerciseNote,
          '2026-11-12:chest-mid-machine-pec-deck',
          SyncOp.delete,
          at: at.add(const Duration(minutes: 1)),
        ),
      ]);
      expect(deleted.results.single.status, PushStatus.applied);
      final after = (await app.pull(
        a,
      )).changes.singleWhere((c) => c.entity == SyncEntities.exerciseNote);
      expect((after.deleted, after.data), (true, null));
      final stored = await app.tdb.pool.execute(
        "SELECT text FROM exercise_notes WHERE NOT (text = '')",
      );
      expect(stored, isEmpty, reason: 'nội dung ghi chú đã xóa không còn');
    });
  });
}
