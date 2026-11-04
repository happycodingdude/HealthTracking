// compat_v4_e2e (06 Bản 5 ED5-11, VS60-T03, TAC5-01): app 4.0.0 đã phát hành
// với server Bản 5. File này KHÔNG chạy trong cây code hiện tại:
// tool/compat_v4_e2e.sh chép nó vào bản code của app 4.0.0 (tag
// mobile-v4.0.0) và chạy bằng chính contract, SyncEngine, Drift của bản đó,
// gọi tới server Bản 5 chạy ở tiến trình riêng.
//
// Biến môi trường (tool/compat_v4_e2e.sh đặt):
//   COMPAT_SERVER_URL    server Bản 5, ví dụ http://127.0.0.1:18091
//   COMPAT_DATABASE_URL  database của server đó (ghi dữ liệu Bản 5 thử)
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
import 'package:mobile/data/sync/outbox_writer.dart';
import 'package:mobile/data/sync/sync_api.dart';
import 'package:mobile/data/sync/sync_engine.dart';
import 'package:mobile/features/library/data/exercise_repository.dart';
import 'package:mobile/features/me/data/account_repository.dart';
import 'package:mobile/features/me/data/profile_repository.dart';
import 'package:mobile/features/menu/data/menu_repository.dart';
import 'package:mobile/features/schedule/data/schedule_repository.dart';
import 'package:mobile/features/weight/data/weight_repository.dart';
import 'package:mobile/features/workout/data/exercise_note_repository.dart';
import 'package:mobile/features/workout/data/exercise_unit_repository.dart';
import 'package:mobile/features/workout/data/lift_log_repository.dart';
import 'package:postgres/postgres.dart';

import 'support/fake_sync.dart';

final _serverUrl = Platform.environment['COMPAT_SERVER_URL']!;
final _password = randomTestPassword();
const _v4 = AppVersion(4, 0, 0);

/// Một iPhone chạy app 4.0.0 (gửi `X-App-Version: 4.0.0` như bản phát hành).
final class V4Device {
  V4Device() : db = AppDatabase(NativeDatabase.memory()) {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    final public = ApiClient.create(_serverUrl);
    public.dio.interceptors.add(AppVersionInterceptor(_v4));
    tokens = TokenManager(
      store: store,
      clock: clock,
      refreshCall: (rt) => AuthRepository.refreshWith(public, rt),
    );
    api = ApiClient.create(_serverUrl);
    api.dio.interceptors.add(AppVersionInterceptor(_v4));
    api.dio.interceptors.add(AuthInterceptor(api.dio, tokens));
    auth = AuthRepository(api: api, tokens: tokens, store: store);
    accounts = AccountRepository(db);
    schedule = ScheduleRepository(db);
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
        SyncEntities.exercise: ExerciseStore(ExerciseRepository(db)),
        SyncEntities.liftLog: LiftLogStore(LiftLogRepository(db)),
        SyncEntities.exerciseUnit: ExerciseUnitStore(
          ExerciseUnitRepository(db),
        ),
        SyncEntities.exerciseNote: ExerciseNoteStore(
          ExerciseNoteRepository(db),
        ),
      },
      clock: clock,
      reporter: reporter,
      scheduler: FakeScheduler(),
    );
    outbox = OutboxWriter(db, clock);
  }

  final AppDatabase db;
  final clock = FixedClock(DateTime.now());
  final store = MemorySessionStore();
  final reporter = RecordingReporter();
  late final TokenManager tokens;
  late final ApiClient api;
  late final AuthRepository auth;
  late final AccountRepository accounts;
  late final ScheduleRepository schedule;
  late final SyncApi syncApi;
  late final SyncEngine engine;
  late final OutboxWriter outbox;

  Future<void> register(String phone) => auth.register(
    RegisterRequest(displayName: 'Minh', phone: phone, password: _password),
  );

  Future<void> login(String phone) =>
      auth.login(LoginRequest(phone: phone, password: _password));

  Future<int> cursor() async =>
      (await db.select(db.syncState).getSingle()).cursor;

  Future<void> close() async {
    engine.stop();
    await db.close();
  }
}

/// Hôm nay theo giờ Việt Nam (múi giờ trong hồ sơ thử).
LocalDate _todayHcm() {
  final t = DateTime.now().toUtc().add(const Duration(hours: 7));
  return LocalDate(t.year, t.month, t.day);
}

