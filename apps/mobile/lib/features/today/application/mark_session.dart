import 'package:api_contract/api_contract.dart';
import 'package:domain/domain.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../data/db/app_database.dart';
import '../../../data/sync/outbox_writer.dart';
import '../../../data/sync/sync_providers.dart';
import '../../schedule/data/schedule_repository.dart';

/// Đánh dấu buổi tập theo lịch (F-05, 06 §6.4.2): kiểm tra bằng domain, ghi
/// bản ghi ngày + outbox trong một transaction. Giao diện đổi ngay nhờ stream
/// của Drift, không chờ mạng (P6, TAC-01, F05-E5).
final class MarkSession {
  MarkSession({
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

  /// Ghi [mark] cho buổi ngày [date]; null = bỏ đánh dấu ("Hoàn tác", UA-09).
  /// [actual] = nhóm cơ thực tế khi "Đã tập" (F05-R4). Trả bản ghi mới; ném
  /// [MarkException] khi không đánh dấu được.
  Future<PlanDay> call(
    LocalDate date,
    DayMark? mark, {
    List<MuscleGroup>? actual,
  }) => _db.transaction(() async {
    final day = await _schedule.day(date);
    if (day == null) throw const MarkException(MarkError.notWorkout);
    final updated = SessionRules.mark(
      day,
      mark,
      actual: actual,
      now: _clock.now(),
    );
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

final markSessionProvider = Provider<MarkSession>(
  (ref) => MarkSession(
    db: ref.watch(databaseProvider),
    schedule: ref.watch(scheduleRepositoryProvider),
    outbox: ref.watch(outboxWriterProvider),
    clock: ref.watch(clockProvider),
  ),
);
