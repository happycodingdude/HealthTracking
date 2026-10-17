import 'package:api_contract/api_contract.dart';
import 'package:postgres/postgres.dart';
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
      const phone = '0912 345 678';
      final before = await app.register();
      final temp = await admin.resetPassword(phone);
      expect(temp.length, greaterThanOrEqualTo(8), reason: 'UA-19');

      final old = await app.post('/v1/auth/login', {
        'phone': '0912345678',
        'password': testPassword,
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
    for (final phone in ['0999999999', '123']) {
      await expectLater(
        admin.resetPassword(phone),
        throwsA(isA<AdminException>()),
        reason: phone,
      );
    }
  });

  test('mật khẩu tạm không có ký tự dễ nhầm, mỗi lần khác nhau', () {
    final a = AdminCommands.generateTempPassword();
    final b = AdminCommands.generateTempPassword();
    expect(a, hasLength(12));
    expect(a, isNot(b));
    expect(a, isNot(matches(RegExp('[0O1lI]'))));
  });

  test('VS13-T03: budget --show in tháng, đã dùng, đặt trước, trạng thái chặn, '
      'yêu cầu gần nhất, không in thông tin tài khoản', () async {
    final now = DateTime.utc(2026, 10, 7, 3);
    expect(
      await admin.budgetReport(now),
      allOf(
        contains('Ngân sách AI tháng 2026-10'),
        contains('Đã dùng: 0đ (0%)'),
        contains('(chưa có)'),
      ),
    );
    await app.tdb.pool.execute(
      'INSERT INTO ai_budget_months (month, used_vnd, reserved_vnd, blocked_at) '
      "VALUES ('2026-10', 12500.5, 434.61, '2026-10-06T10:00:00Z')",
    );
    final user = await app.register();
    await app.tdb.pool.execute(
      Sql.named('''
        INSERT INTO ai_requests (user_id, request_id, feature, local_date, month, provider,
                                 model, status, reserved_vnd, actual_vnd, input_tokens,
                                 output_tokens, created_at, settled_at)
        SELECT id, gen_random_uuid(), 'menu', '2026-10-06', '2026-10', 'fake', 'm',
               'succeeded', 434.61, 186.3, 900, 1200, '2026-10-06T09:00:00Z', now()
        FROM users WHERE phone = '0912345678' '''),
    );
    expect(user.accessToken, isNotEmpty);
    final report = await admin.budgetReport(now);
    expect(report, contains('Mức trần: 50.000đ'));
    expect(report, contains('Đã dùng: 12.500,50đ (25%)'));
    expect(report, contains('Đang đặt trước: 434,61đ'));
    expect(report, contains('ĐÃ CHẶN từ 2026-10-06T10:00:00Z'));
    expect(
      report,
      contains('succeeded  đặt trước 434,61đ  thực tế 186,30đ  token 900/1200'),
    );
    expect(report, isNot(contains('0912345678')));
  });
}
