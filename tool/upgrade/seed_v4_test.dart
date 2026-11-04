// Kiểm thử nâng cấp Bản 5 (06 Bản 5 ED5-11, VS60-T04, TAC5-02), bước 1 —
// chạy TRONG cây code 4.0.0 (tool/upgrade_test.sh chép file này vào
// build/upgrade_v4/apps/mobile/integration_test/): app 4.0.0 trên simulator
// có tài khoản thật trên server test, database thật của app với `v4DataSet`
// (lịch 4 buổi, mức tạ kg + nấc, ghi chú, đơn vị, cân nặng, thực đơn, buổi
// "Không tập" ngày đã qua còn trong hạn 7 ngày của Bản 4), đã đồng bộ xong
// (cursor thật), rồi còn 2 mutation trong outbox chưa gửi.
// Bước 2 (script): cài đè 5.0.0, mở app, kiểm database + server; bước 3
// (tool/upgrade/check_v5_test.dart): buổi ngày đã qua không sửa được.
import 'package:dio/dio.dart';
import 'package:domain/domain.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mobile/app/env.dart';
import 'package:mobile/app/strings_vi.dart';
import 'package:mobile/data/auth/session_store.dart';
import 'package:mobile/data/db/app_database.dart';
import 'package:mobile/data/db/open_database.dart';
import 'package:mobile/features/menu/data/menu_repository.dart';
import 'package:mobile/features/schedule/data/schedule_repository.dart';
import 'package:mobile/features/weight/data/weight_repository.dart';
import 'package:mobile/features/workout/data/exercise_note_repository.dart';
import 'package:mobile/features/workout/data/exercise_unit_repository.dart';
import 'package:mobile/features/workout/data/lift_log_repository.dart';
import 'package:mobile/main.dart' as app;

import '../test/support/menu_fixture.dart';
import '../test/support/schedule_fixture.dart';
import 'flow_helpers.dart';

// Mật khẩu do script sinh ngẫu nhiên mỗi lần chạy (GIT RULES 4).
const _password = String.fromEnvironment('SEED_PASSWORD');
const _phone = '0977777778';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('ED5-11 bước 1: app 4.0.0 có v4DataSet, đã đồng bộ, outbox 2 '
      'mutation', (tester) async {
    expect(_password, isNotEmpty, reason: 'thiếu --dart-define=SEED_PASSWORD');
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

    // Database thật của app (cùng file 5.0.0 sẽ mở sau khi cài đè).
    final db = openAppDatabase();
    // Hồ sơ, lịch 4 buổi, lịch tháng 10 + tháng hiện tại, cân 80 kg.
    final today = LocalDate.fromDateTime(DateTime.now());
    await seedSetUp(
      db,
      extraMonths: [
        if (today.yearMonth != YearMonth(2026, 10)) today.yearMonth,
      ],
    );
    // Buổi "Không tập" ngày đã qua gần nhất, còn hạn 7 ngày của Bản 4 (FC5-12).
    var past = today.addDays(-1);
    while ((await ScheduleRepository(db).day(past))?.isWorkout != true) {
      past = past.addDays(-1);
    }
    await seedMark(db, past, DayMark.skipped);
    await WeightRepository(db).put(LocalDate(2026, 10, 26), 795);
    final chest = LocalDate(2026, 10, 26); // thứ 2: ngực + tay sau
    await LiftLogRepository(db).put(
      LiftLog(
        date: LocalDate(2026, 10, 26),
        exerciseId: 'chest-mid-machine-pec-deck',
        startKgX10: 400,
        endKgX10: 475,
      ),
    );
    await ExerciseUnitRepository(db).put(
      ExerciseUnit(
        exerciseId: 'lats-machine-lat-pulldown',
        unit: LiftUnit.steps,
        changedOn: LocalDate(2026, 10, 21),
      ),
    );
    await LiftLogRepository(db).put(
      LiftLog(
        date: LocalDate(2026, 10, 28),
        exerciseId: 'lats-machine-lat-pulldown',
        startKgX10: 60,
        endKgX10: 70,
      ),
    );
    await ExerciseNoteRepository(db).put(
      ExerciseNote(
        date: chest,
        exerciseId: 'chest-mid-machine-pec-deck',
        text: 'Ghế dốc 30 độ, tay rộng',
      ),
    );
    await MenuRepository(db).put(LocalDate(2026, 10, 30), readyMenu());

    // Mở app 4.0.0 với database này, chờ đồng bộ xong (cursor thật).
    await app.runIronlyApp(database: db);
    await pumpUntil(tester, tabLabel(S.tabToday));
    var synced = false;
    for (var i = 0; i < 300 && !synced; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      final state = await db.select(db.syncState).getSingleOrNull();
      synced =
          state?.lastSyncedAt != null &&
          (await db.select(db.outbox).get()).isEmpty;
    }
    expect(synced, isTrue, reason: 'app 4.0.0 phải đồng bộ xong trước');
    final state = await db.select(db.syncState).getSingle();
    expect(state.cursor, greaterThan(0));

    // 2 mutation chưa gửi (như mất mạng sau khi sửa tên hiển thị 2 lần).
    for (final (id, name) in [
      ('11111111-1111-4111-8111-111111111111', 'Minh Một'),
      ('22222222-2222-4222-8222-222222222222', 'Minh Hai'),
    ]) {
      await db
          .into(db.outbox)
          .insert(
            OutboxCompanion.insert(
              mutationId: id,
              entity: 'account',
              entityKey: 'me',
              op: 'upsert',
              payload: Value('{"displayName":"$name"}'),
              clientUpdatedAt: DateTime.now().toUtc().subtract(
                const Duration(minutes: 1),
              ),
            ),
          );
    }
    expect(await db.select(db.outbox).get(), hasLength(2));
    // In để script đối chiếu sau khi cài đè 5.0.0.
    // ignore: avoid_print
    print(
      'SEED_V4 cursor=${state.cursor} user=${me['userId']} past=${past.toKey()}',
    );
  });
}
