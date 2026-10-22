@Tags(['e2e'])
library;

import 'dart:io';

import 'package:domain/domain.dart';
import 'package:flutter_test/flutter_test.dart' hide pumpEventQueue;
import 'package:mobile/data/sync/sync_engine.dart';
import 'package:mobile/features/onboarding/data/onboarding_draft_repository.dart';
import 'package:server/server.dart' show LibraryImporter;
import 'package:server/testing.dart' show library28;

import 'sync_e2e_harness.dart';

/// 06 Bản 2 VS26-T08 (E2E): F09-AC21, F21-AC11, xung đột hai máy.
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

  // T2 Ngực 06:00. Giờ ghi tạ 08:00–09:00 nằm trong cửa sổ của thứ 2 dù máy
  // chạy test ở UTC hay giờ Việt Nam.
  final template = WeeklyTemplate({
    1: TemplateDay(
      enabled: true,
      time: LocalTime(6, 0),
      muscles: const [MuscleGroup.chest],
    ),
  });
  final monday = LocalDate(2026, 9, 14);

  /// Thiết lập lúc 05:00 thứ 2 14/09, đồng bộ để có thư viện trên máy.
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

  test(
    'F21-AC11, F09-AC21: không có mạng ghi 3 bài → "Chưa đồng bộ"; có '
    'mạng lại → đồng bộ, chỉ báo biến mất; máy B khôi phục → đủ 3 bản ghi',
    () async {
      final a = device();
      await a.register();
      final ids = await setUpDevice(a);
      a.clock.set(DateTime(2026, 9, 14, 8));
      for (final (i, id) in ids.indexed) {
        // Số hợp lệ cho cả kg lẫn số thanh (bài máy, 1–30).
        await a.saveLift(monday, id, start: '${4 + i * 5}', end: '${5 + i}');
      }
      expect((await a.status()).pending, 3, reason: 'chưa gọi sync = mất mạng');
      expect(await a.sync(), SyncOutcome.synced);
      expect((await a.status()).hasPending, isFalse);

      final b = device();
      await b.login();
      await b.restore();
      final restored = await b.liftLogs.watchAll().first;
      expect(restored, await a.liftLogs.watchAll().first);
      expect(
        [for (final l in restored) l.exerciseId]..sort(),
        [...ids]..sort(),
      );
      expect(await b.snapshot(), await a.snapshot());
    },
  );

  test('TA-11: hai máy cùng (ngày, bài) — bản lưu sau thắng ở cả hai máy; '
      'xóa trên một máy → máy kia cũng mất', () async {
    final a = device();
    await a.register();
    final id = (await setUpDevice(a)).first;
    final b = device();
    await b.login();
    await b.restore();

    a.clock.set(DateTime(2026, 9, 14, 8));
    await a.saveLift(monday, id, start: '5', end: '6');
    b.clock.set(DateTime(2026, 9, 14, 8, 5));
    await b.saveLift(monday, id, start: '5', end: '7');
    expect(await b.sync(), SyncOutcome.synced);
    expect(await a.sync(), SyncOutcome.synced);
    expect(a.reporter.reasons, ['sync_ignored_stale']);
    expect((await a.liftLogs.get(monday, id))!.endKgX10, 70);

    a.clock.set(DateTime(2026, 9, 14, 9));
    await a.deleteLift(monday, id);
    expect(await a.sync(), SyncOutcome.synced);
    expect(await b.sync(), SyncOutcome.synced);
    expect(await b.liftLogs.get(monday, id), isNull);
  });
}
