import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:mobile/data/api/api_client.dart';

/// Một request đã nhận.
final class FakeRequest {
  FakeRequest(this.method, this.path, this.headers, this.body, this.query);
  final String method;
  final String path;
  final Map<String, dynamic> headers;
  final Object? body;
  final Map<String, dynamic> query;

  String? get authorization => headers['authorization'] as String?;
}

/// Phản hồi giả: (status, thân JSON). Ném [FakeOffline] để mô phỏng mất mạng.
typedef FakeHandler = FutureOr<(int, Object?)> Function(FakeRequest request);

final class FakeOffline implements Exception {}

/// Server giả cho dio: định tuyến theo `METHOD path`, ghi lại mọi request.
final class FakeServer implements HttpClientAdapter {
  final routes = <String, FakeHandler>{};
  final requests = <FakeRequest>[];

  /// true → mọi request đều lỗi kết nối.
  bool offline = false;

  void on(String method, String path, FakeHandler handler) =>
      routes['$method $path'] = handler;

  List<FakeRequest> calls(String method, String path) =>
      requests.where((r) => r.method == method && r.path == path).toList();

  ApiClient client() =>
      ApiClient.create('http://server.test')..dio.httpClientAdapter = this;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (offline) {
      throw DioException.connectionError(
        requestOptions: options,
        reason: 'offline',
      );
    }
    Object? body;
    if (requestStream != null) {
      final bytes = await requestStream.expand((c) => c).toList();
      body = bytes.isEmpty ? null : jsonDecode(utf8.decode(bytes));
    }
    final req = FakeRequest(
      options.method,
      options.uri.path,
      Map.of(options.headers),
      body,
      options.uri.queryParameters,
    );
    requests.add(req);
    final handler = routes['${options.method} ${options.uri.path}'];
    if (handler == null) {
      return _json(404, {
        'error': {'code': 'not_found'},
      });
    }
    try {
      final (status, json) = await handler(req);
      return _json(status, json);
    } on FakeOffline {
      throw DioException.connectionError(
        requestOptions: options,
        reason: 'offline',
      );
    }
  }

  static ResponseBody _json(int status, Object? json) =>
      ResponseBody.fromString(
        jsonEncode(json),
        status,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );

  @override
  void close({bool force = false}) {}
}

Map<String, Object?> unauthorizedBody() => {
  'error': {'code': 'unauthorized'},
};
