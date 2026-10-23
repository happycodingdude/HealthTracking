@Tags(['e2e'])
library;

import 'dart:io';

import 'package:api_contract/api_contract.dart';
import 'package:domain/domain.dart';
import 'package:flutter_test/flutter_test.dart' hide pumpEventQueue;
import 'package:mobile/data/api/api_client.dart';
import 'package:mobile/data/auth/auth_repository.dart';
import 'package:mobile/data/local_marks.dart';
import 'package:mobile/data/logout_flag.dart';
import 'package:mobile/data/sync/sync_engine.dart';
import 'package:mobile/features/account/application/logout.dart';
import 'package:mobile/features/onboarding/data/onboarding_draft_repository.dart';
import 'package:server/server.dart' show LibraryImporter;
import 'package:server/testing.dart' show library28;

import '../support/app_harness.dart' show FakeConnectivity;
import '../support/fake_logout.dart';
import '../support/fake_notifications.dart';
import 'sync_e2e_harness.dart';

/// 06 Bản 3 VS38-T05 (E2E): đăng xuất với server thật — F27-AC3, F09-AC42,
/// F27-E3, F27-E4, TAC3-10 (refresh token cũ bị từ chối).
void main() {
  late E2eServer server;
  final devices = <E2eDevice>[];

  setUpAll(() => HttpOverrides.global = null);
  setUp(() async {
    server = await E2eServer.start();
    expect((await LibraryImporter(server.tdb.pool).run(library28())).ok, true);
  });
  tearDown(() async {
    for (final d in devices) {
      await d.close();
    }
    devices.clear();
    await server.stop();
  });

  E2eDevice device() {
    final d = E2eDevice(server);
    devices.add(d);
    return d;
  }

  // T2 Ngực 06:00; ghi tạ 08:00–09:00 trong cửa sổ của thứ 2.
  final template = WeeklyTemplate({
    1: TemplateDay(
      enabled: true,
      time: LocalTime(6, 0),
      muscles: const [MuscleGroup.chest],
    ),
  });
  final monday = LocalDate(2026, 9, 14);

  Future<List<String>> setUpDevice(E2eDevice d) async {
    d.clock.set(DateTime(2026, 9, 14, 5));
    await d.onboarding.acceptDisclaimer();
    expect(
      await d.onboarding.saveProfile(
        const ProfileDraft(
          height: '175',
          birthYear: 1996,
          sex: Sex.male,
          activityLevel: ActivityLevel.moderate,
          weight: '80',
        ),
      ),
      isEmpty,
    );
    expect(await d.onboarding.saveCalorie(), isTrue);
    expect(await d.onboarding.saveSchedule(template), isEmpty);
    await d.onboarding.complete(
      remindersEnabled: false,
      timezone: 'Asia/Ho_Chi_Minh',
    );
    expect(await d.sync(), SyncOutcome.synced);
    final chest = await d.exercises.watchGroup(MuscleGroup.chest).first;
    return [for (final e in chest.take(3)) e.id];
  }

  /// Đăng xuất như app (05 Bản 3 §6.6.6): đồng bộ hết → thu hồi phiên → xóa.
  Future<(LogoutOutcome, FakeDeviceFiles)> logout(E2eDevice d) async {
    final flag = MemoryLogoutFlag();
    final files = FakeDeviceFiles();
    final eraser = LocalDataEraser(
      files: files,
      session: d.store,
      marks: MemoryLocalMarks(2026),
      notifications: FakeNotificationGateway(),
      device: const NoLogoutDeviceHooks(),
      flag: flag,
      reporter: d.reporter,
    );
    final outcome = await Logout(
      connectivity: FakeConnectivity(),
      flush: d.engine.flush,
      revoke: d.auth.logout,
      session: d.store,
      device: const NoLogoutDeviceHooks(),
      flag: flag,
      finish: () => eraser.run(d.db),
    )();
    return (outcome, files);
  }

  /// Đơn vị, ghi chú, mức tạ trên máy (F09-R42).
  Future<Map<String, Object?>> liftData(E2eDevice d) async => {
    'units': [
      for (final u in await d.db.select(d.db.exerciseUnits).get())
        (u.exerciseId, u.unit, u.changedOn),
    ]..sort((a, b) => a.$1.compareTo(b.$1)),
    'notes': [
      for (final n in await d.db.select(d.db.exerciseNotes).get())
        (n.date, n.exerciseId, n.noteText),
    ],
    'logs': await d.liftLogs.watchAll().first,
  };

  test('F27-AC3, F27-AC5, F09-AC42, TAC3-10: ghi 2 bài khi mất mạng → đăng '
      'xuất (đồng bộ trước) → refresh token cũ bị từ chối → đăng nhập lại → '
      'đủ hồ sơ, cân nặng, lịch, mức tạ, đơn vị, ghi chú như trước', () async {
    final a = device();
    await a.register();
    final ids = await setUpDevice(a);
    a.clock.set(DateTime(2026, 9, 14, 8));
    await a.saveLift(monday, ids[0], start: '40', end: '45', unit: LiftUnit.kg);
    await a.saveLift(
      monday,
      ids[1],
      start: '8',
      end: '10',
      unit: LiftUnit.steps,
    );
    await a.saveNote(monday, ids[1], 'máy 2 hỏng');
    expect(
      (await a.status()).pending,
      5,
      reason: '2 đơn vị + 2 mức tạ + ghi chú',
    );
    final before = await liftData(a);
    final snapshot = await a.snapshot();
    final oldRefresh = (await a.store.read())!.refreshToken!;

    final (outcome, files) = await logout(a);
    expect(outcome, LogoutOutcome.done);
    expect(files.database, isFalse);
    expect(await a.store.read(), isNull);
    // Phiên đã thu hồi trên server.
    await expectLater(
      AuthRepository.refreshWith(ApiClient.create(server.baseUrl), oldRefresh),
      throwsA(
        isA<ServerFailure>().having(
          (f) => f.error.code,
          'code',
          ErrorCode.unauthorized,
        ),
      ),
    );

    // Đăng nhập lại trên "máy mới" (database đã xóa).
    final again = device();
    again.clock.set(DateTime(2026, 9, 14, 8, 30));
    await again.login();
    await again.restore();
    expect(await liftData(again), before);
    expect(await again.snapshot(), snapshot);
  });

  test('F27-E3: đăng xuất trong cửa sổ ghi tạ rồi đăng nhập lại trong ngày → '
      'vẫn sửa được mức tạ hôm nay', () async {
    final a = device();
    await a.register();
    final id = (await setUpDevice(a)).first;
    a.clock.set(DateTime(2026, 9, 14, 8));
    await a.saveLift(monday, id, start: '40', end: '45', unit: LiftUnit.kg);
    expect((await logout(a)).$1, LogoutOutcome.done);

    final again = device();
    again.clock.set(DateTime(2026, 9, 14, 8, 30));
    await again.login();
    await again.restore();
    await again.saveLift(monday, id, start: '40', end: '47,5');
    expect(await again.sync(), SyncOutcome.synced);
    expect((await again.liftLogs.get(monday, id))!.endKgX10, 475);
  });

  test('F27-E4: đăng nhập tài khoản khác sau đăng xuất → chỉ có dữ liệu của '
      'tài khoản đó', () async {
    final a = device();
    await a.register();
    final id = (await setUpDevice(a)).first;
    a.clock.set(DateTime(2026, 9, 14, 8));
    await a.saveLift(monday, id, start: '40', end: '45', unit: LiftUnit.kg);
    expect((await logout(a)).$1, LogoutOutcome.done);

    final b = device();
    await b.register(phone: '0987654321', name: 'Lan');
    final again = device();
    await again.login(phone: '0987654321');
    await again.restore();
    expect(await again.liftLogs.watchAll().first, isEmpty);
    expect(await again.db.select(again.db.exerciseUnits).get(), isEmpty);
    expect(await again.displayName(), 'Lan');
  });

  test('F27-R3: server lỗi khi đồng bộ → không đăng xuất, phiên và dữ liệu '
      'còn', () async {
    final a = device();
    await a.register();
    final id = (await setUpDevice(a)).first;
    a.clock.set(DateTime(2026, 9, 14, 8));
    await a.saveLift(monday, id, start: '40', end: '45', unit: LiftUnit.kg);
    await server.stop();
    final (outcome, files) = await logout(a);
    expect(outcome, LogoutOutcome.syncFailed);
    expect(files.database, isTrue);
    expect((await a.store.read())?.refreshToken, isNotNull);
    expect((await a.status()).pending, 2);
    server = await E2eServer.start();
  });
}
