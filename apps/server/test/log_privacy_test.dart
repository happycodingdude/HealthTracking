import 'package:api_contract/api_contract.dart';
import 'package:domain/domain.dart';
import 'package:server/server.dart';
import 'package:test/test.dart';
import 'package:uuid/uuid.dart';

import 'support/test_app.dart';

/// 06 VS15-T07, 05 §6.12.1: log server chỉ có metadata — không có số điện
/// thoại, mật khẩu, tên, token, số đo, mức calo hay nội dung thực đơn.
void main() {
  // 03:00 UTC thứ 4 07/10/2026 = 10:00 giờ Việt Nam.
  final t0 = DateTime.utc(2026, 10, 7, 3);
  final today = LocalDate(2026, 10, 7);
  const phone = '0912345678';
  const password = '***REMOVED***';
  const wrongPassword = '***REMOVED***';
  const name = 'Nguyễn Minh Anh';
  const uuid = Uuid();

  test('đăng ký, đăng nhập (sai rồi đúng), làm mới phiên, đồng bộ hồ sơ và '
      'cân nặng (có bản ghi bị từ chối), tạo thực đơn (thành công và lỗi) → '
      'log không chứa dữ liệu nhạy cảm', () async {
    final ai = FakeAiProvider();
    final app = await TestApp.create(now: t0, ai: ai);
    addTearDown(app.dispose);

    final registered = await app.register(
      phone: phone,
      name: name,
      password: password,
    );
    await app.post('/v1/auth/register', {
      'displayName': name,
      'phone': '09123abc',
      'password': password,
    });
    await app.post('/v1/auth/login', {
      'phone': phone,
      'password': wrongPassword,
    });
    final login = TokenPair.fromJson(
      (await app.post('/v1/auth/login', {
        'phone': phone,
        'password': password,
      })).json,
    );
    final refreshed = TokenPair.fromJson(
      (await app.post('/v1/auth/refresh', {
        'refreshToken': login.refreshToken,
      })).json,
    );
    final token = refreshed.accessToken;

    final pushed = await app.push(token, [
      mutation(
        'profile',
        'me',
        SyncOp.upsert,
        at: t0.subtract(const Duration(minutes: 1)),
        data: const ProfileCodec().encode(
          Profile(
            onboardingStep: 5,
            disclaimerAcceptedAt: t0.subtract(const Duration(hours: 1)),
            heightCm: 175,
            birthYear: 1996,
            sex: Sex.male,
            activityLevel: ActivityLevel.moderate,
            calorieMode: CalorieMode.manual,
            calorieKcal: 1900,
            setupDate: today,
            onboardingCompletedAt: t0.subtract(const Duration(minutes: 30)),
            timezone: 'Asia/Ho_Chi_Minh',
          ),
        ),
      ),
      mutation(
        'weight',
        '2026-10-05',
        SyncOp.upsert,
        at: t0,
        data: {'weightKgX10': 783},
      ),
      // Số cân ngoài khoảng cho phép: bị từ chối.
      mutation(
        'weight',
        '2026-09-28',
        SyncOp.upsert,
        at: t0,
        data: {'weightKgX10': 99999},
      ),
    ]);
    expect(pushed.results.map((r) => r.status), [
      PushStatus.applied,
      PushStatus.applied,
      PushStatus.rejected,
    ]);
    await app.pull(token);
    await app.get('/v1/me', token: token);
    await app.get('/v1/me', token: '***REMOVED***');

    Future<TestResponse> generate() => app.post('/v1/ai/menus', {
      'localDate': today.toKey(),
      'requestId': uuid.v4(),
      'targetKcal': 1900,
    }, token: token);
    expect((await generate()).status, 200);
    ai.enqueue([FakeAiMode.invalidJson, FakeAiMode.overloaded]);
    await generate();
    await generate();

    final log = app.log.lines.join('\n');
    expect(app.log.lines, isNotEmpty);
    expect(log, contains('ai_menu_settled'), reason: 'có log của luồng AI');
    final secrets = [
      phone,
      password,
      wrongPassword,
      name,
      '09123abc',
      for (final p in [registered, login, refreshed]) ...[
        p.accessToken,
        p.refreshToken,
      ],
      // Món ăn của nhà cung cấp AI giả.
      'Phở gà', 'Bánh mì', 'Cơm', 'Canh', 'Bún',
      // Tên trường chứa dữ liệu cá nhân, prompt, nội dung request.
      '"phone"', '"password"', '"displayName"', '"heightCm"', '"birthYear"',
      '"weightKgX10"', '"calorieKcal"', '"targetKcal"', '"meals"',
      'Bearer', 'refreshToken', 'accessToken',
    ];
    for (final s in secrets) {
      expect(log, isNot(contains(s)), reason: s);
    }
  });
}
