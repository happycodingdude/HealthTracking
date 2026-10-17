import 'dart:convert';

import 'package:api_contract/api_contract.dart';
import 'package:domain/domain.dart';
import 'package:server/server.dart';
import 'package:server/testing.dart';
import 'package:shelf/shelf.dart';
import 'package:uuid/uuid.dart';

import 'test_item_handler.dart';

final testJwtSecret = randomTestSecret();

/// Phản hồi đã giải mã JSON.
final class TestResponse {
  TestResponse(this.status, this.json, this.headers);
  final int status;
  final Object? json;
  final Map<String, String> headers;

  Map<String, Object?> get body => json! as Map<String, Object?>;

  /// Mã lỗi khi thân là `{"error": {...}}`.
  String? get errorCode => (body['error'] as Map?)?['code'] as String?;
  String? get errorField => (body['error'] as Map?)?['field'] as String?;
}

/// API chạy trong tiến trình test với PostgreSQL thật và [FixedClock].
final class TestApp {
  TestApp._(this.tdb, this.clock, this.deps, this.log, this.ai)
    : handler = buildApp(deps);

  /// [withTestItems] = true: thêm entity `test_item` (upsert/ensure/delete)
  /// để kiểm lớp đồng bộ chung.
  static Future<TestApp> create({
    DateTime? now,
    bool withTestItems = false,
    FakeAiProvider? ai,
    AiConfig aiConfig = const AiConfig(),
  }) async {
    final tdb = await TestDatabase.create();
    if (withTestItems) await TestItemHandler.createTable(tdb.pool);
    final clock = FixedClock(now ?? DateTime.utc(2026, 10, 7, 10));
    final log = CapturingLogger();
    final deps = AppDeps(
      db: tdb.db,
      logger: log.logger,
      clock: clock,
      jwtSecret: testJwtSecret,
      bcryptCost: 4,
      trustProxy: true,
      syncHandlers: [
        ...defaultSyncHandlers,
        if (withTestItems) const TestItemHandler(),
      ],
      aiConfig: aiConfig,
      aiProvider: ai ??= FakeAiProvider(),
    );
    return TestApp._(tdb, clock, deps, log, ai);
  }

  final TestDatabase tdb;
  final FixedClock clock;
  final AppDeps deps;
  final CapturingLogger log;
  final Handler handler;

  /// Nhà cung cấp AI giả (ED-11), chỉnh kịch bản trong test.
  final FakeAiProvider ai;

  Future<TestResponse> send(
    String method,
    String path, {
    Object? body,
    String? token,
    Map<String, String>? headers,
  }) async {
    final res = await handler(
      Request(
        method,
        Uri.parse('http://localhost$path'),
        body: body == null ? null : (body is String ? body : jsonEncode(body)),
        headers: {
          'content-type': 'application/json',
          'x-forwarded-for': '10.0.0.1',
          'authorization': ?(token == null ? null : 'Bearer $token'),
          ...?headers,
        },
      ),
    );
    final text = await res.readAsString();
    return TestResponse(
      res.statusCode,
      text.isEmpty ? null : jsonDecode(text),
      res.headers,
    );
  }

  Future<TestResponse> post(
    String path,
    Object? body, {
    String? token,
    Map<String, String>? headers,
  }) => send('POST', path, body: body, token: token, headers: headers);

  Future<TestResponse> get(String path, {String? token}) =>
      send('GET', path, token: token);

  /// Đăng ký nhanh một tài khoản thử.
  Future<TokenPair> register({
    String phone = '0912345678',
    String name = 'Minh',
    String password = '***REMOVED***',
  }) async {
    final res = await post('/v1/auth/register', {
      'displayName': name,
      'phone': phone,
      'password': password,
    });
    if (res.status != 201) {
      throw StateError('register ${res.status} ${res.json}');
    }
    return TokenPair.fromJson(res.json);
  }

  Future<void> dispose() => tdb.dispose();
}

/// Tạo mutation thử.
SyncMutation mutation(
  String entity,
  String key,
  SyncOp op, {
  required DateTime at,
  Map<String, Object?>? data,
  String? id,
}) => SyncMutation(
  mutationId: id ?? const Uuid().v4(),
  entity: entity,
  key: key,
  op: op,
  clientUpdatedAt: at,
  data: data,
);

extension SyncCalls on TestApp {
  /// [appVersion] = header `X-App-Version` (null = như app Bản 1).
  Future<PushResponse> push(
    String token,
    List<SyncMutation> mutations, {
    AppVersion? appVersion,
  }) async {
    final res = await post(
      '/v1/sync/push',
      PushRequest(mutations).toJson(),
      token: token,
      headers: {AppVersion.header: ?appVersion?.toString()},
    );
    if (res.status != 200) throw StateError('push ${res.status} ${res.json}');
    return PushResponse.fromJson(res.json);
  }

  Future<PullResponse> pull(String token, {int cursor = 0, int? limit}) async {
    final res = await get(
      '/v1/sync/pull?cursor=$cursor${limit == null ? '' : '&limit=$limit'}',
      token: token,
    );
    if (res.status != 200) throw StateError('pull ${res.status} ${res.json}');
    return PullResponse.fromJson(res.json);
  }
}
