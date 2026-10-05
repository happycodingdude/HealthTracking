import 'dart:convert';

import 'package:api_contract/api_contract.dart';
import 'package:domain/domain.dart';
import 'package:server/server.dart';
import 'package:server/testing.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

void main() {
  late CapturingLogger log;

  Future<Response> call(
    Handler h,
    String path, {
    Map<String, String>? headers,
  }) async => await h(
    Request('GET', Uri.parse('http://localhost$path'), headers: headers),
  );

  setUp(() => log = CapturingLogger());

  Handler pipeline(Handler inner) => const Pipeline()
      .addMiddleware(coreMiddleware(log.logger))
      .addHandler(inner);

  group('X-Request-Id (05 §6.8.1)', () {
    test('sinh mới khi client không gửi, có trong response', () async {
      final res = await call(pipeline((_) => Response.ok('x')), '/');
      expect(res.headers['x-request-id'], matches(RegExp(r'^[0-9a-f-]{36}$')));
    });

    test('dùng lại giá trị hợp lệ từ client', () async {
      final res = await call(
        pipeline((_) => Response.ok('x')),
        '/',
        headers: {'x-request-id': 'abc12345-req'},
      );
      expect(res.headers['x-request-id'], 'abc12345-req');
    });

    test('giá trị không hợp lệ bị thay', () async {
      final res = await call(
        pipeline((_) => Response.ok('x')),
        '/',
        headers: {'x-request-id': 'bad id\n'},
      );
      expect(res.headers['x-request-id'], isNot('bad id\n'));
    });
  });

  group('bọc lỗi chuẩn', () {
    test('ApiException → thân lỗi JSON và HTTP status của mã', () async {
      final res = await call(
        pipeline(
          (_) => throw ApiException(ErrorCode.validationFailed, field: 'phone'),
        ),
        '/',
      );
      expect(res.statusCode, 422);
      expect(res.headers['content-type'], startsWith('application/json'));
      expect(jsonDecode(await res.readAsString()), {
        'error': {'code': 'validation_failed', 'field': 'phone'},
      });
      expect(res.headers['x-request-id'], isNotNull);
    });

    test(
      'lỗi không lường trước → 500 internal_error, stack chỉ nằm trong log',
      () async {
        final res = await call(pipeline((_) => throw StateError('boom')), '/');
        expect(res.statusCode, 500);
        final body = await res.readAsString();
        expect(jsonDecode(body), {
          'error': {'code': 'internal_error'},
        });
        expect(body, isNot(contains('boom')));
        final error = log.lines
            .map((l) => jsonDecode(l) as Map)
            .firstWhere((m) => m['event'] == 'unhandled_error');
        expect(error['stack'], isNotEmpty);
        expect(error['requestId'], res.headers['x-request-id']);
      },
    );

    test('đường dẫn không tồn tại → 404 not_found', () async {
      final tdb = await TestDatabase.create(migrate: false);
      addTearDown(tdb.dispose);
      final app = buildApp(_deps(tdb.db, log));
      final res = await call(app, '/khong-co');
      expect(res.statusCode, 404);
      expect(jsonDecode(await res.readAsString()), {
        'error': {'code': 'not_found'},
      });
    });
  });

  test('log JSON một dòng mỗi request, chỉ metadata', () async {
    final res = await call(
      pipeline((_) => Response.ok('secret-body')),
      '/v1/x?cursor=3',
    );
    final line = jsonDecode(log.lines.single) as Map<String, Object?>;
    expect(line['event'], 'request');
    expect(line['level'], 'info');
    expect(line['method'], 'GET');
    expect(line['path'], '/v1/x');
    expect(line['status'], 200);
    expect(line['durationMs'], isA<int>());
    expect(line['requestId'], res.headers['x-request-id']);
    expect(log.lines.single, isNot(contains('secret-body')));
  });

  group('/healthz', () {
    test('200 khi database trả lời', () async {
      final tdb = await TestDatabase.create(migrate: false);
      addTearDown(tdb.dispose);
      final res = await call(buildApp(_deps(tdb.db, log)), '/healthz');
      expect(res.statusCode, 200);
      expect(jsonDecode(await res.readAsString()), {'status': 'ok'});
    });

    test('503 khi không kết nối được database', () async {
      final db = Database.open(
        'postgres://health:***REMOVED***@localhost:1/none?connect_timeout=1',
      );
      addTearDown(db.close);
      final res = await call(buildApp(_deps(db, log)), '/healthz');
      expect(res.statusCode, 503);
    });
  });

  test('readJson: thân sai → validation_failed field body', () async {
    final handler = pipeline((req) async => jsonResponse(await readJson(req)));
    final bad = await handler(
      Request('POST', Uri.parse('http://localhost/'), body: '{oops'),
    );
    expect(bad.statusCode, 422);
    expect(jsonDecode(await bad.readAsString()), {
      'error': {'code': 'validation_failed', 'field': 'body'},
    });
    final big = await handler(
      Request(
        'POST',
        Uri.parse('http://localhost/'),
        body: 'x' * ((1 << 20) + 1),
      ),
    );
    expect(big.statusCode, 422);
    final ok = await handler(
      Request('POST', Uri.parse('http://localhost/'), body: '{"a":1}'),
    );
    expect(jsonDecode(await ok.readAsString()), {'a': 1});
  });
}

AppDeps _deps(Database db, CapturingLogger log) => AppDeps(
  db: db,
  logger: log.logger,
  clock: const SystemClock(),
  jwtSecret: 'test-secret-test-secret-test-secret-123',
);
