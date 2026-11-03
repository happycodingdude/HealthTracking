import 'package:domain/domain.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/data/db/app_database.dart';
import 'package:mobile/data/sync/outbox_writer.dart';
import 'package:mobile/features/me/application/reminders.dart';
import 'package:mobile/features/me/data/profile_repository.dart';
import 'package:mobile/features/schedule/application/pause_edits.dart';
import 'package:mobile/features/schedule/data/schedule_pause_repository.dart';
import 'package:mobile/features/schedule/data/schedule_repository.dart';
import 'package:mobile/features/today/application/mark_session.dart';

import '../../support/fake_notifications.dart';
import '../../support/schedule_fixture.dart';

final class _Hooks implements SessionMarkHooks {
  final ended = <LocalDate>[];

  @override
  Future<void> sessionMarked(LocalDate date) async => ended.add(date);
}

/// 06 Bản 5 VS56-T03: `StartPause`, `UpdatePauseEnd`, `EndPauseEarly` (05
/// Bản 5 §6.4.2) — bản ghi + outbox một transaction, hẹn lại nhắc (F04-R61),
/// tắt thẻ hôm nay khi bắt đầu tạm dừng (F31-R7). Lịch `templateAc2`: T2
/// 12/10 Ngực + Tay sau, T4 14/10 Lưng, T6 16/10 Vai, nhắc 17:00.
void main() {
  late AppDatabase db;
  late FixedClock clock;
  late FakeNotificationGateway notifications;
  late SchedulePauseRepository pauses;
  late _Hooks hooks;
  late PauseEdits edits;
  final mon = LocalDate(2026, 10, 12);
  final wed = LocalDate(2026, 10, 14);
  final thu = LocalDate(2026, 10, 15);
  final fri = LocalDate(2026, 10, 16);
  final sat = LocalDate(2026, 10, 17);
  final sun = LocalDate(2026, 10, 18);

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    clock = FixedClock(DateTime(2026, 10, 14, 10));
    notifications = FakeNotificationGateway();
    final schedule = ScheduleRepository(db);
    pauses = SchedulePauseRepository(db);
    hooks = _Hooks();
    edits = PauseEdits(
      db: db,
      pauses: pauses,
      outbox: OutboxWriter(db, clock),
      reminders: ReminderScheduler(
        gateway: notifications,
        profiles: ProfileRepository(db),
        schedule: schedule,
        clock: clock,
        pauses: pauses,
      ),
      liveActivity: hooks,
      clock: clock,
    );
    await seedSetUp(db, profile: completedProfile(remindersEnabled: true));
  });

  List<DateTime> remindersOn(LocalDate date) => [
    for (final n in notifications.scheduled)
      if (LocalDate.fromDateTime(n.at) == date) n.at,
  ];

  Future<List<String>> outbox() async => [
    for (final o in await db.select(db.outbox).get())
      '${o.entity}:${o.op}:${o.entityKey}',
  ];

  test('F04-AC61, F31-R7: tạm dừng T4 → CN lúc 10:00 T4 → không nhắc 17:00 '
      'T4, T6; thẻ hôm nay tắt; outbox schedule_pause; F04-AC61: kết thúc sớm '
      'lúc 15:00 cùng ngày (ngày A) → xóa khoảng, lại có nhắc 17:00', () async {
    final p = await edits.start(wed, sun);
    expect((p.startDate, p.endDate, p.endedOn), (wed, sun, null));
    expect(await pauses.all(), [p]);
    expect(remindersOn(wed), isEmpty);
    expect(remindersOn(fri), isEmpty);
    expect(remindersOn(LocalDate(2026, 10, 19)), [DateTime(2026, 10, 19, 17)]);
    expect(hooks.ended, [wed]);
    expect(await outbox(), contains('schedule_pause:upsert:${p.id}'));

    clock.set(DateTime(2026, 10, 14, 15));
    await edits.endEarly(p);
    expect(await pauses.all(), isEmpty);
    expect(await outbox(), contains('schedule_pause:delete:${p.id}'));
    expect(remindersOn(wed), [DateTime(2026, 10, 14, 17)]);
    expect(remindersOn(fri), [DateTime(2026, 10, 16, 17)]);
  });

  test('F31-E3: đặt tạm dừng từ ngày mai → hôm nay vẫn bình thường (thẻ, nhắc '
      'hôm nay giữ)', () async {
    clock.set(DateTime(2026, 10, 13, 9));
    await edits.start(wed, sun);
    expect(hooks.ended, isEmpty);
    expect(remindersOn(mon.addDays(1)), isEmpty);
    expect(remindersOn(wed), isEmpty);
  });

  test('F31-R8, F31-AC4: kết thúc sớm thứ 7 → khoảng kết thúc thứ 6, CN và '
      'tuần sau chạy lại', () async {
    final p = await edits.start(wed, sun);
    clock.set(DateTime(2026, 10, 17, 9));
    await edits.endEarly(p);
    final ended = (await pauses.all()).single;
    expect(ended.endedOn, fri);
    expect(ended.covers(fri), isTrue);
    expect(ended.covers(sat), isFalse);
    expect(PauseRules.active(await pauses.all(), sat), isNull);
  });

  test('F31-R9, F31-V3: rút ngày kết thúc về T5 → T6 lại có nhắc; sửa về ngày '
      'đã qua → endInPast', () async {
    final p = await edits.start(wed, sun);
    final shorter = await edits.updateEnd(p, thu);
    expect(shorter.endDate, thu);
    expect(remindersOn(fri), [DateTime(2026, 10, 16, 17)]);
    clock.set(DateTime(2026, 10, 15, 9));
    await expectLater(
      edits.updateEnd(shorter, wed),
      throwsA(
        isA<PauseException>().having(
          (e) => e.error,
          'error',
          PauseError.endInPast,
        ),
      ),
    );
  });

  test('F31-R1, F31-AC6: đang có khoảng → không tạo khoảng thứ hai; F31-V1: '
      'ngày bắt đầu đã qua', () async {
    await edits.start(wed, sun);
    await expectLater(
      edits.start(LocalDate(2026, 10, 20), LocalDate(2026, 10, 21)),
      throwsA(
        isA<PauseException>().having(
          (e) => e.error,
          'error',
          PauseError.overlap,
        ),
      ),
    );
    expect(await pauses.all(), hasLength(1));
    final other = SchedulePauseRepository(db);
    expect((await other.all()).single.startDate, wed);
    await expectLater(edits.start(mon, sun), throwsA(isA<PauseException>()));
  });
}
