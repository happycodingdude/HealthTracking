// compat_e2e (06 Bản 3 VS32-T08, IR3-10, TAC3-01): app 2.x đã phát hành với
// server Bản 3. File này KHÔNG chạy trong cây code hiện tại: tool/compat_e2e.sh
// chép nó vào bản code của app 2.x (commit đã lên TestFlight, build 2.0.0) và
// chạy bằng chính contract, SyncEngine, Drift của bản đó, gọi tới server Bản 3
// chạy ở tiến trình riêng.
//
// Biến môi trường (tool/compat_e2e.sh đặt):
//   COMPAT_SERVER_URL    server Bản 3, ví dụ http://127.0.0.1:18090
//   COMPAT_DATABASE_URL  database của server đó (đọc, ghi dữ liệu thử)
import 'dart:io';

import 'package:api_contract/api_contract.dart';
import 'package:dio/dio.dart';
import 'package:domain/domain.dart';
import 'package:domain/testing.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/data/api/api_client.dart';
import 'package:mobile/data/api/app_version_interceptor.dart';
import 'package:mobile/data/auth/auth_interceptor.dart';
import 'package:mobile/data/auth/auth_repository.dart';
import 'package:mobile/data/auth/session_store.dart';
import 'package:mobile/data/auth/token_manager.dart';
import 'package:mobile/data/db/app_database.dart';
import 'package:mobile/data/sync/local_stores.dart';
import 'package:mobile/data/sync/sync_api.dart';
import 'package:mobile/data/sync/sync_engine.dart';
import 'package:mobile/features/library/data/exercise_repository.dart';
import 'package:mobile/features/me/data/account_repository.dart';
import 'package:mobile/features/me/data/profile_repository.dart';
import 'package:mobile/features/menu/data/menu_repository.dart';
import 'package:mobile/features/schedule/data/schedule_repository.dart';
import 'package:mobile/features/weight/data/weight_repository.dart';
import 'package:mobile/features/workout/data/lift_log_repository.dart';
import 'package:postgres/postgres.dart';
import 'package:server/server.dart' show LibraryFile, LibraryImporter;

import 'support/fake_sync.dart';

final _serverUrl = Platform.environment['COMPAT_SERVER_URL']!;
final _password = randomTestPassword();

/// Một iPhone chạy app 2.x. [version] = null: không gửi `X-App-Version`.
final class V2Device {
  V2Device({AppVersion? version = AppVersion.v2})
    : db = AppDatabase(NativeDatabase.memory()) {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    final public = ApiClient.create(_serverUrl);
    if (version != null) {
      public.dio.interceptors.add(AppVersionInterceptor(version));
    }
    tokens = TokenManager(
      store: store,
      clock: clock,
      refreshCall: (rt) => AuthRepository.refreshWith(public, rt),
    );
    api = ApiClient.create(_serverUrl);
    if (version != null) {
      api.dio.interceptors.add(AppVersionInterceptor(version));
    }
    api.dio.interceptors.add(AuthInterceptor(api.dio, tokens));
    auth = AuthRepository(api: api, tokens: tokens, store: store);
    accounts = AccountRepository(db);
    exercises = ExerciseRepository(db);
    final schedule = ScheduleRepository(db);
    final menus = MenuRepository(db);
    syncApi = HttpSyncApi(api);
    engine = SyncEngine(
      db: db,
      api: syncApi,
      stores: {
        SyncEntities.account: AccountStore(accounts),
        SyncEntities.profile: ProfileStore(ProfileRepository(db)),
        SyncEntities.weight: WeightStore(WeightRepository(db)),
        SyncEntities.weeklyTemplate: WeeklyTemplateStore(schedule),
        SyncEntities.monthPlan: MonthPlanStore(schedule),
        SyncEntities.day: DayStore(schedule),
        SyncEntities.menu: MenuStore(menus),
        SyncEntities.aiDailyUsage: AiDailyUsageStore(menus),
        SyncEntities.exercise: ExerciseStore(exercises),
        SyncEntities.liftLog: LiftLogStore(LiftLogRepository(db)),
      },
      clock: clock,
      reporter: reporter,
      scheduler: FakeScheduler(),
    );
  }

