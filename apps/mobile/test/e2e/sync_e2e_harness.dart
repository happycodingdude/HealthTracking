import 'dart:io';

import 'package:api_contract/api_contract.dart';
import 'package:domain/domain.dart';
import 'package:drift/drift.dart' show QueryExecutor, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:mobile/data/api/api_client.dart';
import 'package:mobile/data/auth/auth_interceptor.dart';
import 'package:mobile/data/auth/auth_repository.dart';
import 'package:mobile/data/auth/session_store.dart';
import 'package:mobile/data/auth/token_manager.dart';
import 'package:mobile/data/db/app_database.dart';
import 'package:mobile/data/sync/local_stores.dart';
import 'package:mobile/data/sync/outbox_writer.dart';
import 'package:mobile/data/sync/sync_api.dart';
import 'package:mobile/data/sync/sync_engine.dart';
import 'package:mobile/data/sync/sync_status.dart';
import 'package:mobile/features/me/application/update_display_name.dart';
import 'package:mobile/features/me/data/account_repository.dart';
import 'package:mobile/features/me/data/profile_repository.dart';
import 'package:mobile/features/onboarding/application/onboarding_steps.dart';
import 'package:mobile/features/onboarding/data/onboarding_draft_repository.dart';
import 'package:mobile/features/weight/data/weight_repository.dart';
import 'package:server/server.dart';
import 'package:server/testing.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;

import '../support/fake_sync.dart';

/// Bộ khung `sync_e2e` (06 VS02-T13): server thật (PostgreSQL + HTTP) và nhiều
/// "máy" chạy SyncEngine thật với Drift. Slice sau thêm entity vào [E2eDevice].
final class E2eServer {
  E2eServer._(this.tdb, this._http);

  static Future<E2eServer> start() async {
    final tdb = await TestDatabase.create();
    final deps = AppDeps(
      db: tdb.db,
      logger: Logger((_) {}),
      clock: const SystemClock(),
      jwtSecret: 'e2e-secret-e2e-secret-e2e-secret-e2e',
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
  E2eDevice(this.server, {DateTime? now, QueryExecutor? executor})
    : clock = FixedClock(now ?? DateTime.now()),
      db = AppDatabase(executor ?? NativeDatabase.memory()) {
    // Mỗi máy có executor riêng nên không tranh chấp; tắt cảnh báo của Drift
    // về việc tạo AppDatabase nhiều lần.
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    final public = ApiClient.create(server.baseUrl);
    tokens = TokenManager(
      store: store,
      clock: clock,
      refreshCall: (rt) => AuthRepository.refreshWith(public, rt),
    );
    api = ApiClient.create(server.baseUrl);
    api.dio.interceptors.add(AuthInterceptor(api.dio, tokens));
    auth = AuthRepository(api: api, tokens: tokens, store: store);
    accounts = AccountRepository(db);
    profiles = ProfileRepository(db);
    weights = WeightRepository(db);
    onboarding = OnboardingSteps(
      db: db,
      profiles: profiles,
      weights: weights,
      drafts: OnboardingDraftRepository(db),
      outbox: OutboxWriter(db, clock),
      clock: clock,
    );
    engine = SyncEngine(
      db: db,
      api: HttpSyncApi(api),
      stores: {
        SyncEntities.account: AccountStore(accounts),
        SyncEntities.profile: ProfileStore(profiles),
        SyncEntities.weight: WeightStore(weights),
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

  /// Các bước thiết lập lần đầu qua use case thật (VS-03).
  late final OnboardingSteps onboarding;
  late final SyncEngine engine;

  Future<void> register({
    String phone = '0912345678',
    String name = 'Minh',
  }) async {
    final me = await auth.register(
      RegisterRequest(displayName: name, phone: phone, password: 'matkhau123'),
    );
    await accounts.put(me.displayName);
  }

  Future<MeResponse> login({String phone = '0912345678'}) async {
    final me = await auth.login(
      LoginRequest(phone: phone, password: 'matkhau123'),
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

  Future<void> close() async {
    engine.stop();
    await db.close();
  }
}
