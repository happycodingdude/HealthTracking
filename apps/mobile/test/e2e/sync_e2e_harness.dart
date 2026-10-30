import 'dart:io';

import 'package:api_contract/api_contract.dart';
import 'package:domain/domain.dart';
import 'package:drift/drift.dart'
    show
        Insertable,
        QueryExecutor,
        Table,
        TableInfo,
        Variable,
        driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:mobile/data/api/api_client.dart';
import 'package:mobile/data/api/app_version_interceptor.dart';
import 'package:mobile/data/auth/auth_interceptor.dart';
import 'package:mobile/data/auth/auth_repository.dart';
import 'package:mobile/data/auth/session_store.dart';
import 'package:mobile/data/auth/token_manager.dart';
import 'package:mobile/data/db/app_database.dart';
import 'package:mobile/data/local_marks.dart';
import 'package:mobile/data/sync/local_stores.dart';
import 'package:mobile/data/sync/outbox_writer.dart';
import 'package:mobile/data/sync/sync_api.dart';
import 'package:mobile/data/sync/sync_engine.dart';
import 'package:mobile/data/sync/sync_status.dart';
import 'package:mobile/features/library/data/exercise_repository.dart';
import 'package:mobile/features/me/application/calorie_updates.dart';
import 'package:mobile/features/me/application/update_display_name.dart';
import 'package:mobile/features/me/data/account_repository.dart';
import 'package:mobile/features/me/data/profile_repository.dart';
import 'package:mobile/features/menu/data/menu_api.dart';
import 'package:mobile/features/menu/data/menu_repository.dart';
import 'package:mobile/features/onboarding/application/onboarding_steps.dart';
import 'package:mobile/features/onboarding/data/onboarding_draft_repository.dart';
import 'package:mobile/features/schedule/application/month_materializer.dart';
import 'package:mobile/features/schedule/data/schedule_repository.dart';
import 'package:mobile/features/today/application/mark_session.dart';
import 'package:mobile/features/weight/application/weight_edits.dart';
import 'package:mobile/features/weight/data/weight_repository.dart';
import 'package:mobile/features/workout/application/lift_log_edits.dart';
import 'package:mobile/features/workout/data/exercise_note_repository.dart';
import 'package:mobile/features/workout/data/exercise_unit_repository.dart';
import 'package:mobile/features/workout/data/lift_log_repository.dart';
import 'package:server/server.dart';
import 'package:server/testing.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;

import '../support/fake_sync.dart';
import '../support/version_fixture.dart';

/// Bộ khung `sync_e2e` (06 VS02-T13): server thật (PostgreSQL + HTTP) và nhiều
/// "máy" chạy SyncEngine thật với Drift. Slice sau thêm entity vào [E2eDevice].
/// Mật khẩu chung của các tài khoản thử (mọi máy đăng nhập cùng tài khoản).
final _password = randomTestPassword();

final class E2eServer {
  E2eServer._(this.tdb, this._http);

  static Future<E2eServer> start() async {
    final tdb = await TestDatabase.create();
    final deps = AppDeps(
      db: tdb.db,
      logger: Logger((_) {}),
      clock: const SystemClock(),
      jwtSecret: randomTestSecret(),
      bcryptCost: 4,
    );
    final http = await shelf_io.serve(
      buildApp(deps),
      InternetAddress.loopbackIPv4,
      0,
    );
    return E2eServer._(tdb, http);
  }

  final TestDatabase tdb;
  final HttpServer _http;

  String get baseUrl => 'http://127.0.0.1:${_http.port}';

  Future<void> stop() async {
    await _http.close(force: true);
    await tdb.dispose();
  }
}

