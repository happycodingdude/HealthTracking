import 'package:api_contract/api_contract.dart';
import 'package:domain/domain.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../data/db/app_database.dart';
import '../../../data/sync/outbox_writer.dart';
import '../../../data/sync/sync_providers.dart';
import '../../library/data/exercise_repository.dart';
import '../../schedule/data/schedule_repository.dart';
import '../data/exercise_feel_repository.dart';
import '../data/exercise_note_repository.dart';
import '../data/lift_log_repository.dart';
import '../data/session_exercise_repository.dart';
import 'lift_log_edits.dart';

/// Ghi danh sách bài của buổi (06 Bản 5 ED5-04, 05 Bản 5 TD5-10): xóa bản ghi
/// của một bài hôm nay và ghi / tombstone dòng `session_exercise`, **bên trong
/// transaction của use case**. Outbox theo thứ tự `lift_log` → `exercise_note`
/// → `exercise_feel` → `session_exercise`. Ba use case F-28 / F-29 / F-30 đều
/// gọi qua đây (FC5-14 một chỗ).
final class SessionItemMutator {
  SessionItemMutator({
    required LiftLogRepository logs,
    required ExerciseNoteRepository notes,
    required ExerciseFeelRepository feels,
    required SessionExerciseRepository rows,
    required OutboxWriter outbox,
  }) : _logs = logs,
       _notes = notes,
       _feels = feels,
       _rows = rows,
       _outbox = outbox;

  final LiftLogRepository _logs;
  final ExerciseNoteRepository _notes;
  final ExerciseFeelRepository _feels;
  final SessionExerciseRepository _rows;
  final OutboxWriter _outbox;

  static const _rowCodec = SessionExerciseCodec();

  /// Xóa mức tạ, ghi chú, mức thoải mái hôm [date] của bài [exerciseId]
  /// (FC5-14). Trả true khi có xóa mức tạ.
  Future<bool> clearRecords(LocalDate date, String exerciseId) async {
    final key = LiftLog.keyOf(date, exerciseId);
    final hadLog = await _logs.get(date, exerciseId) != null;
    if (hadLog) {
      await _logs.delete(date, exerciseId);
      await _outbox.enqueue(SyncEntities.liftLog, key, SyncOp.delete, null);
    }
    if (await _notes.get(date, exerciseId) != null) {
      await _notes.delete(date, exerciseId);
      await _outbox.enqueue(
        SyncEntities.exerciseNote,
        key,
        SyncOp.delete,
        null,
      );
    }
    if (await _feels.get(date, exerciseId) != null) {
      await _feels.delete(date, exerciseId);
      await _outbox.enqueue(
        SyncEntities.exerciseFeel,
        key,
        SyncOp.delete,
        null,
      );
    }
    return hadLog;
  }

  Future<void> putRow(SessionExerciseRow row) async {
    await _rows.put(row);
    await _outbox.enqueue(
      SyncEntities.sessionExercise,
      row.key,
      SyncOp.upsert,
      _rowCodec.encode(row),
    );
  }

  /// Tombstone dòng của bài [exerciseId] ngày [date] (hủy đổi, hủy bỏ qua,
  /// xóa bài thêm).
  Future<void> deleteRow(LocalDate date, String exerciseId) async {
    await _rows.delete(date, exerciseId);
    await _outbox.enqueue(
      SyncEntities.sessionExercise,
      SessionExerciseRow.keyOf(date, exerciseId),
      SyncOp.delete,
      null,
    );
  }
}

/// Đọc danh sách bài của buổi ngày [date] trên máy (dùng trong transaction).
Future<
  ({
    PlanDay? day,
    List<Exercise> library,
    List<SessionExerciseRow> rows,
    List<SessionItem> items,
  })
>
_readSession({
  required ScheduleRepository schedule,
  required ExerciseRepository exercises,
  required LiftLogRepository logs,
  required SessionExerciseRepository rows,
  required LocalDate date,
}) async {
  final day = await schedule.day(date);
  final library = await exercises.all();
  final dayRows = await rows.day(date);
  final logged = {for (final l in await logs.day(date)) l.exerciseId};
  final items = day == null
      ? const <SessionItem>[]
      : SessionList.build(
          library: library,
          groups: MuscleGroup.ordered(day.sessionMuscles),
          rows: dayRows,
          loggedToday: logged,
        );
  return (day: day, library: library, rows: dayRows, items: items);
}

