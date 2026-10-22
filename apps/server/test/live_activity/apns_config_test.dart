import 'dart:io';

import 'package:api_contract/api_contract.dart';
import 'package:server/server.dart';
import 'package:server/src/admin/admin_commands.dart';
import 'package:server/testing.dart';
import 'package:test/test.dart';

import '../support/test_app.dart';

/// 06 Bản 3 VS40-T06, T08: cấu hình APNs (thiếu khóa → job tắt, ED3-15),
/// `LIVE_ACTIVITY_CRON`, `admin apns test`, khóa `.p8` không vào image
/// (TAC3-11 phần server).
void main() {
  final full = {
    'APNS_KEY_PATH': '/app/secrets/key.p8',
    'APNS_KEY_ID': 'K',
    'APNS_TEAM_ID': 'T',
    'APNS_BUNDLE_ID': 'com.happycodingdude.ironly',
  };

  test(
    'ED3-15: thiếu bất kỳ biến APNS_* nào → không có cấu hình (job tắt)',
    () {
      expect(
        ApnsConfig.fromEnvironment(full)?.bundleId,
        'com.happycodingdude.ironly',
      );
      for (final key in full.keys) {
        expect(
          ApnsConfig.fromEnvironment({...full, key: ''}),
          isNull,
          reason: key,
        );
      }
    },
  );

  test(
    'LIVE_ACTIVITY_CRON: mặc định mỗi phút; "*/N" mỗi N phút; dạng khác lỗi',
    () {
      expect(
        ServerConfig.parseMinuteCron('* * * * *'),
        const Duration(minutes: 1),
      );
      expect(
        ServerConfig.parseMinuteCron('*/5 * * * *'),
        const Duration(minutes: 5),
      );
      for (final bad in ['0 * * * *', '*/0 * * * *', 'mỗi phút']) {
        expect(
          () => ServerConfig.parseMinuteCron(bad),
          throwsA(isA<ConfigException>()),
        );
      }
    },
  );

  test('TAC3-11 (server): image không chép khóa .p8 hay thư mục secrets', () {
    final dockerfile = File('Dockerfile').readAsStringSync();
    expect(dockerfile, isNot(contains('.p8')));
    expect(dockerfile, isNot(contains('secrets')));
    final gitignore = File('../../.gitignore').readAsStringSync();
    expect(gitignore, contains('*.p8'));
    expect(gitignore, contains('deploy/secrets/'));
  });

  group('admin apns test --user', () {
    late TestApp app;

    setUp(() async => app = await TestApp.create());
    tearDown(() => app.dispose());

    test(
      'gửi end tới token thẻ của tài khoản; chưa có token → báo lỗi',
      () async {
        final pair = await app.register();
        final admin = AdminCommands(
          app.tdb.pool,
          app.deps.tokens,
          bcryptCost: 4,
        );
        final apns = FakeApns();
        await expectLater(
          admin.apnsTest('0912345678', apns, DateTime.utc(2026, 10, 12)),
          throwsA(isA<AdminException>()),
        );
        final startToken = randomApnsToken();
        await app.send(
          'PUT',
          '/v1/me/live-activity-token',
          body: LiveActivityTokenRequest(
            pushToStartToken: startToken,
            environment: ApnsEnvironment.sandbox,
            appVersion: '3.0.0',
          ).toJson(),
          token: pair.accessToken,
        );
        final result = await admin.apnsTest(
          '0912345678',
          apns,
          DateTime.utc(2026, 10, 12),
        );
        expect(result.outcome, ApnsOutcome.sent);
        final sent = apns.sent.single;
        expect(sent.token, startToken);
        expect(sent.environment, ApnsEnvironment.sandbox);
        expect((sent.payload['aps']! as Map)['event'], 'end');
      },
    );
  });
}