/// Một iPhone: database riêng, phiên riêng, đồng hồ riêng (giờ trên máy).
/// Đồng bộ chỉ chạy khi gọi [sync] — giữa các lần gọi coi như không có mạng.
final class E2eDevice {
  E2eDevice(
    this.server, {
    DateTime? now,
    QueryExecutor? executor,
    SyncApi Function(SyncApi api)? wrapSyncApi,
  }) : clock = FixedClock(now ?? DateTime.now()),
       db = AppDatabase(executor ?? NativeDatabase.memory()) {
    // Mỗi máy có executor riêng nên không tranh chấp; tắt cảnh báo của Drift
    // về việc tạo AppDatabase nhiều lần.
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    final public = ApiClient.create(server.baseUrl)
      ..dio.interceptors.add(AppVersionInterceptor(appVersionV4));
    tokens = TokenManager(
      store: store,
      clock: clock,
      refreshCall: (rt) => AuthRepository.refreshWith(public, rt),
    );
    api = ApiClient.create(server.baseUrl);
    api.dio.interceptors
      ..add(AppVersionInterceptor(appVersionV4))
      ..add(AuthInterceptor(api.dio, tokens));
    auth = AuthRepository(api: api, tokens: tokens, store: store);
    accounts = AccountRepository(db);
    profiles = ProfileRepository(db);
    weights = WeightRepository(db);
    schedule = ScheduleRepository(db);
    menus = MenuRepository(db);
    exercises = ExerciseRepository(db);
    liftLogs = LiftLogRepository(db);
    final outbox = OutboxWriter(db, clock);
    onboarding = OnboardingSteps(
      db: db,
      profiles: profiles,
      weights: weights,
      drafts: OnboardingDraftRepository(db),
      schedule: schedule,
      outbox: outbox,
      clock: clock,
    );
    markDone = MarkSessionDone(
      db: db,
      schedule: schedule,
      outbox: outbox,
      clock: clock,
    );
    markSkipped = MarkSessionSkipped(
      db: db,
      schedule: schedule,
      liftLogs: liftLogs,
      outbox: outbox,
      clock: clock,
    );
    addExtra = AddExtraSession(
      db: db,
      schedule: schedule,
      outbox: outbox,
      clock: clock,
    );
    saveLift = SaveLiftLog(
      db: db,
      logs: liftLogs,
      schedule: schedule,
      exercises: exercises,
      outbox: outbox,
      clock: clock,
      units: units,
    );
    saveNote = SaveExerciseNote(
      db: db,
      notes: notes,
      schedule: schedule,
      exercises: exercises,
      outbox: outbox,
      clock: clock,
    );
    deleteLift = DeleteLiftLog(
      db: db,
      logs: liftLogs,
      schedule: schedule,
      exercises: exercises,
      outbox: outbox,
      clock: clock,
    );
    materializer = MonthMaterializer(
      db: db,
      schedule: schedule,
      outbox: outbox,
      clock: clock,
    );
    weightEdits = WeightEdits(
      db: db,
      weights: weights,
      profiles: profiles,
      outbox: outbox,
      calorie: CalorieUpdates(
        db: db,
        profiles: profiles,
        weights: weights,
        outbox: outbox,
        marks: MemoryLocalMarks(),
        clock: clock,
      ),
      clock: clock,
    );
    menuApi = HttpMenuApi(api);
    final syncApi = HttpSyncApi(api);
    engine = SyncEngine(
      db: db,
      api: wrapSyncApi == null ? syncApi : wrapSyncApi(syncApi),
      stores: {
        SyncEntities.account: AccountStore(accounts),
        SyncEntities.profile: ProfileStore(profiles),
        SyncEntities.weight: WeightStore(weights),
        SyncEntities.weeklyTemplate: WeeklyTemplateStore(schedule),
        SyncEntities.monthPlan: MonthPlanStore(schedule),
        SyncEntities.day: DayStore(schedule),
        SyncEntities.menu: MenuStore(menus),
        SyncEntities.aiDailyUsage: AiDailyUsageStore(menus),
        SyncEntities.exercise: ExerciseStore(exercises),
        SyncEntities.liftLog: LiftLogStore(liftLogs),
        SyncEntities.exerciseUnit: ExerciseUnitStore(units),
        SyncEntities.exerciseNote: ExerciseNoteStore(notes),
      },
      clock: clock,
      reporter: reporter,
      scheduler: FakeScheduler(),
    );
  }

