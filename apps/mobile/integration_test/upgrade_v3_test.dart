// Integration test VS-32 trên iOS simulator (06 Bản 3 VS32-T10, TAC3-02):
// iPhone đang chạy app 2.x (database schema 1, có dữ liệu, outbox còn 2
// mutation chưa gửi) được cài app 3.0.0 → Drift lên schema 2, giữ nguyên dữ
// liệu và outbox, gửi đủ 2 mutation tới server thật rồi pull lại từ cursor 0
// (bộ entity đã biết thêm `exercise_unit`, `exercise_note`, TD3-09).
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:domain/testing.dart';
import 'package:drift/native.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mobile/app/env.dart';
import 'package:mobile/app/providers.dart';
import 'package:mobile/app/strings_vi.dart';
import 'package:mobile/data/auth/session_store.dart';
import 'package:mobile/data/db/app_database.dart';
import 'package:mobile/main.dart' as app;

import '../test/generated_migrations/schema_v1.dart' as v1;
import 'flow_helpers.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('TAC3-02: schema 1 có dữ liệu + outbox 2 mutation → 3.0.0 → '
      'schema 2, gửi đủ mutation, cursor về 0 rồi pull hết', (tester) async {
    await const FlutterSecureStorage().deleteAll();
    final http = Dio(BaseOptions(baseUrl: AppEnv.fromEnvironment().apiBaseUrl));
    final password = randomTestPassword();
    const phone = '0966666666';
    final pair = (await http.post<Map<String, Object?>>(
      '/v1/auth/register',
      data: {'displayName': 'Minh', 'phone': phone, 'password': password},
    )).data!;
    final access = Options(
      headers: {'Authorization': 'Bearer ${pair['accessToken']}'},
    );
    final me = (await http.get<Map<String, Object?>>(
      '/v1/me',
      options: access,
    )).data!;
    await SecureSessionStore().write(
      StoredSession(
        userId: me['userId']! as String,
        phone: phone,
        refreshToken: pair['refreshToken']! as String,
      ),
    );

    // Database của app 2.x (schema 1).
    final file = File(
      '${Directory.systemTemp.createTempSync('ironly_v2_').path}/ironly.sqlite',
    );
    final old = v1.DatabaseAtV1(NativeDatabase(file));
    await old.customStatement(
      'INSERT INTO sync_state (id, cursor, known_entities) VALUES (1, 812, '
      "'account,ai_daily_usage,day,dish_image,exercise,lift_log,menu,"
      "month_plan,profile,weekly_template,weight')",
    );
    await old.customStatement(
      "INSERT INTO account (key, display_name) VALUES ('me', 'Minh')",
    );
    await old.customStatement('''
      INSERT INTO profiles (key, onboarding_step, height_cm, birth_year, sex,
        activity_level, setup_date, disclaimer_accepted_at, onboarding_completed_at,
        calorie_mode, calorie_kcal, reminders_enabled, timezone)
      VALUES ('me', 5, 172, 1994, 'male', 'moderate', '2026-10-01',
        '2026-10-01T08:00:00.000', '2026-10-01T08:10:00.000', 'auto', 2210, 0,
        'Asia/Ho_Chi_Minh')''');
    for (final (id, name) in [
      ('11111111-1111-4111-8111-111111111111', 'Minh Một'),
      ('22222222-2222-4222-8222-222222222222', 'Minh Hai'),
    ]) {
      await old.customStatement(
        'INSERT INTO outbox (mutation_id, entity, key, op, payload, client_updated_at) '
        "VALUES ('$id', 'account', 'me', 'upsert', '{\"displayName\":\"$name\"}', "
        "'${DateTime.now().toUtc().subtract(const Duration(minutes: 1)).toIso8601String()}')",
      );
    }
    await old.close();

    // Cài 3.0.0: mở cùng file bằng AppDatabase hiện tại.
    final db = AppDatabase(NativeDatabase(file));
    await app.runIronlyApp(
      database: db,
      overrides: [clockProvider.overrideWithValue(ShiftedClock(Duration.zero))],
    );
    await pumpUntil(tester, tabLabel(S.tabToday));
    for (var i = 0; i < 200; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      final state = await db.select(db.syncState).getSingle();
      if ((await db.select(db.outbox).get()).isEmpty &&
          state.lastSyncedAt != null) {
        break;
      }
    }

    final version = await db.customSelect('PRAGMA user_version').getSingle();
    expect(version.data.values.single, 2);
    expect(await db.select(db.outbox).get(), isEmpty);
    final state = await db.select(db.syncState).getSingle();
    expect(state.knownEntities, contains('exercise_note'));
    expect(state.knownEntities, contains('exercise_unit'));
    expect(state.cursor, greaterThan(0));
    expect(state.cursor, isNot(812));
    expect(
      await db.select(db.exercises).get(),
      hasLength(29),
      reason: 'pull lại từ 0 có đủ thư viện của server',
    );
    expect(await db.select(db.muscleRegions).get(), hasLength(19));
    final after = (await http.get<Map<String, Object?>>(
      '/v1/me',
      options: access,
    )).data!;
    expect(after['displayName'], 'Minh Hai', reason: 'cả 2 mutation đã gửi');
    await const FlutterSecureStorage().deleteAll();
  });
}
