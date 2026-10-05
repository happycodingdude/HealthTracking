import 'package:api_contract/api_contract.dart';
import 'package:domain/domain.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../data/db/app_database.dart';
import '../../../data/sync/outbox_writer.dart';
import '../../../data/sync/sync_providers.dart';
import '../data/schedule_repository.dart';

/// Tạo lịch tháng mới theo lịch tuần hiện tại (F03-R6, 05 §6.4.4). Chạy khi
/// app khởi động, khi quay lại foreground và khi qua 00:00 lúc đang mở.
///
/// Chỉ tạo khi tháng hiện tại chưa có lịch, và chỉ dùng `ensure`: chạy nhiều
/// lần hay trên nhiều máy đều không ghi đè ngày đã có (TR-11).
final class MonthMaterializer {
  MonthMaterializer({
    required AppDatabase db,
    required ScheduleRepository schedule,
    required OutboxWriter outbox,
    required Clock clock,
  }) : _db = db,
       _schedule = schedule,
       _outbox = outbox,
       _clock = clock;

  final AppDatabase _db;
  final ScheduleRepository _schedule;
  final OutboxWriter _outbox;
  final Clock _clock;

  static const _planCodec = MonthPlanCodec();
  static const _dayCodec = DayCodec();

  /// true khi vừa tạo lịch cho tháng hiện tại.
  Future<bool> run() => _db.transaction(() async {
    final template = await _schedule.template();
    if (template == null) return false;
    final now = _clock.now();
    final month = LocalDate.fromDateTime(now).yearMonth;
    if (await _schedule.plan(month) != null) return false;
    final generated = MonthGenerator.month(template, month, now);
    await _schedule.putPlan(generated.plan);
    await _outbox.enqueue(
      SyncEntities.monthPlan,
      MonthPlanCodec.keyOf(month),
      SyncOp.ensure,
      _planCodec.encode(generated.plan),
    );
    for (final day in generated.days) {
      if (await _schedule.day(day.date) != null) continue;
      await _schedule.putDay(day);
      await _outbox.enqueue(
        SyncEntities.day,
        day.date.toKey(),
        SyncOp.ensure,
        _dayCodec.encode(day),
      );
    }
    return true;
  });
}

final monthMaterializerProvider = Provider<MonthMaterializer>(
  (ref) => MonthMaterializer(
    db: ref.watch(databaseProvider),
    schedule: ref.watch(scheduleRepositoryProvider),
    outbox: ref.watch(outboxWriterProvider),
    clock: ref.watch(clockProvider),
  ),
);