  final AppDatabase db;
  final clock = FixedClock(DateTime.now());
  final store = MemorySessionStore();
  final reporter = RecordingReporter();
  late final TokenManager tokens;
  late final ApiClient api;
  late final AuthRepository auth;
  late final AccountRepository accounts;
  late final ExerciseRepository exercises;
  late final SyncApi syncApi;
  late final SyncEngine engine;

  Future<void> register(String phone) => auth.register(
    RegisterRequest(displayName: 'Minh', phone: phone, password: _password),
  );

  Future<void> login(String phone) =>
      auth.login(LoginRequest(phone: phone, password: _password));

  Future<int> cursor() async =>
      (await db.select(db.syncState).getSingle()).cursor;

  Future<Set<String>> exerciseIds() async => {
    for (final r in await db.select(db.exercises).get()) r.id,
  };

  Future<void> close() async {
    engine.stop();
    await db.close();
  }
}

void main() {
  late Connection sql;
  final phone = '09${DateTime.now().millisecondsSinceEpoch % 100000000}'
      .padRight(10, '0')
      .substring(0, 10);

  Future<String> userId() async =>
      (await sql.execute(
            Sql.named('SELECT id FROM users WHERE phone = @p'),
            parameters: {'p': phone},
          )).single[0]!
          as String;

  /// Thay đổi hợp lệ app 2.x áp dụng được: tên hiển thị (entity `account`).
  Future<void> rename(String name) async => sql.execute(
    Sql.named(
      "UPDATE users SET display_name = @n, server_version = nextval('sync_version_seq') "
      'WHERE phone = @p',
    ),
    parameters: {'n': name, 'p': phone},
  );

  setUpAll(() async {
    // Test này gọi server thật qua mạng (như sync_e2e).
    HttpOverrides.global = null;
    sql = await Connection.openFromUrl(
      Platform.environment['COMPAT_DATABASE_URL']!,
    );
    // Thư viện 29 bài như production Bản 2: nạp bằng chính lệnh của server
    // 2.x (database đã chạy migration của Bản 3, cột mới có giá trị mặc định).
    final count =
        (await sql.execute('SELECT count(*) FROM exercises')).single[0]! as int;
    if (count == 0) {
      final report = await LibraryImporter(sql).run(
        LibraryFile.parse(File('../../data/exercises.json').readAsStringSync()),
      );
      expect(report.ok, isTrue, reason: report.describe());
    }
  });
  tearDownAll(() => sql.close());

  test('TA3-11 (TAC3-01 phần khung): pull có exercise_unit, exercise_note xen '
      'giữa thay đổi hợp lệ và tombstone exercise → không lỗi, cursor tiến '
      'hết, dữ liệu còn nguyên', () async {
    final a = V2Device();
    addTearDown(a.close);
    await a.register(phone);
    expect(await a.engine.syncNow(), SyncOutcome.synced);
    expect(await a.exerciseIds(), hasLength(29));

    final user = await userId();
    await rename('Minh A');
    // 2 entity Bản 3 (máy khác chạy app 3.0.0 ghi), xen giữa.
    await sql.execute(
      Sql.named('''
        INSERT INTO days (user_id, date, kind, time, muscles, server_version, client_updated_at)
        VALUES (@u, '2026-11-02', 'workout', '18:00', ARRAY['chest']::muscle_group[],
                nextval('sync_version_seq'), now());
        '''),
      parameters: {'u': user},
    );
    await sql.execute(
      Sql.named('''
        INSERT INTO exercise_units (user_id, exercise_id, unit, changed_on,
                                    client_updated_at, server_version)
        VALUES (@u, 'chest-mid-machine-pec-deck', 'steps', '2026-11-02', now(),
                nextval('sync_version_seq'))'''),
      parameters: {'u': user},
    );
    await sql.execute(
      Sql.named('''
        INSERT INTO exercise_notes (user_id, date, exercise_id, text, logged_at,
                                    client_updated_at, server_version)
        VALUES (@u, '2026-11-02', 'chest-mid-machine-pec-deck', 'máy 2 hỏng', now(),
                now(), nextval('sync_version_seq'))'''),
      parameters: {'u': user},
    );
    await rename('Minh B');
    // Tombstone `exercise` của một bài bỏ (như `library purge`).
    await sql.execute('''
      UPDATE exercises SET deleted = true, active = false,
             server_version = nextval('sync_version_seq')
      WHERE id = 'biceps-free-weight-dumbbell-biceps-curl' ''');
    await rename('Minh C');

    expect(await a.engine.syncNow(), SyncOutcome.synced);
    expect(a.reporter.reasons, isEmpty);
    expect(await a.accounts.watchDisplayName().first, 'Minh C');
    final ids = await a.exerciseIds();
    expect(ids, hasLength(28));
    expect(ids, isNot(contains('biceps-free-weight-dumbbell-biceps-curl')));
    final rest = await a.syncApi.pull(cursor: await a.cursor());
    expect(rest.changes, isEmpty);
    expect(rest.hasMore, isFalse);
  });

  test('TD3-21: dòng exercise không equipment (kiểu nạp Bản 3) và bài Chân '
      'xen giữa thay đổi hợp lệ → app 2.x (có và không có header) không nhận, '
      'không lỗi, cursor tiến hết; request 3.0.0 nhận đủ, dạng Bản 3', () async {
    final a = V2Device();
    addTearDown(a.close);
    await a.login(phone);
    expect(await a.engine.syncNow(), SyncOutcome.synced);
    final before = await a.exerciseIds();

    await sql.execute('''
      UPDATE exercises SET equipment = NULL, sort_in_group = 1,
             name_vi = 'Máy ép ngực', server_version = nextval('sync_version_seq')
      WHERE id = 'chest-mid-machine-pec-deck' ''');
    await rename('Minh D');
    await sql.execute(
      '''
      INSERT INTO exercises (id, muscle_group, muscle_region, logs_weight, name_vi,
                             youtube_video_id, video_channel, video_duration_s,
                             guide_steps, guide_safety, approved_at, sort_in_group,
                             sort_order, library_version, server_version)
      VALUES ('legs-quads-leg-press', 'legs', 'quads', true, 'Nằm máy đạp chân',
              'abcdefghijk', 'Kênh', 40, ARRAY['a','b','c'], ARRAY['a','b'],
              '2026-10-21', 1, 701, 2, nextval('sync_version_seq'))
      ON CONFLICT (id) DO UPDATE SET server_version = EXCLUDED.server_version''',
    );
    final legsVersion =
        (await sql.execute(
              "SELECT server_version FROM exercises WHERE id = 'legs-quads-leg-press'",
            )).single[0]!
            as int;

    expect(await a.engine.syncNow(), SyncOutcome.synced);
    expect(a.reporter.reasons, isEmpty);
    expect(await a.accounts.watchDisplayName().first, 'Minh D');
    expect(await a.exerciseIds(), before, reason: 'không thêm, không mất bài');
    final kept = await a.exercises.get('chest-mid-machine-pec-deck');
    expect(kept!.equipment, Equipment.machine, reason: 'giữ bản Bản 2');
    expect(await a.cursor(), greaterThanOrEqualTo(legsVersion));

    // Máy 2.x không gửi header, khôi phục từ đầu.
    final b = V2Device(version: null);
    addTearDown(b.close);
    await b.login(phone);
    await b.engine.restore();
    expect(b.reporter.reasons, isEmpty);
    final ids = await b.exerciseIds();
    expect(ids, isNot(contains('legs-quads-leg-press')));
    expect(ids, isNot(contains('chest-mid-machine-pec-deck')));
    expect(ids, isNot(contains('biceps-free-weight-dumbbell-biceps-curl')));
    expect(ids, hasLength(27));

    // Cùng database, request của app 3.0.0: mọi dòng, dạng Bản 3.
    final http = Dio(BaseOptions(baseUrl: _serverUrl));
    final login = await http.post<Map<String, Object?>>(
      '/v1/auth/login',
      data: {'phone': phone, 'password': _password},
    );
    final token = login.data!['accessToken']! as String;
    final pulled = await http.get<Map<String, Object?>>(
      '/v1/sync/pull',
      queryParameters: {'cursor': 0, 'limit': 500},
      options: Options(
        headers: {'Authorization': 'Bearer $token', AppVersion.header: '3.0.0'},
      ),
    );
    final changes = [
      for (final c in pulled.data!['changes']! as List)
        if ((c as Map)['entity'] == 'exercise') c,
    ];
    final legs = changes.singleWhere((c) => c['key'] == 'legs-quads-leg-press');
    final data = (legs['data']! as Map).cast<String, Object?>();
    expect((data['muscleGroup'], data['sortInGroup']), ('legs', 1));
    expect(data.containsKey('equipment'), isFalse);
    expect(changes, hasLength(30));
  });
}
