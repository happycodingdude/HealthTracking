import 'package:api_contract/api_contract.dart';
import 'package:domain/domain.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../data/db/app_database.dart';
import '../../../data/sync/outbox_writer.dart';
import '../../../data/sync/sync_providers.dart';
import '../../me/application/reminders.dart';
import '../data/schedule_repository.dart';

/// Thay đổi lịch sau khi thiết lập (F03-R7 → R10): sửa riêng một ngày, trả
/// về theo lịch tuần, sửa lịch tuần, chia lại. Mỗi thao tác là một
/// transaction (bản ghi + outbox, 06 §6.4.2); xong thì hẹn lại nhắc (F03-R12,
/// F04-R7, F04-E4).
final class ScheduleEdits {
  ScheduleEdits({
    required AppDatabase db,
    required ScheduleRepository schedule,
    required OutboxWriter outbox,
    required ReminderScheduler reminders,
    required Clock clock,
  }) : _db = db,
       _schedule = schedule,
       _outbox = outbox,
       _reminders = reminders,
       _clock = clock;

  final AppDatabase _db;
  final ScheduleRepository _schedule;
  final OutboxWriter _outbox;
  final ReminderScheduler _reminders;
  final Clock _clock;

  static const _dayCodec = DayCodec();
  static const _planCodec = MonthPlanCodec();
  static const _templateCodec = WeeklyTemplateCodec();

  Future<void> _putDay(PlanDay day) async {
    await _schedule.putDay(day);
    await _outbox.enqueue(
      SyncEntities.day,
      day.date.toKey(),
      SyncOp.upsert,
      _dayCodec.encode(day),
    );
  }

  /// Sửa riêng ngày [date] thành ngày tập ([time], [muscles]) hoặc ngày nghỉ
  /// ([time] null) (F03-R9). Ném [OverrideException].
  Future<PlanDay> overrideDay(
    LocalDate date, {
    LocalTime? time,
    List<MuscleGroup> muscles = const [],
  }) async {
    final updated = await _db.transaction(() async {
      final day = await _schedule.day(date);
      if (day == null) throw const OverrideException(OverrideError.notEditable);
      final next = OverrideRules.override(
        day,
        time: time,
        muscles: muscles,
        now: _clock.now(),
      );
      await _putDay(next);
      return next;
    });
    await _reminders.reschedule();
    return updated;
  }

  /// "Trả về theo lịch tuần" (F03-R10). Ném [OverrideException].
  Future<PlanDay> revertDay(LocalDate date) async {
    final updated = await _db.transaction(() async {
      final day = await _schedule.day(date);
      final template = await _schedule.template();
      if (day == null || template == null) {
        throw const OverrideException(OverrideError.notEditable);
      }
      final next = OverrideRules.revert(day, template, now: _clock.now());
      await _putDay(next);
      return next;
    });
    await _reminders.reschedule();
    return updated;
  }

  /// Lưu lịch tuần ở S-22 (F03-R7): lịch tháng hiện tại không đổi; tháng sau
  /// (và nhắc của tháng sau) theo lịch mới. Trả lỗi F03-V1 → V3, rỗng = đã
  /// lưu.
  Future<List<TemplateError>> saveTemplate(WeeklyTemplate template) async {
    final errors = template.validate();
    if (errors.isNotEmpty) return errors;
    await _db.transaction(() async {
      await _schedule.putTemplate(template);
      await _outbox.enqueue(
        SyncEntities.weeklyTemplate,
        WeeklyTemplateCodec.key,
        SyncOp.upsert,
        _templateCodec.encode(template),
      );
    });
    await _reminders.reschedule();
    return const [];
  }

  /// Chia lại lịch tháng hiện tại theo lịch tuần (F03-R8). null khi tháng
  /// hiện tại chưa có lịch hoặc chưa có lịch tuần.
  Future<Redistribution?> redistribute() async {
    final result = await _db.transaction(() async {
      final now = _clock.now();
      final month = LocalDate.fromDateTime(now).yearMonth;
      final template = await _schedule.template();
      final plan = await _schedule.plan(month);
      if (template == null || plan == null) return null;
      final r = Redistributor.apply(
        days: await _schedule.monthDays(month),
        template: template,
        now: now,
      );
      final next = MonthPlan(
        month: plan.month,
        startDate: plan.startDate,
        templateHash: template.contentHash,
        generatedAt: plan.generatedAt,
        redistributedAt: now,
      );
      await _schedule.putPlan(next);
      await _outbox.enqueue(
        SyncEntities.monthPlan,
        MonthPlanCodec.keyOf(month),
        SyncOp.upsert,
        _planCodec.encode(next),
      );
      for (final d in r.changed) {
        await _putDay(d);
      }
      return r;
    });
    await _reminders.reschedule();
    return result;
  }
}

final scheduleEditsProvider = Provider<ScheduleEdits>(
  (ref) => ScheduleEdits(
    db: ref.watch(databaseProvider),
    schedule: ref.watch(scheduleRepositoryProvider),
    outbox: ref.watch(outboxWriterProvider),
    reminders: ref.watch(reminderSchedulerProvider),
    clock: ref.watch(clockProvider),
  ),
);
