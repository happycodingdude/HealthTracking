import 'dart:convert';
import 'dart:typed_data';

import 'package:api_contract/api_contract.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/data/api/api_client.dart';

/// Adapter giả: trả response theo hàm [respond] hoặc ném lỗi kết nối.
class FakeAdapter implements HttpClientAdapter {
  FakeAdapter(this.respond);
  final ResponseBody Function(RequestOptions) respond;
  final requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return respond(options);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody json(int status, Object body) => ResponseBody.fromString(
  jsonEncode(body),
  status,
  headers: {
    Headers.contentTypeHeader: [Headers.jsonContentType],
  },
);

void main() {
  ApiClient client(ResponseBody Function(RequestOptions) respond) {
    final c = ApiClient.create('http://server.test');
    c.dio.httpClientAdapter = FakeAdapter(respond);
    return c;
  }

  test('200 → trả JSON đã giải mã', () async {
    final c = client((_) => json(200, {'status': 'ok'}));
    expect(await c.getJson('/healthz'), {'status': 'ok'});
    expect(await c.healthz(), isTrue);
  });

  test('lỗi chuẩn của server → ServerFailure có ApiError', () async {
    final c = client(
      (_) => json(409, {
        'error': {'code': 'phone_taken', 'field': 'phone'},
      }),
    );
    await expectLater(
      c.postJson('/v1/auth/register', {}),
      throwsA(
        isA<ServerFailure>()
            .having(
              (f) => f.error,
              'error',
              const ApiError(ErrorCode.phoneTaken, field: 'phone'),
            )
            .having((f) => f.status, 'status', 409),
      ),
    );
  });

  test('không kết nối được → NetworkFailure; healthz = false', () async {
    final c = client(
      (o) => throw DioException.connectionError(
        requestOptions: o,
        reason: 'offline',
      ),
    );
    await expectLater(c.getJson('/healthz'), throwsA(isA<NetworkFailure>()));
    expect(await c.healthz(), isFalse);
  });

  test('base URL theo flavor được dùng cho request', () async {
    final adapter = FakeAdapter((_) => json(200, {}));
    final c = ApiClient.create('http://mac.local:8080')
      ..dio.httpClientAdapter = adapter;
    await c.getJson('/healthz');
    expect(
      adapter.requests.single.uri.toString(),
      'http://mac.local:8080/healthz',
    );
  });
}