/// Đổi bài tạm trong buổi hôm nay (F-28, 05 Bản 5 §6.4.2 `ReplaceExercise`):
/// bài ở chỗ [slotExerciseId] (bài gốc hoặc bài thay) đổi sang
/// [newExerciseId] chọn ở S-75. Bài thay đứng đúng chỗ bài gốc; bản ghi hôm
/// nay của bài đang ở chỗ đó (đã hỏi S-78) bị xóa (FC5-14). Chọn đúng bài gốc
/// = hủy đổi (FC5-04). Một transaction; không cần mạng. Ném
/// [SessionEditException]. Trả bài đứng ở chỗ đó sau khi đổi.
final class ReplaceExercise {
  ReplaceExercise({
    required AppDatabase db,
    required ScheduleRepository schedule,
    required ExerciseRepository exercises,
    required LiftLogRepository logs,
    required SessionExerciseRepository rows,
    required SessionItemMutator mutator,
    required Clock clock,
    LiftChangeHooks hooks = const NoLiftChangeHooks(),
  }) : _db = db,
       _schedule = schedule,
       _exercises = exercises,
       _logs = logs,
       _rows = rows,
       _mutator = mutator,
       _clock = clock,
       _hooks = hooks;

  final AppDatabase _db;
  final ScheduleRepository _schedule;
  final ExerciseRepository _exercises;
  final LiftLogRepository _logs;
  final SessionExerciseRepository _rows;
  final SessionItemMutator _mutator;
  final Clock _clock;
  final LiftChangeHooks _hooks;

  Future<Exercise> call(
    LocalDate date,
    String slotExerciseId,
    String newExerciseId,
  ) async {
    var removedLog = false;
    final result = await _db.transaction(() async {
      final s = await _readSession(
        schedule: _schedule,
        exercises: _exercises,
        logs: _logs,
        rows: _rows,
        date: date,
      );
      final error = SessionList.editError(s.day, _clock.now());
      if (error != null) throw SessionEditException(error);
      final item = s.items
          .where(
            (i) =>
                i.id == slotExerciseId && i.role != SessionExerciseRole.extra,
          )
          .firstOrNull;
      if (item == null) {
        throw const SessionEditException(SessionEditError.notInSession);
      }
      final original = item.original!;
      if (newExerciseId == original.id) {
        // Chọn lại bài gốc = hủy đổi (FC5-04).
        if (item.role == SessionExerciseRole.replacement) {
          removedLog = await _mutator.clearRecords(date, item.id);
          await _mutator.deleteRow(date, item.id);
        }
        return original;
      }
      final next = SessionList.pickable(
        s.library,
        s.items,
      ).where((e) => e.id == newExerciseId).firstOrNull;
      if (next == null) {
        throw const SessionEditException(SessionEditError.notPickable);
      }
      removedLog = await _mutator.clearRecords(date, item.id);
      if (item.role == SessionExerciseRole.replacement) {
        await _mutator.deleteRow(date, item.id);
      }
      // Bài gốc đang bỏ qua mà được đổi: chỗ đó không còn bỏ qua (dòng bỏ
      // qua của bài gốc tombstone trước, server không nhận bài thay cho bài
      // gốc đang bỏ qua — 05 Bản 5 §6.6.2).
      if (s.rows.any(
        (r) =>
            r.role == SessionExerciseRole.original &&
            r.exerciseId == original.id,
      )) {
        await _mutator.deleteRow(date, original.id);
      }
      await _mutator.putRow(
        SessionExerciseRow(
          date: date,
          exerciseId: next.id,
          role: SessionExerciseRole.replacement,
          replacesExerciseId: original.id,
          position: item.position,
        ),
      );
      return next;
    });
    await _changed(_hooks, date, slotExerciseId, removedLog: removedLog);
    return result;
  }
}

/// Sau khi danh sách bài đổi: xóa bản ghi → cập nhật thẻ như xóa mức tạ (thứ
/// tự lưu + nội dung); không xóa → chỉ tính lại "Kế tiếp" (05 Bản 5 §6.4.4).
Future<void> _changed(
  LiftChangeHooks hooks,
  LocalDate date,
  String exerciseId, {
  required bool removedLog,
}) => removedLog
    ? hooks.liftChanged(date, exerciseId, deleted: true)
    : hooks.sessionItemsChanged(date);

