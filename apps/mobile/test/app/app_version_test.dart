import 'package:api_contract/api_contract.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/data/api/app_version_interceptor.dart';

import '../support/fake_server.dart';
import '../support/version_fixture.dart';

/// 06 Bản 5 VS52-T03: pubspec 5.0.0 và header `X-App-Version: 5.0.0`
/// (05 Bản 5 TD5-18).
void main() {
  test('TD5-18: pubspec.yaml là 5.0.0', () {
    expect(pubspecVersion(), AppVersion.parse('5.0.0'));
  });

  test('TD5-18: request gửi X-App-Version 5.0.0', () async {
    final server = FakeServer()
      ..on('GET', '/healthz', (_) => (200, {'status': 'ok'}));
    final api = server.client()
      ..dio.interceptors.add(AppVersionInterceptor(appVersionV5));
    await api.getJson('/healthz', auth: false);
    expect(server.requests.single.headers[AppVersion.header], '5.0.0');
  });
}