  final E2eServer server;
  final FixedClock clock;
  final AppDatabase db;
  final store = MemorySessionStore();
  final reporter = RecordingReporter();
  late final TokenManager tokens;
  late final ApiClient api;
  late final AuthRepository auth;
  late final AccountRepository accounts;
  late final ProfileRepository profiles;
  late final WeightRepository weights;
  late final ScheduleRepository schedule;
  late final MenuRepository menus;
  late final ExerciseRepository exercises;
  late final LiftLogRepository liftLogs;
  late final ExerciseUnitRepository units = ExerciseUnitRepository(db);
  late final ExerciseNoteRepository notes = ExerciseNoteRepository(db);
  late final SaveLiftLog saveLift;
  late final SaveExerciseNote saveNote;
  late final DeleteLiftLog deleteLift;
  late final MarkSessionDone markDone;
  late final MarkSessionSkipped markSkipped;
  late final AddExtraSession addExtra;
  late final MonthMaterializer materializer;
  late final WeightEdits weightEdits;
  late final MenuApi menuApi;

  /// Các bước thiết lập lần đầu qua use case thật (VS-03).
  late final OnboardingSteps onboarding;
  late final SyncEngine engine;

  Future<void> register({
    String phone = '0912345678',
    String name = 'Minh',
  }) async {
    final me = await auth.register(
      RegisterRequest(displayName: name, phone: phone, password: _password),
    );
    await accounts.put(me.displayName);
  }

  Future<MeResponse> login({String phone = '0912345678'}) async {
    final me = await auth.login(
      LoginRequest(phone: phone, password: _password),
    );
    await accounts.put(me.displayName);
    return me;
  }

  /// Đổi tên qua use case thật (bản ghi + outbox).
  Future<void> rename(String name) async {
    final ok = await UpdateDisplayName(db, accounts, OutboxWriter(db, clock))(
      name,
    );
    if (!ok) throw StateError('tên không hợp lệ');
  }

  Future<String?> displayName() => accounts.watchDisplayName().first;

  Future<SyncStatus> status() => watchSyncStatus(db).first;

  Future<SyncOutcome> sync() => engine.syncNow();

  /// S-07: khôi phục từ cursor đã nhận đến hết (VS-14).
  Future<void> restore({void Function(double)? onProgress}) =>
      engine.restore(onProgress: onProgress);

  /// Toàn bộ dữ liệu của Bạn trên máy (TAC-04): mọi bảng bản sao entity và
  /// ngân sách AI của tháng; bỏ hàng đợi gửi, nháp thiết lập, cursor.
  Future<Map<String, Object?>> snapshot() async {
    Future<List<Map<String, Object?>>> rows(TableInfo<Table, Object?> t) async {
      final all = [
        for (final r in await db.select(t).get())
          (r! as Insertable<Object?>)
              .toColumns(false)
              .map(
                (k, v) => MapEntry(k, v is Variable ? v.value : v.toString()),
              ),
      ];
      all.sort((a, b) => '$a'.compareTo('$b'));
      return all;
    }

    return {
      for (final t in <TableInfo<Table, Object?>>[
        db.account,
        db.profiles,
        db.weights,
        db.weeklyTemplates,
        db.monthPlans,
        db.days,
        db.menus,
        db.aiDailyUsage,
        db.exercises,
        db.liftLogs,
      ])
        t.actualTableName: await rows(t),
      'aiBudget': (await db.select(db.syncState).getSingle()).aiBudget,
    };
  }

  Future<void> close() async {
    engine.stop();
    await db.close();
  }
}