/// Phần chung của ba use case bỏ qua / thêm / xóa bài thêm (05 Bản 5 §6.4.2):
/// đọc danh sách bài của buổi trong transaction, kiểm tra buổi hôm nay chưa
/// chốt ([SessionList.editError]).
abstract base class _SessionItemWrite {
  _SessionItemWrite({
    required AppDatabase db,
    required ScheduleRepository schedule,
    required ExerciseRepository exercises,
    required LiftLogRepository logs,
    required SessionExerciseRepository rows,
    required SessionItemMutator mutator,
    required Clock clock,
    LiftChangeHooks hooks = const NoLiftChangeHooks(),
  }) : _db = db,
       _schedule = schedule,
       _exercises = exercises,
       _logs = logs,
       _rows = rows,
       _mutator = mutator,
       _clock = clock,
       _hooks = hooks;

  final AppDatabase _db;
  final ScheduleRepository _schedule;
  final ExerciseRepository _exercises;
  final LiftLogRepository _logs;
  final SessionExerciseRepository _rows;
  final SessionItemMutator _mutator;
  final Clock _clock;
  final LiftChangeHooks _hooks;

  Future<
    ({
      PlanDay? day,
      List<Exercise> library,
      List<SessionExerciseRow> rows,
      List<SessionItem> items,
    })
  >
  _open(LocalDate date) async {
    final s = await _readSession(
      schedule: _schedule,
      exercises: _exercises,
      logs: _logs,
      rows: _rows,
      date: date,
    );
    final error = SessionList.editError(s.day, _clock.now());
    if (error != null) throw SessionEditException(error);
    return s;
  }
}

/// Bỏ qua / hủy bỏ qua một bài hôm nay (F-29, 05 Bản 5 §6.4.2 `SkipExercise`):
/// bài gốc, bài thay, bài thêm, bài bụng; không lý do (F29-R2). Bỏ qua bài
/// đã có bản ghi hôm nay (đã hỏi S-78) → xóa mức tạ, ghi chú, mức thoải mái
/// trước (F29-R3, FC5-14). Bài gốc: dòng `original` + `skipped`, hủy bỏ qua =
/// tombstone; bài thay / bài thêm: giữ vai trò, đổi `skipped`. Một
/// transaction; không cần mạng. Ném [SessionEditException].
final class SkipExercise extends _SessionItemWrite {
  SkipExercise({
    required super.db,
    required super.schedule,
    required super.exercises,
    required super.logs,
    required super.rows,
    required super.mutator,
    required super.clock,
    super.hooks,
  });

  Future<void> call(
    LocalDate date,
    String exerciseId, {
    required bool skipped,
  }) async {
    var removedLog = false;
    final changed = await _db.transaction(() async {
      final s = await _open(date);
      final item = s.items.where((i) => i.id == exerciseId).firstOrNull;
      if (item == null) {
        throw const SessionEditException(SessionEditError.notInSession);
      }
      if (item.skipped == skipped) return false;
      if (skipped) removedLog = await _mutator.clearRecords(date, item.id);
      final row = s.rows.where((r) => r.exerciseId == item.id).firstOrNull;
      if (item.role == SessionExerciseRole.original) {
        if (skipped) {
          await _mutator.putRow(
            SessionExerciseRow(
              date: date,
              exerciseId: item.id,
              role: SessionExerciseRole.original,
              position: item.position,
              skipped: true,
            ),
          );
        } else {
          await _mutator.deleteRow(date, item.id);
        }
      } else if (row != null) {
        await _mutator.putRow(row.withSkipped(skipped));
      }
      return true;
    });
    if (changed) {
      await _changed(_hooks, date, exerciseId, removedLog: removedLog);
    }
  }
}

/// Thêm bài lẻ vào buổi hôm nay (F-30, 05 Bản 5 §6.4.2 `AddExtraExercise`):
/// bài chọn ở S-75 (bất kỳ nhóm cơ, không trùng — F30-R2, FC5-04) nối cuối
/// danh sách theo thứ tự thêm (`position = max + 1`, F30-R3). Chỉ buổi theo
/// lịch hôm nay chưa chốt (F30-R1, R7); lịch tuần không đổi (F30-R6). Ném
/// [SessionEditException]. Trả bài đã thêm.
final class AddExtraExercise extends _SessionItemWrite {
  AddExtraExercise({
    required super.db,
    required super.schedule,
    required super.exercises,
    required super.logs,
    required super.rows,
    required super.mutator,
    required super.clock,
    super.hooks,
  });

