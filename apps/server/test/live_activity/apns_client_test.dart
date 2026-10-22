import 'dart:convert';
import 'dart:io';

import 'package:api_contract/api_contract.dart';
import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import 'package:domain/domain.dart';
import 'package:server/src/live_activity/apns_client.dart';
import 'package:server/testing.dart';
import 'package:test/test.dart';

/// Phản hồi APNs ghi sẵn.
final class _Transport implements ApnsTransport {
  _Transport(this.responses);

  final List<({int status, String body})> responses;
  final requests =
      <
        ({String host, String path, Map<String, String> headers, String body})
      >[];
  Object? error;

  @override
  Future<({int status, String body})> post(
    String host,
    String path,
    Map<String, String> headers,
    List<int> body,
  ) async {
    if (error case final e?) throw e;
    requests.add((
      host: host,
      path: path,
      headers: headers,
      body: utf8.decode(body),
    ));
    return responses.removeAt(0);
  }

  @override
  Future<void> close() async {}
}

/// Khóa EC P-256 sinh mới mỗi lần chạy (không có khóa nào trong repo).
Future<(String privatePem, String publicPem)> _keyPair() async {
  final dir = await Directory.systemTemp.createTemp('apns_test');
  try {
    final key = '${dir.path}/key.p8';
    final pub = '${dir.path}/key.pub';
    final gen = await Process.run('openssl', [
      'genpkey',
      '-algorithm',
      'EC',
      '-pkeyopt',
      'ec_paramgen_curve:P-256',
      '-out',
      key,
    ]);
    expect(gen.exitCode, 0, reason: '${gen.stderr}');
    final out = await Process.run('openssl', [
      'pkey',
      '-in',
      key,
      '-pubout',
      '-out',
      pub,
    ]);
    expect(out.exitCode, 0, reason: '${out.stderr}');
    return (File(key).readAsStringSync(), File(pub).readAsStringSync());
  } finally {
    await dir.delete(recursive: true);
  }
}

/// 06 Bản 3 VS40-T02, T08: `ApnsClient` với phản hồi ghi sẵn (200 / 410 /
/// 400 / 429 / lỗi mạng), header theo 05 Bản 3 §6.9.2, JWT ES256 ký lại.
void main() {
  late String privatePem;
  late String publicPem;
  late FixedClock clock;
  final keyId = 'K${DateTime.now().microsecond}';
  final teamId = 'T${DateTime.now().millisecond}';

  setUpAll(() async => (privatePem, publicPem) = await _keyPair());
  setUp(() => clock = FixedClock(DateTime.utc(2026, 10, 12, 11)));

  ApnsClient client(_Transport t) => ApnsClient(
    credentials: ApnsCredentials(
      keyPem: privatePem,
      keyId: keyId,
      teamId: teamId,
    ),
    bundleId: 'com.happycodingdude.ironly.dev',
    clock: clock,
    transport: t,
  );

  final deviceToken = randomApnsToken();
  final push = ApnsPush(
    token: deviceToken,
    environment: ApnsEnvironment.sandbox,
    payload: {
      'aps': {'event': 'end'},
    },
  );

  test(
    'header, host theo môi trường, JWT ES256 đúng khóa (iss, iat, kid)',
    () async {
      final t = _Transport([(status: 200, body: '')]);
      final c = client(t);
      expect((await c.send(push)).outcome, ApnsOutcome.sent);
      final r = t.requests.single;
      expect(r.host, 'api.sandbox.push.apple.com');
      expect(r.path, '/3/device/$deviceToken');
      expect(r.headers, containsPair('apns-push-type', 'liveactivity'));
      expect(
        r.headers,
        containsPair(
          'apns-topic',
          'com.happycodingdude.ironly.dev.push-type.liveactivity',
        ),
      );
      expect(r.headers, containsPair('apns-priority', '10'));
      expect(r.headers, containsPair('apns-expiration', '0'));
      expect(jsonDecode(r.body), push.payload);
      final jwt = JWT.verify(
        r.headers['authorization']!.substring('bearer '.length),
        ECPublicKey(publicPem),
      );
      expect(jwt.header?['kid'], keyId);
      expect(jwt.header?['alg'], 'ES256');
      expect(jwt.payload, {
        'iss': teamId,
        'iat': DateTime.utc(2026, 10, 12, 11).millisecondsSinceEpoch ~/ 1000,
      });
      expect(ApnsClient.host(ApnsEnvironment.production), 'api.push.apple.com');
    },
  );

  test('ký lại JWT sau 50 phút, không ký lại trước đó', () {
    final c = client(_Transport([]));
    final first = c.token();
    clock.advance(const Duration(minutes: 49));
    expect(c.token(), first);
    clock.advance(const Duration(minutes: 1));
    expect(c.token(), isNot(first));
  });

  test('mã phản hồi → cách xử lý của job', () async {
    String reason(String r) => jsonEncode({'reason': r});
    final t = _Transport([
      (status: 410, body: reason('Unregistered')),
      (status: 400, body: reason('BadDeviceToken')),
      (status: 400, body: reason('BadTopic')),
      (status: 429, body: reason('TooManyRequests')),
      (status: 503, body: reason('ServiceUnavailable')),
    ]);
    final c = client(t);
    final results = [for (var i = 0; i < 5; i++) await c.send(push)];
    expect(
      [for (final r in results) r.outcome],
      [
        ApnsOutcome.invalidToken,
        ApnsOutcome.invalidToken,
        ApnsOutcome.rejected,
        ApnsOutcome.retry,
        ApnsOutcome.retry,
      ],
    );
    expect(results.first.error, '410 Unregistered');
    t.error = const SocketException('mất mạng');
    expect((await c.send(push)).outcome, ApnsOutcome.retry);
  });

  test('ExpiredProviderToken → ký lại và gửi lại ngay một lần', () async {
    final t = _Transport([
      (status: 403, body: jsonEncode({'reason': 'ExpiredProviderToken'})),
      (status: 200, body: ''),
    ]);
    final c = client(t);
    expect((await c.send(push)).outcome, ApnsOutcome.sent);
    expect(t.requests, hasLength(2));
  });
}
