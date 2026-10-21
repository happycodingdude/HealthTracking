import 'package:api_contract/api_contract.dart';
import 'package:domain/domain.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../data/db/app_database.dart';
import '../../../data/sync/outbox_writer.dart';
import '../../../data/sync/sync_providers.dart';
import '../../library/data/exercise_repository.dart';
import '../../schedule/data/schedule_repository.dart';
import '../data/lift_log_repository.dart';
import 'lift_unit.dart';

/// Ghi, xóa mức tạ (F-21, 05 Bản 2 §6.4.1). Mỗi thao tác là một transaction
/// (bản ghi + outbox); không cần mạng (F21-R10). Cửa sổ tính lại với giờ lúc
/// bấm Lưu (FA2-17, F21-R12).
abstract base class _LiftWrite {
  _LiftWrite({
    required AppDatabase db,
    required LiftLogRepository logs,
    required ScheduleRepository schedule,
    required ExerciseRepository exercises,
    required OutboxWriter outbox,
    required Clock clock,
  }) : _db = db,
       _logs = logs,
       _schedule = schedule,
       _exercises = exercises,
       _outbox = outbox,
       _clock = clock;

  final AppDatabase _db;
  final LiftLogRepository _logs;
  final ScheduleRepository _schedule;
  final ExerciseRepository _exercises;
  final OutboxWriter _outbox;
  final Clock _clock;

  /// 05 Bản 2 §6.6.2 bước 1 → 4 với giờ hiện tại. Ném [LiftException].
  Future<void> _check(
    LocalDate date,
    String exerciseId, {
    required bool exists,
  }) async {
    final error = LiftLogRules.check(
      day: await _schedule.day(date),
      exercise: await _exercises.get(exerciseId),
      now: _clock.now(),
      exists: exists,
    );
    if (error != null) throw LiftException(error);
  }
}

/// Lưu mức tạ bắt đầu, kết thúc của bài [exerciseId] trong buổi ngày [date]
/// (S-64): kiểm tra F21-V1 → V4 rồi buổi, cửa sổ, bài; ghi đè bản cũ nếu có.
/// Ném [LiftInputException] hoặc [LiftException] (ngoài cửa sổ →
/// [LiftError.windowClosed], S-64 hiện "Mức tạ của buổi này đã khóa lúc
/// 00:00.").
final class SaveLiftLog extends _LiftWrite {
  SaveLiftLog({
    required super.db,
    required super.logs,
    required super.schedule,
    required super.exercises,
    required super.outbox,
    required super.clock,
  });

  static const _codec = LiftLogCodec();

  Future<LiftLog> call(
    LocalDate date,
    String exerciseId, {
    required String start,
    required String end,
  }) async {
    // Đơn vị theo dụng cụ của bài; bài không có thì [_check] từ chối sau.
    final unit = (await _exercises.get(exerciseId))?.liftUnit ?? LiftUnit.kg;
    final input = LiftInput.of(start, end, unit);
    if (!input.isValid) throw LiftInputException(input);
    return _db.transaction(() async {
      await _check(
        date,
        exerciseId,
        exists: await _logs.get(date, exerciseId) != null,
      );
      final log = LiftLog(
        date: date,
        exerciseId: exerciseId,
        startKgX10: input.startX10!,
        endKgX10: input.endX10!,
      );
      await _logs.put(log);
      await _outbox.enqueue(
        SyncEntities.liftLog,
        log.key,
        SyncOp.upsert,
        _codec.encode(log),
      );
      return log;
    });
  }
}

/// Xóa mức tạ của bài trong buổi khi cửa sổ còn mở: tombstone qua outbox.
/// Ném [LiftException].
final class DeleteLiftLog extends _LiftWrite {
  DeleteLiftLog({
    required super.db,
    required super.logs,
    required super.schedule,
    required super.exercises,
    required super.outbox,
    required super.clock,
  });

  Future<void> call(LocalDate date, String exerciseId) =>
      _db.transaction(() async {
        await _check(date, exerciseId, exists: true);
        await _logs.delete(date, exerciseId);
        await _outbox.enqueue(
          SyncEntities.liftLog,
          LiftLog.keyOf(date, exerciseId),
          SyncOp.delete,
          null,
        );
      });
}

final saveLiftLogProvider = Provider<SaveLiftLog>(
  (ref) => SaveLiftLog(
    db: ref.watch(databaseProvider),
    logs: ref.watch(liftLogRepositoryProvider),
    schedule: ref.watch(scheduleRepositoryProvider),
    exercises: ref.watch(exerciseRepositoryProvider),
    outbox: ref.watch(outboxWriterProvider),
    clock: ref.watch(clockProvider),
  ),
);

final deleteLiftLogProvider = Provider<DeleteLiftLog>(
  (ref) => DeleteLiftLog(
    db: ref.watch(databaseProvider),
    logs: ref.watch(liftLogRepositoryProvider),
    schedule: ref.watch(scheduleRepositoryProvider),
    exercises: ref.watch(exerciseRepositoryProvider),
    outbox: ref.watch(outboxWriterProvider),
    clock: ref.watch(clockProvider),
  ),
);