  Future<Exercise> call(LocalDate date, String exerciseId) async {
    final added = await _db.transaction(() async {
      final s = await _open(date);
      final e = SessionList.pickable(
        s.library,
        s.items,
      ).where((e) => e.id == exerciseId).firstOrNull;
      if (e == null) {
        throw const SessionEditException(SessionEditError.notPickable);
      }
      var position = 0;
      for (final r in s.rows) {
        if (r.role == SessionExerciseRole.extra && r.position >= position) {
          position = r.position + 1;
        }
      }
      await _mutator.putRow(
        SessionExerciseRow(
          date: date,
          exerciseId: e.id,
          role: SessionExerciseRole.extra,
          position: position,
        ),
      );
      return e;
    });
    await _hooks.sessionItemsChanged(date);
    return added;
  }
}

/// Xóa bài thêm (F30-R5, 05 Bản 5 §6.4.2 `RemoveExtraExercise`): đã có bản
/// ghi hôm nay (đã hỏi S-78) → xóa cùng mức tạ, ghi chú, mức thoải mái
/// (FC5-14); rồi tombstone dòng. Chỉ bài thêm; buổi chưa chốt (F30-R7). Ném
/// [SessionEditException].
final class RemoveExtraExercise extends _SessionItemWrite {
  RemoveExtraExercise({
    required super.db,
    required super.schedule,
    required super.exercises,
    required super.logs,
    required super.rows,
    required super.mutator,
    required super.clock,
    super.hooks,
  });

  Future<void> call(LocalDate date, String exerciseId) async {
    var removedLog = false;
    await _db.transaction(() async {
      final s = await _open(date);
      final item = s.items
          .where(
            (i) => i.id == exerciseId && i.role == SessionExerciseRole.extra,
          )
          .firstOrNull;
      if (item == null) {
        throw const SessionEditException(SessionEditError.notInSession);
      }
      removedLog = await _mutator.clearRecords(date, item.id);
      await _mutator.deleteRow(date, item.id);
    });
    await _changed(_hooks, date, exerciseId, removedLog: removedLog);
  }
}

/// Danh sách bài của buổi ngày [date] đọc thẳng từ máy (dùng ngoài provider:
/// "Đã tập" kiểm tra bỏ qua tất cả bài — FC5-03).
final class SessionItemsReader {
  SessionItemsReader({
    required ScheduleRepository schedule,
    required ExerciseRepository exercises,
    required LiftLogRepository logs,
    required SessionExerciseRepository rows,
  }) : _schedule = schedule,
       _exercises = exercises,
       _logs = logs,
       _rows = rows;

  final ScheduleRepository _schedule;
  final ExerciseRepository _exercises;
  final LiftLogRepository _logs;
  final SessionExerciseRepository _rows;

  Future<List<SessionItem>> call(LocalDate date) async => (await _readSession(
    schedule: _schedule,
    exercises: _exercises,
    logs: _logs,
    rows: _rows,
    date: date,
  )).items;
}

/// Xóa mức tạ, ghi chú, mức thoải mái hôm nay của một bài trong buổi sau khi
/// Bạn xác nhận ở S-78 (FC5-14), trước khi sang S-75 "Đổi bài" (04 Bản 5
/// S-78: thoát S-75 bằng quay lại thì bản ghi đã xóa, bài vẫn ở chỗ). Ném
/// [SessionEditException].
final class ClearSessionRecords {
  ClearSessionRecords({
    required AppDatabase db,
    required ScheduleRepository schedule,
    required ExerciseRepository exercises,
    required LiftLogRepository logs,
    required SessionExerciseRepository rows,
    required SessionItemMutator mutator,
    required Clock clock,
    LiftChangeHooks hooks = const NoLiftChangeHooks(),
  }) : _db = db,
       _schedule = schedule,
       _exercises = exercises,
       _logs = logs,
       _rows = rows,
       _mutator = mutator,
       _clock = clock,
       _hooks = hooks;

  final AppDatabase _db;
  final ScheduleRepository _schedule;
  final ExerciseRepository _exercises;
  final LiftLogRepository _logs;
  final SessionExerciseRepository _rows;
  final SessionItemMutator _mutator;
  final Clock _clock;
  final LiftChangeHooks _hooks;

