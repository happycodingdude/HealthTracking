// Thẻ theo vị trí khi app tắt hẳn (06 Bản 5 VS60-T05, D5-3 / D5-4 phần
// simulator, TAC5-08), bước 1 — chạy TRONG cây code hiện tại
// (tool/gym_killed_test.sh chép file này vào apps/mobile/integration_test/ rồi
// xóa sau khi chạy): tài khoản thật trên server test, vị trí phòng gym đã lưu
// và đang bật; app mở lên khôi phục việc theo dõi vùng 150 m (05 Bản 5
// §6.4.6). Bước 2 (script): tắt hẳn app, dời vị trí ra xa rồi vào lại.
import 'package:dio/dio.dart';
import 'package:domain/domain.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mobile/app/env.dart';
import 'package:mobile/app/strings_vi.dart';
import 'package:mobile/data/auth/session_store.dart';
import 'package:mobile/data/db/open_database.dart';
import 'package:mobile/features/me/data/account_repository.dart';
import 'package:mobile/features/me/data/gym_location_repository.dart';
import 'package:mobile/features/me/data/profile_repository.dart';
import 'package:mobile/main.dart' as app;

import 'flow_helpers.dart';

// Mật khẩu do script sinh ngẫu nhiên mỗi lần chạy (GIT RULES 4).
const _password = String.fromEnvironment('SEED_PASSWORD');
const _phone = String.fromEnvironment('SEED_PHONE');
const _lat = String.fromEnvironment('GYM_LAT');
const _lng = String.fromEnvironment('GYM_LNG');

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('D5-3 bước 1: đăng nhập, vị trí phòng gym đã lưu và bật, app '
      'theo dõi vùng', (tester) async {
    expect([_password, _phone, _lat, _lng], everyElement(isNotEmpty));
    await const FlutterSecureStorage().deleteAll();
    final http = Dio(BaseOptions(baseUrl: AppEnv.fromEnvironment().apiBaseUrl));
    final pair = (await http.post<Map<String, Object?>>(
      '/v1/auth/register',
      data: {'displayName': 'Minh', 'phone': _phone, 'password': _password},
    )).data!;
    final me = (await http.get<Map<String, Object?>>(
      '/v1/me',
      options: Options(
        headers: {'Authorization': 'Bearer ${pair['accessToken']}'},
      ),
    )).data!;
    await SecureSessionStore().write(
      StoredSession(
        userId: me['userId']! as String,
        phone: _phone,
        refreshToken: pair['refreshToken']! as String,
      ),
    );
    final db = openAppDatabase();
    await AccountRepository(db).put('Minh');
    // Đã xong thiết lập lần đầu (chưa có lịch: Hôm nay H1, có thanh tab).
    final setupAt = DateTime.now().subtract(const Duration(days: 30));
    await ProfileRepository(db).put(
      Profile(
        onboardingStep: 5,
        disclaimerAcceptedAt: setupAt,
        heightCm: 175,
        birthYear: 1996,
        sex: Sex.male,
        activityLevel: ActivityLevel.moderate,
        calorieMode: CalorieMode.auto,
        calorieKcal: 2210,
        setupDate: LocalDate.fromDateTime(setupAt),
        onboardingCompletedAt: setupAt,
        remindersEnabled: false,
        timezone: 'Asia/Ho_Chi_Minh',
      ),
    );
    await GymLocationRepository(db).put(
      GymLocation(
        lat: double.parse(_lat),
        lng: double.parse(_lng),
        savedAt: DateTime.now(),
      ),
    );
    await app.runIronlyApp(database: db);
    await pumpUntil(tester, tabLabel(S.tabToday));
    // Cho app khôi phục theo dõi vùng (start) trước khi script tắt app.
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    // ignore: avoid_print
    print('SEED_GYM user=${me['userId']}');
  });
}
