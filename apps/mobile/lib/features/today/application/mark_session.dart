import 'package:api_contract/api_contract.dart';
import 'package:domain/domain.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../data/db/app_database.dart';
import '../../../data/sync/outbox_writer.dart';
import '../../../data/sync/sync_providers.dart';
import '../../schedule/data/schedule_repository.dart';
import '../../workout/data/lift_log_repository.dart';

/// Chưa xác nhận hộp chốt buổi S-65: chưa lưu gì (F05-V22, 06 Bản 2 ED2-04).
final class NotConfirmedException implements Exception {
  const NotConfirmedException();

  @override
  String toString() => 'NotConfirmedException';
}

/// Ghi một bản ngày đã kiểm tra bằng domain + outbox trong một transaction.
/// Giao diện đổi ngay nhờ stream của Drift, không chờ mạng (P6, F05-E28).
abstract base class _DayWrite {
  _DayWrite({
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

  Future<PlanDay> _write(
    LocalDate date,
    PlanDay Function(PlanDay? day, DateTime now) change,
  ) => _db.transaction(() async {
    final updated = change(await _schedule.day(date), _clock.now());
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

/// "Đã tập" (F05-R23, F05-R24, 05 Bản 2 TD2-08): chỉ khi Bạn đã xác nhận hộp
/// S-65 ([confirmed]); ghi `mark = done`, nhóm cơ thực tế = nhóm cơ của lịch,
/// `markedAt`. Buổi chốt từ đây. Ném [NotConfirmedException] hoặc
/// [MarkException].
final class MarkSessionDone extends _DayWrite {
  MarkSessionDone({
    required super.db,
    required super.schedule,
    required super.outbox,
    required super.clock,
  });

  Future<PlanDay> call(LocalDate date, {required bool confirmed}) async {
    if (!confirmed) throw const NotConfirmedException();
    return _write(date, (day, now) {
      if (day == null) throw const MarkException(MarkError.notWorkout);
      return SessionRules.markDone(day, now: now);
    });
  }
}

/// "Không tập" (F05-R25): lưu ngay, không cần xác nhận, chỉ từ "Chờ đánh dấu".
/// Ném [MarkException]. Mức tạ đã ghi của buổi giữ nguyên (FD2-02).
final class MarkSessionSkipped extends _DayWrite {
  MarkSessionSkipped({
    required super.db,
    required super.schedule,
    required LiftLogRepository liftLogs,
    required super.outbox,
    required super.clock,
  }) : _liftLogs = liftLogs;

  final LiftLogRepository _liftLogs;

  /// Số bài đã có mức tạ trong buổi ngày [date]: > 0 thì UI hỏi trước khi
  /// lưu "Buổi này đã có mức tạ của {N} bài." (F05-R28).
  Future<int> liftLogCount(LocalDate date) => _liftLogs.countDay(date);

  Future<PlanDay> call(LocalDate date) => _write(date, (day, now) {
    if (day == null) throw const MarkException(MarkError.notWorkout);
    return SessionRules.markSkipped(day, now: now);
  });
}

/// Thêm buổi tập thêm (F05-R31 → R35): chỉ khi Bạn đã xác nhận hộp S-65
/// ([confirmed]) và đã có lịch tuần; khóa ngay khi lưu. Không có sửa, xóa.
/// Ném
/// [NotConfirmedException] hoặc [ExtraException].
final class AddExtraSession extends _DayWrite {
  AddExtraSession({
    required super.db,
    required super.schedule,
    required super.outbox,
    required super.clock,
  });

  Future<PlanDay> call(
    LocalDate date,
    List<MuscleGroup> muscles, {
    required bool confirmed,
  }) async {
    if (!confirmed) throw const NotConfirmedException();
    // F05-R31: chưa có lịch tuần thì không có buổi tập thêm.
    final hasSchedule = await _schedule.template() != null;
    return _write(date, (day, now) {
      if (day == null) {
        throw ExtraException(
          hasSchedule ? ExtraError.notRestDay : ExtraError.noSchedule,
        );
      }
      return ExtraSessionRules.add(
        day,
        muscles,
        now: now,
        hasSchedule: hasSchedule,
      );
    });
  }
}

final markSessionDoneProvider = Provider<MarkSessionDone>(
  (ref) => MarkSessionDone(
    db: ref.watch(databaseProvider),
    schedule: ref.watch(scheduleRepositoryProvider),
    outbox: ref.watch(outboxWriterProvider),
    clock: ref.watch(clockProvider),
  ),
);

final markSessionSkippedProvider = Provider<MarkSessionSkipped>(
  (ref) => MarkSessionSkipped(
    db: ref.watch(databaseProvider),
    schedule: ref.watch(scheduleRepositoryProvider),
    liftLogs: ref.watch(liftLogRepositoryProvider),
    outbox: ref.watch(outboxWriterProvider),
    clock: ref.watch(clockProvider),
  ),
);

final addExtraSessionProvider = Provider<AddExtraSession>(
  (ref) => AddExtraSession(
    db: ref.watch(databaseProvider),
    schedule: ref.watch(scheduleRepositoryProvider),
    outbox: ref.watch(outboxWriterProvider),
    clock: ref.watch(clockProvider),
  ),
);