  Future<void> call(LocalDate date, String exerciseId) async {
    var removedLog = false;
    await _db.transaction(() async {
      final s = await _readSession(
        schedule: _schedule,
        exercises: _exercises,
        logs: _logs,
        rows: _rows,
        date: date,
      );
      final error = SessionList.editError(s.day, _clock.now());
      if (error != null) throw SessionEditException(error);
      if (!s.items.any((i) => i.id == exerciseId)) {
        throw const SessionEditException(SessionEditError.notInSession);
      }
      removedLog = await _mutator.clearRecords(date, exerciseId);
    });
    if (removedLog) {
      await _hooks.liftChanged(date, exerciseId, deleted: true);
    }
  }
}

final sessionItemMutatorProvider = Provider<SessionItemMutator>(
  (ref) => SessionItemMutator(
    logs: ref.watch(liftLogRepositoryProvider),
    notes: ref.watch(exerciseNoteRepositoryProvider),
    feels: ref.watch(exerciseFeelRepositoryProvider),
    rows: ref.watch(sessionExerciseRepositoryProvider),
    outbox: ref.watch(outboxWriterProvider),
  ),
);

final replaceExerciseProvider = Provider<ReplaceExercise>(
  (ref) => ReplaceExercise(
    db: ref.watch(databaseProvider),
    schedule: ref.watch(scheduleRepositoryProvider),
    exercises: ref.watch(exerciseRepositoryProvider),
    logs: ref.watch(liftLogRepositoryProvider),
    rows: ref.watch(sessionExerciseRepositoryProvider),
    mutator: ref.watch(sessionItemMutatorProvider),
    clock: ref.watch(clockProvider),
    hooks: ref.watch(liftChangeHooksProvider),
  ),
);

final clearSessionRecordsProvider = Provider<ClearSessionRecords>(
  (ref) => ClearSessionRecords(
    db: ref.watch(databaseProvider),
    schedule: ref.watch(scheduleRepositoryProvider),
    exercises: ref.watch(exerciseRepositoryProvider),
    logs: ref.watch(liftLogRepositoryProvider),
    rows: ref.watch(sessionExerciseRepositoryProvider),
    mutator: ref.watch(sessionItemMutatorProvider),
    clock: ref.watch(clockProvider),
    hooks: ref.watch(liftChangeHooksProvider),
  ),
);

final skipExerciseProvider = Provider<SkipExercise>(
  (ref) => SkipExercise(
    db: ref.watch(databaseProvider),
    schedule: ref.watch(scheduleRepositoryProvider),
    exercises: ref.watch(exerciseRepositoryProvider),
    logs: ref.watch(liftLogRepositoryProvider),
    rows: ref.watch(sessionExerciseRepositoryProvider),
    mutator: ref.watch(sessionItemMutatorProvider),
    clock: ref.watch(clockProvider),
    hooks: ref.watch(liftChangeHooksProvider),
  ),
);

final addExtraExerciseProvider = Provider<AddExtraExercise>(
  (ref) => AddExtraExercise(
    db: ref.watch(databaseProvider),
    schedule: ref.watch(scheduleRepositoryProvider),
    exercises: ref.watch(exerciseRepositoryProvider),
    logs: ref.watch(liftLogRepositoryProvider),
    rows: ref.watch(sessionExerciseRepositoryProvider),
    mutator: ref.watch(sessionItemMutatorProvider),
    clock: ref.watch(clockProvider),
    hooks: ref.watch(liftChangeHooksProvider),
  ),
);

final removeExtraExerciseProvider = Provider<RemoveExtraExercise>(
  (ref) => RemoveExtraExercise(
    db: ref.watch(databaseProvider),
    schedule: ref.watch(scheduleRepositoryProvider),
    exercises: ref.watch(exerciseRepositoryProvider),
    logs: ref.watch(liftLogRepositoryProvider),
    rows: ref.watch(sessionExerciseRepositoryProvider),
    mutator: ref.watch(sessionItemMutatorProvider),
    clock: ref.watch(clockProvider),
    hooks: ref.watch(liftChangeHooksProvider),
  ),
);

final sessionItemsReaderProvider = Provider<SessionItemsReader>(
  (ref) => SessionItemsReader(
    schedule: ref.watch(scheduleRepositoryProvider),
    exercises: ref.watch(exerciseRepositoryProvider),
    logs: ref.watch(liftLogRepositoryProvider),
    rows: ref.watch(sessionExerciseRepositoryProvider),
  ),
);