/// Ngày tập đã qua gần nhất (không phải chủ nhật).
LocalDate _pastWorkoutDay() {
  var d = _todayHcm().addDays(-1);
  while (d.isSunday) {
    d = d.addDays(-1);
  }
  return d;
}

void main() {
  late Connection sql;
  final phone = '08${DateTime.now().millisecondsSinceEpoch % 100000000}'
      .padRight(10, '0')
      .substring(0, 10);
  final past = _pastWorkoutDay();
  final today = _todayHcm();

  Future<String> userId() async =>
      (await sql.execute(
            Sql.named('SELECT id FROM users WHERE phone = @p'),
            parameters: {'p': phone},
          )).single[0]!
          as String;

  Future<void> rename(String name) async => sql.execute(
    Sql.named(
      "UPDATE users SET display_name = @n, server_version = nextval('sync_version_seq') "
      'WHERE phone = @p',
    ),
    parameters: {'n': name, 'p': phone},
  );

  Future<int> maxVersion() async =>
      (await sql.execute('SELECT last_value FROM sync_version_seq')).single[0]!
          as int;

  setUpAll(() async {
    HttpOverrides.global = null;
    sql = await Connection.openFromUrl(
      Platform.environment['COMPAT_DATABASE_URL']!,
    );
  });
  tearDownAll(() => sql.close());

  test('TAC5-01 (pull): app 4.0.0 pull có session_exercise, exercise_feel, '
      'schedule_pause, gym_location và day.openedAt xen giữa thay đổi hợp lệ '
      '→ không lỗi, cursor tiến hết, dữ liệu Bản 4 còn nguyên', () async {
    final a = V4Device();
    addTearDown(a.close);
    await a.register(phone);
    expect(await a.engine.syncNow(), SyncOutcome.synced);

    final user = await userId();
    // Hồ sơ có múi giờ (máy 5.0.0 khác ghi), để server áp quy tắc theo ngày.
    await sql.execute(
      Sql.named(
        '''
        INSERT INTO profiles (user_id, onboarding_step, timezone, server_version, client_updated_at)
        VALUES (@u, 1, 'Asia/Ho_Chi_Minh', nextval('sync_version_seq'), now())''',
      ),
      parameters: {'u': user},
    );
    await sql.execute(
      Sql.named(
        '''
        INSERT INTO month_plans (user_id, month, start_date, template_hash,
                                 generated_at, server_version, client_updated_at)
        VALUES (@u, @m, @s, repeat('a', 64), now(), nextval('sync_version_seq'), now())''',
      ),
      parameters: {
        'u': user,
        'm': past.toKey().substring(0, 7),
        's': '${past.toKey().substring(0, 7)}-01',
      },
    );
    await rename('Minh A');
    // Dữ liệu Bản 5 (máy khác chạy app 5.0.0 ghi), xen giữa.
    await sql.execute(
      Sql.named('''
        INSERT INTO days (user_id, date, kind, time, muscles, opened_at,
                          server_version, client_updated_at)
        VALUES (@u, @d, 'workout', '18:00', ARRAY['chest']::muscle_group[],
                (@d::date + time '17:20') AT TIME ZONE 'Asia/Ho_Chi_Minh',
                nextval('sync_version_seq'), now())'''),
      parameters: {'u': user, 'd': past.toKey()},
    );
    await sql.execute(
      Sql.named('''
        INSERT INTO session_exercises (user_id, date, exercise_id, role,
          replaces_exercise_id, position, skipped, client_updated_at, server_version)
        VALUES (@u, @d, 'lats-machine-lat-pulldown', 'replacement',
                'chest-mid-machine-pec-deck', 1, false, now(), nextval('sync_version_seq')),
               (@u, @d, 'chest-mid-free-weight-flat-barbell-bench-press', 'original',
                NULL, 0, true, now(), nextval('sync_version_seq'))'''),
      parameters: {'u': user, 'd': past.toKey()},
    );
    await rename('Minh B');
    await sql.execute(
      Sql.named('''
        INSERT INTO exercise_feels (user_id, date, exercise_id, feel,
                                    client_updated_at, server_version)
        VALUES (@u, @d, 'lats-machine-lat-pulldown', 'medium', now(),
                nextval('sync_version_seq'))'''),
      parameters: {'u': user, 'd': past.toKey()},
    );
    await sql.execute(
      Sql.named(
        '''
        INSERT INTO schedule_pauses (id, user_id, start_date, end_date,
                                     client_updated_at, server_version)
        VALUES (gen_random_uuid(), @u, @a, @b, now(), nextval('sync_version_seq'))''',
      ),
      parameters: {
        'u': user,
        'a': today.addDays(1).toKey(),
        'b': today.addDays(4).toKey(),
      },
    );
    await sql.execute(
      Sql.named('''
        INSERT INTO gym_locations (user_id, lat, lng, saved_at, enabled,
                                   client_updated_at, server_version)
        VALUES (@u, 10.776889, 106.700806, now(), true, now(),
                nextval('sync_version_seq'))'''),
      parameters: {'u': user},
    );
    await rename('Minh C');
    final last = await maxVersion();

    expect(await a.engine.syncNow(), SyncOutcome.synced);
    expect(a.reporter.reasons, isEmpty);
    expect(await a.accounts.watchDisplayName().first, 'Minh C');
    expect(await a.cursor(), greaterThanOrEqualTo(last));
    final day = await a.schedule.day(past);
    expect(day, isNotNull, reason: 'day có openedAt vẫn nhận');
    expect(day!.muscles, [MuscleGroup.chest]);
    final rest = await a.syncApi.pull(cursor: await a.cursor());
    expect(rest.changes, isEmpty);
    expect(rest.hasMore, isFalse);

    // Cùng database, request của app 5.0.0: nhận đủ 4 entity mới.
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
        headers: {'Authorization': 'Bearer $token', AppVersion.header: '5.0.0'},
      ),
    );
    final entities = {
      for (final c in pulled.data!['changes']! as List)
        (c as Map)['entity'] as String,
    };
    expect(
      entities,
      containsAll([
        'session_exercise',
        'exercise_feel',
        'schedule_pause',
        'gym_location',
      ]),
    );
  });

  test('TAC5-01 (day_locked): app 4.0.0 đánh dấu "Không tập" cho buổi ngày đã '
      'qua (còn trong hạn 7 ngày của Bản 4) → server từ chối day_locked, app '
      'hoàn về bản trên server (FC5-12, TA-12)', () async {
    final a = V4Device();
    addTearDown(a.close);
    await a.login(phone);
    await a.engine.restore();
    final before = await a.schedule.day(past);
    expect(before, isNotNull);
    expect(before!.mark, isNull);

    final marked = before.withMark(DayMark.skipped, markedAt: a.clock.now());
    await a.schedule.putDay(marked);
    await a.outbox.enqueue(
      SyncEntities.day,
      past.toKey(),
      SyncOp.upsert,
      const DayCodec().encode(marked),
    );
    expect((await a.schedule.day(past))!.mark, DayMark.skipped);

    expect(await a.engine.syncNow(), SyncOutcome.synced);
    // App 4.0.0 không biết mã `day_locked` (đọc thành mã lạ) nhưng vẫn hoàn
    // về bản server và báo lỗi như mọi lần ghi bị từ chối.
    expect(a.reporter.reasons, contains('sync_rejected'));
    expect((await a.schedule.day(past))!.mark, isNull);
    expect(await a.db.select(a.db.outbox).get(), isEmpty);
    final server = await sql.execute(
      Sql.named('SELECT mark FROM days WHERE user_id = @u AND date = @d'),
      parameters: {'u': await userId(), 'd': past.toKey()},
    );
    expect(server.single[0], isNull);

    // Mã trên dây đúng là `day_locked` (app 4.0.0 chỉ thấy mã lạ).
    final http = Dio(BaseOptions(baseUrl: _serverUrl));
    final login = await http.post<Map<String, Object?>>(
      '/v1/auth/login',
      data: {'phone': phone, 'password': _password},
    );
    final pushed = await http.post<Map<String, Object?>>(
      '/v1/sync/push',
      data: {
        'mutations': [
          {
            'mutationId': '44444444-4444-4444-8444-444444444444',
            'entity': SyncEntities.day,
            'key': past.toKey(),
            'op': SyncOp.upsert.wire,
            'clientUpdatedAt': InstantCodec.encode(DateTime.now().toUtc()),
            'data': const DayCodec().encode(marked),
          },
        ],
      },
      options: Options(
        headers: {
          'Authorization': 'Bearer ${login.data!['accessToken']}',
          AppVersion.header: '4.0.0',
        },
      ),
    );
    final result = (pushed.data!['results']! as List).single as Map;
    expect((result['status'], result['code']), ('rejected', 'day_locked'));
  });
}
