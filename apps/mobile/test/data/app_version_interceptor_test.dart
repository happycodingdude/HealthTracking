import 'package:api_contract/api_contract.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/data/api/app_version_interceptor.dart';

import '../support/fake_server.dart';

void main() {
  test('TR2-13, ED2-02: mọi request gửi X-App-Version, kể cả request không '
      'cần đăng nhập', () async {
    final server = FakeServer()
      ..on('GET', '/healthz', (_) => (200, {'status': 'ok'}))
      ..on('POST', '/v1/sync/push', (_) => (200, {'results': <Object>[]}));
    final api = server.client()
      ..dio.interceptors.add(AppVersionInterceptor(AppVersion.parse('2.0.0')));
    await api.getJson('/healthz', auth: false);
    await api.postJson('/v1/sync/push', {'mutations': <Object>[]});
    expect(server.requests, hasLength(2));
    for (final r in server.requests) {
      expect(r.headers[AppVersion.header], '2.0.0', reason: r.path);
    }
  });
}
