import 'package:api_contract/api_contract.dart';
import 'package:server/src/admin/admin_commands.dart';
import 'package:test/test.dart';

import 'support/test_app.dart';

void main() {
  late TestApp app;
  late AdminCommands admin;

  setUp(() async {
    app = await TestApp.create();
    admin = AdminCommands(app.tdb.pool, app.deps.tokens, bcryptCost: 4);
  });
  tearDown(() => app.dispose());

  test(
    'TR-09: reset-password → mật khẩu cũ hết hiệu lực, mật khẩu tạm đăng nhập được, phiên cũ bị thu hồi',
    () async {
      final before = await app.register();
      final temp = await admin.resetPassword('0912 345 678');
      expect(temp.length, greaterThanOrEqualTo(8), reason: 'UA-19');

      final old = await app.post('/v1/auth/login', {
        'phone': '0912345678',
        'password': '***REMOVED***',
      });
      expect(old.errorCode, 'invalid_credentials');
      final login = await app.post('/v1/auth/login', {
        'phone': '0912345678',
        'password': temp,
      });
      expect(login.status, 200);
      expect(TokenPair.fromJson(login.json).accessToken, isNotEmpty);

      final refresh = await app.post('/v1/auth/refresh', {
        'refreshToken': before.refreshToken,
      });
      expect(refresh.status, 401, reason: 'mọi phiên cũ bị thu hồi');
    },
  );

  test('số không có tài khoản hoặc sai định dạng → AdminException', () async {
    await expectLater(
      admin.resetPassword('0999999999'),
      throwsA(isA<AdminException>()),
    );
    await expectLater(
      admin.resetPassword('123'),
      throwsA(isA<AdminException>()),
    );
  });

  test('mật khẩu tạm không có ký tự dễ nhầm, mỗi lần khác nhau', () {
    final a = AdminCommands.generateTempPassword();
    final b = AdminCommands.generateTempPassword();
    expect(a, hasLength(12));
    expect(a, isNot(b));
    expect(a, isNot(matches(RegExp('[0O1lI]'))));
  });
}
