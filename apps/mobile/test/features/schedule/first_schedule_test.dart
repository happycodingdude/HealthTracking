import 'package:api_contract/api_contract.dart';
import 'package:domain/domain.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/data/db/app_database.dart';
import 'package:mobile/data/sync/outbox_writer.dart';
import 'package:mobile/features/me/application/reminders.dart';
import 'package:mobile/features/me/data/account_repository.dart';
import 'package:mobile/features/me/data/profile_repository.dart';
import 'package:mobile/features/onboarding/application/onboarding_steps.dart';
import 'package:mobile/features/onboarding/data/onboarding_draft_repository.dart';
import 'package:mobile/features/schedule/application/month_materializer.dart';
import 'package:mobile/features/schedule/application/schedule_edits.dart';
import 'package:mobile/features/schedule/data/schedule_repository.dart';
import 'package:mobile/features/today/application/mark_session.dart';
import 'package:mobile/features/weight/data/weight_repository.dart';

import '../../support/fake_notifications.dart';
import '../../support/schedule_fixture.dart';

/// VS-25: "Để sau" ở bước lịch tuần, trạng thái Chưa có lịch, lần lưu lịch
/// tuần đầu tiên (03 Bản 2 §6.2, §6.3; 05 Bản 2 §6.4.1, §6.4.4, TD2-09).
void main() {
  late AppDatabase db;
  late FixedClock clock;
  late FakeNotificationGateway notifications;
  late ScheduleRepository schedule;
  late ProfileRepository profiles;
  late ReminderScheduler reminders;
  late ScheduleEdits edits;
  late OutboxWriter outbox;

  // templateAc23: thứ 4 Lưng 18:00, thứ 6 Vai 18:00 (06 Bản 2 §6.9).
  final ac23 = WeeklyTemplate({
    3: TemplateDay(
      enabled: true,
      time: LocalTime(18, 0),
      muscles: const [MuscleGroup.back],
    ),
    5: TemplateDay(
      enabled: true,
      time: LocalTime(18, 0),
      muscles: const [MuscleGroup.shoulders],
    ),
  });

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    // 12:00 thứ 4 14/10/2026.
    clock = FixedClock(DateTime(2026, 10, 14, 12));
    notifications = FakeNotificationGateway();
    schedule = ScheduleRepository(db);
    profiles = ProfileRepository(db);
    outbox = OutboxWriter(db, clock);
    reminders = ReminderScheduler(
      gateway: notifications,
      profiles: profiles,
      schedule: schedule,
      clock: clock,
    );
    edits = ScheduleEdits(
      db: db,
      schedule: schedule,
      outbox: outbox,
      reminders: reminders,
      profiles: profiles,
      clock: clock,
    );
    // Tài khoản Chưa có lịch: hoàn tất thiết lập 07/10 với "Để sau", bật nhắc.
    await AccountRepository(db).put('Minh');
    await profiles.put(completedProfile(remindersEnabled: true));
  });

  Future<List<SyncMutation>> mutations() async => [
    for (final o in await db.select(db.outbox).get()) o.toMutation(),
  ];

  test('F03-AC21, VS25-T02: "Để sau" ở bước 4 → không lưu lịch nào, bỏ các '
      'ngày đang chọn dở, sang bước 5', () async {
    await profiles.put(const Profile(onboardingStep: 4));
    final drafts = OnboardingDraftRepository(db);
    await drafts.saveTemplate(ac23);
    final steps = OnboardingSteps(
      db: db,
      profiles: profiles,
      weights: WeightRepository(db),
      drafts: drafts,
      schedule: schedule,
      outbox: outbox,
      clock: clock,
    );
    await steps.skipSchedule();
    expect((await profiles.get())!.onboardingStep, 5);
    expect(await schedule.template(), isNull);
    expect(await drafts.template(), isNull);
    expect(
      [for (final m in await mutations()) m.entity],
      [SyncEntities.profile],
    );
  });

  test('F04-R22, F04-AC23: Chưa có lịch, công tắc bật → không hẹn nhắc nào; '
      'chia tháng mới không làm gì (F03-R25)', () async {
    expect(await reminders.reschedule(), 0);
    expect(notifications.scheduled, isEmpty);
    clock.set(DateTime(2026, 11, 1, 0, 1));
    final materializer = MonthMaterializer(
      db: db,
      schedule: schedule,
      outbox: outbox,
      clock: clock,
    );
    expect(await materializer.run(), isFalse);
    expect(await schedule.plan(YearMonth(2026, 11)), isNull);
  });

  test('F03-AC23, F04-R23: 12:00 thứ 4 14/10 lưu lịch tuần lần đầu → lịch '
      'tháng 10 có 14, 16, 21, 23, 28, 30 (không ngày nào trước 14/10); ghi '
      'scheduleStartedOn = 14/10; nhắc 17:00 ngay hôm nay', () async {
    expect(await edits.saveTemplate(ac23), isEmpty);
    final days = await schedule.monthDays(YearMonth(2026, 10));
    expect(
      [
        for (final d in days)
          if (d.isWorkout) d.date.day,
      ],
      [14, 16, 21, 23, 28, 30],
    );
    expect(
      days.every((d) => !d.date.isBefore(LocalDate(2026, 10, 14))),
      isTrue,
    );
    final plan = (await schedule.plan(YearMonth(2026, 10)))!;
    expect(plan.startDate, LocalDate(2026, 10, 14));
    expect(plan.templateHash, ac23.contentHash, reason: 'không có banner');
    expect((await profiles.get())!.scheduleStartedOn, LocalDate(2026, 10, 14));
    final ms = await mutations();
    expect(ms.first.entity, SyncEntities.weeklyTemplate);
    expect(
      ms.where((m) => m.entity == SyncEntities.monthPlan).single.op,
      SyncOp.ensure,
    );
    expect(
      ms.where((m) => m.entity == SyncEntities.day).map((m) => m.op).toSet(),
      {SyncOp.ensure},
    );
    expect(
      const ProfileCodec()
          .decode(ms.firstWhere((m) => m.entity == SyncEntities.profile).data!)
          .scheduleStartedOn,
      LocalDate(2026, 10, 14),
    );
    expect(notifications.scheduled.first.at, DateTime(2026, 10, 14, 17));
  });

  test('F03-AC24: lưu lần hai → như Bản 1 (lịch tháng không đổi), mốc giữ '
      'nguyên', () async {
    await edits.saveTemplate(ac23);
    clock.set(DateTime(2026, 10, 15, 9));
    await edits.saveTemplate(templateAc2);
    expect((await profiles.get())!.scheduleStartedOn, LocalDate(2026, 10, 14));
    expect(
      (await schedule.plan(YearMonth(2026, 10)))!.templateHash,
      ac23.contentHash,
      reason: 'đổi lịch tuần sau đó cần Chia lại (banner)',
    );
  });

  test('F03-E24: lưu lần đầu vào chủ nhật cuối tháng (31/05/2026) → tháng '
      'này không có buổi nào; 00:00 ngày 1 tháng sau tự chia', () async {
    clock.set(DateTime(2026, 5, 31, 9));
    await edits.saveTemplate(ac23);
    final may = await schedule.monthDays(YearMonth(2026, 5));
    expect(may.where((d) => d.isWorkout), isEmpty);
    clock.set(DateTime(2026, 6, 1, 0, 1));
    final materializer = MonthMaterializer(
      db: db,
      schedule: schedule,
      outbox: outbox,
      clock: clock,
    );
    expect(await materializer.run(), isTrue);
    final june = await schedule.monthDays(YearMonth(2026, 6));
    expect(june.where((d) => d.isWorkout).first.date, LocalDate(2026, 6, 3));
  });

  test(
    'F05-R31, F05-AC27: Chưa có lịch → AddExtraSession bị từ chối',
    () async {
      final add = AddExtraSession(
        db: db,
        schedule: schedule,
        outbox: outbox,
        clock: clock,
      );
      await expectLater(
        add(LocalDate(2026, 10, 13), const [MuscleGroup.abs], confirmed: true),
        throwsA(
          isA<ExtraException>().having(
            (e) => e.error,
            'error',
            ExtraError.noSchedule,
          ),
        ),
      );
      expect(await db.select(db.outbox).get(), isEmpty);
    },
  );
}
