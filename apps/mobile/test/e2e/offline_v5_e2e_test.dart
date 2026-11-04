@Tags(['e2e'])
library;

import 'dart:io';

import 'package:domain/domain.dart';
import 'package:flutter_test/flutter_test.dart' hide pumpEventQueue;
import 'package:mobile/data/sync/outbox_writer.dart';
import 'package:mobile/data/sync/sync_engine.dart';
import 'package:mobile/features/me/application/gym_location.dart';
import 'package:mobile/features/me/application/reminders.dart';
import 'package:mobile/features/onboarding/data/onboarding_draft_repository.dart';
import 'package:mobile/features/schedule/application/pause_edits.dart';
import 'package:mobile/features/today/application/mark_session.dart';
import 'package:mobile/features/workout/application/lift_log_edits.dart';
import 'package:mobile/features/workout/application/session_item_edits.dart';
import 'package:server/server.dart' show LibraryImporter;
import 'package:server/testing.dart' show library28;

import '../support/fake_native.dart';
import '../support/fake_notifications.dart';
import 'sync_e2e_harness.dart';

/// 06 Bản 5 VS60-T05 (E2E): F09-AC61, UX-AC61 — đổi bài, bỏ qua bài, thêm
/// bài, mức thoải mái, đặt tạm dừng, lưu vị trí phòng gym khi không có mạng
/// (chưa gọi sync) → "Chưa đồng bộ"; có mạng → đồng bộ, server nhận hết; máy
/// khác đăng nhập khôi phục → tất cả còn đúng (F09-R61, TR5-03).
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

  // T2 Ngực 06:00; ghi lúc 08:00 nằm trong cửa sổ dù máy chạy test ở UTC hay
  // giờ Việt Nam.
  final template = WeeklyTemplate({
    1: TemplateDay(
      enabled: true,
      time: LocalTime(6, 0),
      muscles: const [MuscleGroup.chest],
    ),
  });
  final monday = LocalDate(2026, 9, 14);

  Future<void> setUpDevice(E2eDevice d) async {
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
  }

  test('F09-AC61, UX-AC61: đổi / bỏ qua / thêm bài, mức thoải mái, tạm dừng, '
      'vị trí phòng gym khi không có mạng → "Chưa đồng bộ"; có mạng → server '
      'nhận đủ; máy B khôi phục → tất cả còn đúng', () async {
    final a = device();
    await a.register();
    await setUpDevice(a);
    a.clock.set(DateTime(2026, 9, 14, 8));

    final outbox = OutboxWriter(a.db, a.clock);
    final mutator = SessionItemMutator(
      logs: a.liftLogs,
      notes: a.notes,
      feels: a.feels,
      rows: a.sessionRows,
      outbox: outbox,
    );
    final chest = [
      for (final e in await a.exercises.watchGroup(MuscleGroup.chest).first)
        if (e.active) e,
    ];
    final back = (await a.exercises.watchGroup(MuscleGroup.back).first)
        .firstWhere((e) => e.active);
    final abs = (await a.exercises.watchGroup(MuscleGroup.abs).first)
        .firstWhere((e) => e.active);

    await ReplaceExercise(
      db: a.db,
      schedule: a.schedule,
      exercises: a.exercises,
      logs: a.liftLogs,
      rows: a.sessionRows,
      mutator: mutator,
      clock: a.clock,
    )(monday, chest[1].id, back.id);
    await SkipExercise(
      db: a.db,
      schedule: a.schedule,
      exercises: a.exercises,
      logs: a.liftLogs,
      rows: a.sessionRows,
      mutator: mutator,
      clock: a.clock,
    )(monday, chest[2].id, skipped: true);
    await AddExtraExercise(
      db: a.db,
      schedule: a.schedule,
      exercises: a.exercises,
      logs: a.liftLogs,
      rows: a.sessionRows,
      mutator: mutator,
      clock: a.clock,
    )(monday, abs.id);
    await SaveExerciseFeel(
      db: a.db,
      feels: a.feels,
      schedule: a.schedule,
      exercises: a.exercises,
      outbox: outbox,
      clock: a.clock,
    )(monday, chest[0].id, Feel.hard);
    final pause = await PauseEdits(
      db: a.db,
      pauses: a.pauses,
      outbox: outbox,
      reminders: ReminderScheduler(
        gateway: FakeNotificationGateway(),
        profiles: a.profiles,
        schedule: a.schedule,
        clock: a.clock,
        pauses: a.pauses,
      ),
      liveActivity: const NoSessionMarkHooks(),
      clock: a.clock,
    ).start(monday.addDays(2), monday.addDays(5));
    final bridge = FakeGymRegionBridge();
    expect(
      await GymLocationEdits(
        db: a.db,
        repo: a.gyms,
        outbox: outbox,
        bridge: bridge,
        clock: a.clock,
      ).save(),
      GymSaveResult.saved,
    );

    // Chưa gọi sync = mất mạng: 3 dòng bài trong buổi, 1 mức thoải mái, 1
    // khoảng tạm dừng, 1 vị trí — tất cả "Chưa đồng bộ".
    expect((await a.status()).pending, 6, reason: 'outbox Bản 5');
    expect(await a.sync(), SyncOutcome.synced);
    expect(a.reporter.reasons, isEmpty);
    expect((await a.status()).hasPending, isFalse);

    // Máy B (đổi máy, đăng nhập lại) khôi phục.
    final b = device();
    b.clock.set(DateTime(2026, 9, 14, 9));
    await b.login();
    await b.restore();
    expect(b.reporter.reasons, isEmpty);
    final rows = {
      for (final r in await b.sessionRows.day(monday)) r.exerciseId: r,
    };
    expect(rows.keys.toSet(), {back.id, chest[2].id, abs.id});
    expect(rows[back.id]!.role, SessionExerciseRole.replacement);
    expect(rows[back.id]!.replacesExerciseId, chest[1].id);
    expect(rows[chest[2].id]!.skipped, isTrue);
    expect(rows[abs.id]!.role, SessionExerciseRole.extra);
    expect((await b.feels.get(monday, chest[0].id))!.feel, Feel.hard);
    final restored = (await b.pauses.all()).single;
    expect(
      (restored.id, restored.startDate, restored.endDate),
      (pause.id, monday.addDays(2), monday.addDays(5)),
    );
    final gym = (await b.gyms.get())!;
    expect((gym.lat, gym.lng, gym.enabled), (10.770123, 106.690457, true));
  });
}
