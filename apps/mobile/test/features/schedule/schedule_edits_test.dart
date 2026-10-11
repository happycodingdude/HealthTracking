import 'package:api_contract/api_contract.dart';
import 'package:domain/domain.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/data/db/app_database.dart';
import 'package:mobile/data/sync/outbox_writer.dart';
import 'package:mobile/features/me/application/reminders.dart';
import 'package:mobile/features/me/data/profile_repository.dart';
import 'package:mobile/features/schedule/application/schedule_edits.dart';
import 'package:mobile/features/schedule/data/schedule_repository.dart';

import '../../support/fake_notifications.dart';
import '../../support/schedule_fixture.dart';

void main() {
  late AppDatabase db;
  late FixedClock clock;
  late FakeNotificationGateway notifications;
  late ScheduleRepository schedule;
  late ScheduleEdits edits;

  // templateAc2, thiết lập 12:00 ngày 07/10; hôm nay 10:00 thứ 4 14/10.
  final wed14 = LocalDate(2026, 10, 14);
  final shouldersOnWed = WeeklyTemplate({
    ...templateAc2.days,
    3: TemplateDay(
      enabled: true,
      time: LocalTime(18, 0),
      muscles: const [MuscleGroup.shoulders],
    ),
  });

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    clock = FixedClock(DateTime(2026, 10, 14, 10));
    notifications = FakeNotificationGateway();
    schedule = ScheduleRepository(db);
    final profiles = ProfileRepository(db);
    edits = ScheduleEdits(
      db: db,
      schedule: schedule,
      outbox: OutboxWriter(db, clock),
      reminders: ReminderScheduler(
        gateway: notifications,
        profiles: profiles,
        schedule: schedule,
        clock: clock,
      ),
      profiles: profiles,
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
      '${o.entity}:${o.entityKey}',
  ];

  test('F04-AC4, F03-R12: đổi giờ buổi 18:00 → 19:00 trước 17:00 → nhắc lúc '
      '18:00, không nhắc lúc 17:00; ngày mang nhãn "Đã sửa riêng"', () async {
    final d = await edits.overrideDay(
      wed14,
      time: LocalTime(19, 0),
      muscles: const [MuscleGroup.back],
    );
    expect(d.source, DaySource.override);
    expect(remindersOn(wed14), [DateTime(2026, 10, 14, 18)]);
    expect(await outbox(), contains('day:2026-10-14'));
  });

  test('F04-E4, F03-E1: cho nghỉ hôm nay khi buổi chưa đến giờ → nhắc của '
      'ngày đó bị hủy', () async {
    await edits.overrideDay(wed14);
    expect((await schedule.day(wed14))!.isWorkout, isFalse);
    expect(remindersOn(wed14), isEmpty);
    expect(remindersOn(LocalDate(2026, 10, 16)), isNotEmpty);
  });

  test(
    'F03-AC8: thứ 5 23/10 (nghỉ) thành Bụng 18:00 → có buổi, nhắc 17:00',
    () async {
      final thu = LocalDate(2026, 10, 23);
      await edits.overrideDay(
        thu,
        time: LocalTime(18, 0),
        muscles: const [MuscleGroup.abs],
      );
      expect(remindersOn(thu), [DateTime(2026, 10, 23, 17)]);
    },
  );

  test('F03-AC9: ngày đã qua → OverrideException, không ghi gì', () async {
    await expectLater(
      edits.overrideDay(LocalDate(2026, 10, 13)),
      throwsA(isA<OverrideException>()),
    );
    expect(await outbox(), isEmpty);
  });

  test('F03-R10: trả về theo lịch tuần → lấy lịch tuần hiện tại, bỏ "Đã sửa '
      'riêng"', () async {
    final wed21 = LocalDate(2026, 10, 21);
    await edits.overrideDay(wed21);
    final back = await edits.revertDay(wed21);
    expect(back.isWorkout, isTrue);
    expect(back.source, DaySource.template);
    expect(remindersOn(wed21), [DateTime(2026, 10, 21, 17)]);
  });

  test('F03-AC5, F03-R7: sửa lịch tuần thứ 4 Lưng → Vai, chưa chia lại → các '
      'thứ 4 tháng 10 vẫn Lưng; thứ 4 tháng 11 (nhắc suy ra từ lịch tuần) là '
      'Vai', () async {
    expect(await edits.saveTemplate(shouldersOnWed), isEmpty);
    expect(
      (await schedule.template())!.contentHash,
      shouldersOnWed.contentHash,
    );
    for (final d in [14, 21, 28]) {
      expect((await schedule.day(LocalDate(2026, 10, d)))!.muscles, [
        MuscleGroup.back,
      ]);
    }
    expect(
      (await schedule.plan(YearMonth(2026, 10)))!.templateHash,
      templateAc2.contentHash,
    );
    final nov4 = notifications.scheduled.where(
      (n) => LocalDate.fromDateTime(n.at) == LocalDate(2026, 11, 4),
    );
    expect(nov4.single.body, contains('vai'));
    expect(await outbox(), ['weekly_template:me']);
  });

  test('F03-V1 → V3: lịch tuần không hợp lệ → trả lỗi, không lưu', () async {
    final errors = await edits.saveTemplate(WeeklyTemplate(const {}));
    expect(errors.single.issue, TemplateIssue.noWorkoutDay);
    expect(await outbox(), isEmpty);
  });

  test('F03-AC6, F03-AC7, F03-R8: 10:00 ngày 14/10 chia lại → thứ 4 14, 28/10 '
      'thành Vai; 21/10 đã sửa riêng thành nghỉ được giữ (báo 1 ngày); lịch '
      'tháng mang hash lịch tuần mới', () async {
    await edits.overrideDay(LocalDate(2026, 10, 21));
    await edits.saveTemplate(shouldersOnWed);
    final r = (await edits.redistribute())!;
    expect((r.from, r.to), (wed14, LocalDate(2026, 10, 31)));
    expect(r.keptOverrides, 1);
    expect(r.changed.map((d) => d.date.day), [14, 28]);
    for (final d in [14, 28]) {
      expect((await schedule.day(LocalDate(2026, 10, d)))!.muscles, [
        MuscleGroup.shoulders,
      ]);
    }
    expect((await schedule.day(LocalDate(2026, 10, 21)))!.isWorkout, isFalse);
    final plan = (await schedule.plan(YearMonth(2026, 10)))!;
    expect(plan.templateHash, shouldersOnWed.contentHash);
    expect(plan.redistributedAt, DateTime(2026, 10, 14, 10));
    final rows = await db.select(db.outbox).get();
    final planRow = rows.firstWhere((o) => o.entity == 'month_plan');
    expect(planRow.toMutation().op, SyncOp.upsert);
    expect(remindersOn(wed14).single, DateTime(2026, 10, 14, 17));
  });
}
