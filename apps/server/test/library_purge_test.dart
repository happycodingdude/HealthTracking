import 'package:api_contract/api_contract.dart';
import 'package:domain/domain.dart';
import 'package:postgres/postgres.dart';
import 'package:server/server.dart';
import 'package:server/src/jobs/maintenance.dart';
import 'package:server/testing.dart';
import 'package:test/test.dart';

import 'support/test_app.dart';

/// 06 Bản 3 VS34-T06: `library purge` (TAC3-05, TD3-08, TA3-04, D3-04).
void main() {
  late TestApp app;
  late String user;
  late LibraryPurge purge;

  setUp(() async {
    // 10:00 UTC 07/10/2026 = 17:00 ở Việt Nam.
    app = await TestApp.create();
    user = await V2DataSet.load(app.tdb.pool);
    purge = LibraryPurge(app.tdb.pool, app.clock);
  });
  tearDown(() => app.dispose());

  /// Toàn bộ dòng của các bảng purge chạm tới, để so "database không đổi".
  Future<List<List<Object?>>> snapshot() async => [
    for (final table in [
      'SELECT exercise_id, date::text, start_kg_x10, end_kg_x10, deleted, '
          'server_version FROM lift_logs ORDER BY 1, 2',
      'SELECT exercise_id, date::text, text, deleted, server_version '
          'FROM exercise_notes ORDER BY 1, 2',
      'SELECT id, active, deleted, server_version FROM exercises ORDER BY 1',
      'SELECT exercise_id, unit FROM exercise_units ORDER BY 1',
    ])
      for (final r in await app.tdb.pool.execute(table)) r.toList(),
  ];

  Future<void> addNote(String exerciseId, String date) => app.tdb.pool.execute(
    Sql.named('''
      INSERT INTO exercise_notes (user_id, date, exercise_id, text, logged_at,
                                  client_updated_at, server_version)
      VALUES (@u, @d::date, @e, 'ghế số 3', now(), now(),
              nextval('sync_version_seq'))'''),
    parameters: {'u': user, 'd': date, 'e': exerciseId},
  );

  test('ED3-04: 14 bài bỏ cố định trong purge khớp domain và đều có trong '
      'thư viện Bản 2', () {
    expect(LibraryPurge.removedIds, hasLength(14));
    expect(LibraryPurge.removedIds.toSet(), LibraryV3.removedV2Ids);
    final v2 = {for (final e in v2Library().exercises) e.id};
    expect(v2.containsAll(LibraryPurge.removedIds), isTrue);
    expect(v2.containsAll(LibraryV3.keptV2Ids), isTrue);
    expect(v2.length, 29);
  });

  test('--dry-run: bảng đủ 14 bài, đếm mức tạ, ghi chú chưa xóa; đơn vị sẽ '
      'tạo; không đổi gì', () async {
    await addNote('biceps-free-weight-dumbbell-biceps-curl', '2026-11-04');
    final before = await snapshot();
    final r = await purge.dryRun();
    expect(r.rows, hasLength(14));
    expect([for (final row in r.rows) row.id], LibraryPurge.removedIds);
    final incline = r.rows.first;
    expect(incline.nameVi, isNot(incline.id), reason: 'tên bài Bản 2');
    expect((incline.liftLogs, incline.notes), (2, 0));
    final curl = r.rows.firstWhere(
      (row) => row.id == 'biceps-free-weight-dumbbell-biceps-curl',
    );
    expect((curl.liftLogs, curl.notes), (2, 1));
    expect((r.liftLogs, r.notes, r.total), (4, 1, 5));
    expect((r.exercisesLeft, r.stepsUnits, r.kgUnits), (14, 2, 1));
    expect(r.table(), contains('| **Tổng** | **4** | **1** | **5** |'));
    expect(await snapshot(), before);
  });

  test('--confirm-count sai → từ chối, database không đổi', () async {
    final before = await snapshot();
    for (final wrong in [0, 3, 5]) {
      await expectLater(
        purge.apply(confirmCount: wrong),
        throwsA(
          isA<PurgeRefused>().having(
            (e) => e.message,
            'message',
            contains('khác tổng hiện tại 4'),
          ),
        ),
      );
    }
    expect(await snapshot(), before);
  });

  test('TAC3-05, LIB-AC24: --apply đúng tổng → tombstone đủ trong một lần, '
      'đơn vị theo loại bài Bản 2 (máy → nấc, tạ → kg), con số mức tạ bài giữ không đổi; '
      'mọi dòng đổi có version mới; máy nhận qua pull', () async {
    await addNote(
      'chest-upper-free-weight-incline-dumbbell-press',
      '2026-11-09',
    );
    final maxBefore =
        (await app.tdb.pool.execute(
              'SELECT last_value FROM sync_version_seq',
            )).single[0]!
            as int;
    final r = await purge.apply(confirmCount: 5);
    expect((r.liftLogs, r.notes, r.stepsUnits, r.kgUnits), (4, 1, 2, 1));

    final logs = await app.tdb.pool.execute(
      'SELECT exercise_id, start_kg_x10, end_kg_x10, deleted, server_version '
      'FROM lift_logs ORDER BY exercise_id, date',
    );
    for (final row in logs) {
      final removed = LibraryPurge.removedIds.contains(row[0]);
      expect(row[3], removed, reason: '${row[0]}');
      if (removed) {
        expect((row[1], row[2]), (null, null));
        expect(row[4]! as int, greaterThan(maxBefore));
      }
    }
    expect(
      [
        for (final row in logs)
          if (row[3] == false) (row[0], row[1], row[2]),
      ],
      [
        ('chest-mid-free-weight-flat-barbell-bench-press', 400, 450),
        ('chest-mid-machine-pec-deck', 70, 80),
        ('lats-machine-lat-pulldown', 60, 70),
      ],
      reason: 'TA3-05: số Bản 2 giữ nguyên, nấc đọc thẳng từ số thanh',
    );
    expect(
      (await app.tdb.pool.execute(
        'SELECT text, deleted FROM exercise_notes',
      )).single.toList(),
      ['', true],
    );
    final exercises = await app.tdb.pool.execute(
      Sql.named(
        'SELECT count(*) FILTER (WHERE deleted AND NOT active), count(*) '
        'FROM exercises WHERE id = ANY(@ids)',
      ),
      parameters: {'ids': LibraryPurge.removedIds},
    );
    expect(exercises.single.toList(), [14, 14]);
    expect(
      [
        for (final row in await app.tdb.pool.execute(
          'SELECT exercise_id, unit, changed_on::text FROM exercise_units '
          'ORDER BY 1',
        ))
          row.toList(),
      ],
      [
        ['chest-mid-free-weight-flat-barbell-bench-press', 'kg', '2026-10-07'],
        ['chest-mid-machine-pec-deck', 'steps', '2026-10-07'],
        ['lats-machine-lat-pulldown', 'steps', '2026-10-07'],
      ],
    );

    // Máy của tài khoản nhận tombstone và đơn vị qua pull (app 3.0.0 và 2.x).
    final token = app.deps.tokens.issueAccessToken(user).token;
    final v3 = (await app.pull(token)).changes;
    final tombstones = {
      for (final c in v3)
        if (c.deleted) '${c.entity}:${c.key}',
    };
    for (final id in LibraryPurge.removedIds) {
      expect(tombstones, contains('exercise:$id'));
    }
    expect(tombstones.where((t) => t.startsWith('lift_log:')), hasLength(4));
    expect(
      tombstones.where((t) => t.startsWith('exercise_note:')),
      hasLength(1),
    );
    expect(
      [
        for (final c in v3)
          if (c.entity == SyncEntities.exerciseUnit) c.data!['unit'],
      ]..sort(),
      ['kg', 'steps', 'steps'],
    );
    final legacy = (await app.pull(token, appVersion: AppVersion.v2)).changes;
    expect(
      [
        for (final c in legacy)
          if (c.entity == SyncEntities.exercise && c.deleted) c.key,
      ]..sort(),
      [...LibraryPurge.removedIds]..sort(),
    );
  });

  test('chạy lần hai → không có gì để xóa, database không đổi; lần đầu '
      'không có bản ghi nào vẫn gỡ 14 bài', () async {
    await purge.apply(confirmCount: 4);
    final before = await snapshot();
    final again = await purge.dryRun();
    expect(again.nothingToDo, isTrue);
    expect((await purge.apply(confirmCount: 0)).nothingToDo, isTrue);
    expect(await snapshot(), before);
    await expectLater(
      purge.apply(confirmCount: 4),
      throwsA(isA<PurgeRefused>()),
    );

    // Database chưa ai ghi: tổng 0 nhưng vẫn còn 14 bài để gỡ.
    final empty = await TestDatabase.create();
    addTearDown(empty.dispose);
    await insertV2Library(empty.pool);
    final fresh = LibraryPurge(empty.pool, app.clock);
    final preview = await fresh.dryRun();
    expect((preview.total, preview.exercisesLeft), (0, 14));
    expect(preview.nothingToDo, isFalse);
    await fresh.apply(confirmCount: 0);
    expect((await fresh.dryRun()).nothingToDo, isTrue);
  });

  test('§6.11.3: library import Bản 3 chạy trước purge (bài giữ đã ghi mất '
      'equipment) → --apply từ chối, database không đổi', () async {
    expect((await LibraryImporter(app.tdb.pool).run(library28())).ok, isTrue);
    final before = await snapshot();
    await expectLater(
      purge.apply(confirmCount: 4),
      throwsA(
        isA<PurgeRefused>().having(
          (e) => e.message,
          'message',
          allOf(
            contains('chest-mid-machine-pec-deck'),
            contains('lats-machine-lat-pulldown'),
          ),
        ),
      ),
    );
    expect(await snapshot(), before);
  });

  test('bài giữ đã có đơn vị (máy khác chạy 3.0.0 đã chọn) → không tạo '
      'thêm, giữ đơn vị đã chọn', () async {
    await app.tdb.pool.execute(
      Sql.named('''
        INSERT INTO exercise_units (user_id, exercise_id, unit, changed_on,
                                    client_updated_at, server_version)
        VALUES (@u, 'chest-mid-machine-pec-deck', 'kg', '2026-10-06', now(),
                nextval('sync_version_seq'))'''),
      parameters: {'u': user},
    );
    final r = await purge.apply(confirmCount: 4);
    expect((r.stepsUnits, r.kgUnits), (1, 1));
    expect(
      (await app.tdb.pool.execute(
        "SELECT unit FROM exercise_units WHERE exercise_id = 'chest-mid-machine-pec-deck'",
      )).single[0],
      'kg',
    );
  });

  test('TD3-08: job dọn dữ liệu xóa vật lý tombstone mức tạ, ghi chú quá 90 '
      'ngày; giữ tombstone mới và bản ghi còn hiệu lực', () async {
    await addNote('biceps-free-weight-dumbbell-biceps-curl', '2026-11-04');
    await purge.apply(confirmCount: 5);
    // Một nửa tombstone đã quá 90 ngày.
    await app.tdb.pool.execute('''
      UPDATE lift_logs SET updated_at = now() - interval '91 days'
      WHERE deleted AND date = '2026-11-02' ''');
    await app.tdb.pool.execute('''
      UPDATE exercise_notes SET updated_at = now() - interval '91 days' ''');
    final maintenance = Maintenance(app.tdb.pool, FixedClock(DateTime.now()));
    final removed = await maintenance.dailyCleanup();
    expect((removed.liftLogs, removed.exerciseNotes), (1, 1));
    final left = await app.tdb.pool.execute(
      'SELECT count(*) FILTER (WHERE deleted), count(*) FILTER (WHERE NOT deleted) '
      'FROM lift_logs',
    );
    expect(left.single.toList(), [3, 3]);
  });
}
