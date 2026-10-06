import 'package:api_contract/api_contract.dart';
import 'package:domain/domain.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../data/db/app_database.dart';
import '../../../data/sync/outbox_writer.dart';
import '../../../data/sync/sync_providers.dart';
import '../../schedule/data/schedule_repository.dart';

/// Thêm, sửa, xóa buổi tập thêm (F05-R7 → R11, 06 §6.4.2): kiểm tra bằng
/// domain, ghi bản ghi ngày + outbox trong một transaction. Thêm và sửa cùng
/// là ghi đè nhóm cơ (tối đa 1 buổi mỗi ngày, F05-R8); xóa = `extraMuscles:
/// null` (ED-08).
final class LogExtraSession {
  LogExtraSession({
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

  static const _codec = DayCodec();

  /// Ghi buổi tập thêm ngày [date] với [muscles]; null = xóa. Trả bản ghi
  /// mới; ném [ExtraException] khi không ghi được.
  Future<PlanDay> call(LocalDate date, List<MuscleGroup>? muscles) =>
      _db.transaction(() async {
        final day = await _schedule.day(date);
        if (day == null) throw const ExtraException(ExtraError.notRestDay);
        final updated = ExtraSessionRules.log(day, muscles, now: _clock.now());
        await _schedule.putDay(updated);
        await _outbox.enqueue(
          SyncEntities.day,
          date.toKey(),
          SyncOp.upsert,
          _codec.encode(updated),
        );
        return updated;
      });
}

final logExtraSessionProvider = Provider<LogExtraSession>(
  (ref) => LogExtraSession(
    db: ref.watch(databaseProvider),
    schedule: ref.watch(scheduleRepositoryProvider),
    outbox: ref.watch(outboxWriterProvider),
    clock: ref.watch(clockProvider),
  ),
);
