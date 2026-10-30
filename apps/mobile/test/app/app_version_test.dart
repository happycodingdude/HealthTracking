import 'package:api_contract/api_contract.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/data/api/app_version_interceptor.dart';

import '../support/fake_server.dart';
import '../support/version_fixture.dart';

/// 06 Bản 4 VS43-T10: pubspec 4.0.0 và header `X-App-Version: 4.0.0`
/// (05 Bản 4 TD4-11).
void main() {
  test('TD4-11: pubspec.yaml là 4.0.0', () {
    expect(pubspecVersion(), AppVersion.parse('4.0.0'));
  });

  test('TD4-11: request gửi X-App-Version 4.0.0', () async {
    final server = FakeServer()
      ..on('GET', '/healthz', (_) => (200, {'status': 'ok'}));
    final api = server.client()
      ..dio.interceptors.add(AppVersionInterceptor(appVersionV4));
    await api.getJson('/healthz', auth: false);
    expect(server.requests.single.headers[AppVersion.header], '4.0.0');
  });
}
