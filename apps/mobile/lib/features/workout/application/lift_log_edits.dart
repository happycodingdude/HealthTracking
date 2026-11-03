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
import '../data/exercise_unit_repository.dart';
import '../data/lift_log_repository.dart';
import '../data/session_exercise_repository.dart';

/// Việc làm sau khi mức tạ hoặc đơn vị của bài đổi (05 Bản 3 §6.4.1): cập nhật
/// widget (VS-39) và thẻ màn hình khóa (VS-41). Mặc định không làm gì.
abstract interface class LiftChangeHooks {
  /// Đã lưu ([deleted] = false) hoặc xóa mức tạ bài [exerciseId] ngày [date].
  Future<void> liftChanged(
    LocalDate date,
    String exerciseId, {
    required bool deleted,
  });
  Future<void> unitChanged(String exerciseId);

  /// Danh sách bài của buổi ngày [date] đổi (đổi bài, bỏ qua, thêm, xóa bài
  /// thêm — 05 Bản 5 §6.4.4): "Kế tiếp" trên thẻ tính lại.
  Future<void> sessionItemsChanged(LocalDate date);
}

final class NoLiftChangeHooks implements LiftChangeHooks {
  const NoLiftChangeHooks();

  @override
  Future<void> liftChanged(
    LocalDate date,
    String exerciseId, {
    required bool deleted,
  }) async {}

  @override
  Future<void> unitChanged(String exerciseId) async {}

  @override
  Future<void> sessionItemsChanged(LocalDate date) async {}
}

final liftChangeHooksProvider = Provider<LiftChangeHooks>(
  (ref) => const NoLiftChangeHooks(),
);

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
    SessionExerciseRepository? sessionRows,
  }) : _db = db,
       _logs = logs,
       _schedule = schedule,
       _exercises = exercises,
       _outbox = outbox,
       _clock = clock,
       _sessionRows = sessionRows;

  final AppDatabase _db;
  final LiftLogRepository _logs;
  final ScheduleRepository _schedule;
  final ExerciseRepository _exercises;
  final OutboxWriter _outbox;
  final Clock _clock;

  /// Bài đổi / bỏ qua / thêm của buổi (05 Bản 5 TD5-09); null = chỉ xét nhóm
  /// cơ như Bản 3.
  final SessionExerciseRepository? _sessionRows;

  /// 05 Bản 2 §6.6.2 bước 1 → 4 với giờ hiện tại; bước 4 theo danh sách bài
  /// của buổi (TD5-09), xóa không xét bước 4 ([removing]). Ném
  /// [LiftException].
  Future<void> _check(
    LocalDate date,
    String exerciseId, {
    required bool exists,
    bool removing = false,
  }) async {
    final error = LiftLogRules.check(
      day: await _schedule.day(date),
      exercise: await _exercises.get(exerciseId),
      now: _clock.now(),
      exists: exists,
      sessionRows: await _sessionRows?.day(date) ?? const [],
      removing: removing,
    );
    if (error != null) throw LiftException(error);
  }
}

/// Lưu mức tạ bắt đầu, kết thúc của bài [exerciseId] trong buổi ngày [date]
/// (S-64, 05 Bản 3 §6.4.1): đơn vị là đơn vị hiện tại của bài, hoặc [unit]
/// Bạn chọn ở lần ghi đầu (F21-V41); kiểm khoảng theo đơn vị (V43, V44), hai
/// số (V42), rồi buổi, cửa sổ, bài; ghi đè bản cũ nếu có. Lần ghi đầu tạo
/// đơn vị và đưa `exercise_unit` vào outbox **trước** `lift_log` (TD3-05).
/// Ném [LiftInputException] hoặc [LiftException] (ngoài cửa sổ →
/// [LiftError.windowClosed]).
final class SaveLiftLog extends _LiftWrite {
  SaveLiftLog({
    required super.db,
    required super.logs,
    required super.schedule,
    required super.exercises,
    required super.outbox,
    required super.clock,
    super.sessionRows,
    required ExerciseUnitRepository units,
    LiftChangeHooks hooks = const NoLiftChangeHooks(),
  }) : _units = units,
       _hooks = hooks;

  final ExerciseUnitRepository _units;
  final LiftChangeHooks _hooks;

  static const _codec = LiftLogCodec();
  static const _unitCodec = ExerciseUnitCodec();

  Future<LiftLog> call(
    LocalDate date,
    String exerciseId, {
    required String start,
    required String end,
    LiftUnit? unit,
  }) async {
    // Bài bụng không có đơn vị, không ghi mức tạ (F21-AC50).
    if ((await _exercises.get(exerciseId))?.logsWeight == false) {
      throw const LiftException(LiftError.notAllowedForExercise);
    }
    final current = await _units.get(exerciseId);
    final input = LiftInput.of(start, end, current?.unit ?? unit);
    if (!input.isValid) throw LiftInputException(input);
    final log = await _db.transaction(() async {
      await _check(
        date,
        exerciseId,
        exists: await _logs.get(date, exerciseId) != null,
      );
      if (current == null) {
        final chosen = ExerciseUnit(
          exerciseId: exerciseId,
          unit: unit!,
          changedOn: LocalDate.fromDateTime(_clock.now()),
        );
        await _units.put(chosen);
        await _outbox.enqueue(
          SyncEntities.exerciseUnit,
          exerciseId,
          SyncOp.upsert,
          _unitCodec.encode(chosen),
        );
      }
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
    await _hooks.liftChanged(date, exerciseId, deleted: false);
    return log;
  }
}

/// Lưu ghi chú của bài trong buổi (F-26, 05 Bản 3 §6.4.1): bỏ khoảng trắng
/// hai đầu, giữ tối đa 200 ký tự (F26-V1, E1); trống → xóa ghi chú đang có
/// (tombstone qua outbox, F26-V2). Cùng cửa sổ ghi tạ, không xét bài có ghi
/// mức tạ (bài bụng có ghi chú, F26-R4). Ném [LiftException]. Trả ghi chú đã
/// lưu, null khi đã xóa hoặc không có gì để lưu.
final class SaveExerciseNote {
  SaveExerciseNote({
    required AppDatabase db,
    required ExerciseNoteRepository notes,
    required ScheduleRepository schedule,
    required ExerciseRepository exercises,
    required OutboxWriter outbox,
    required Clock clock,
    SessionExerciseRepository? sessionRows,
  }) : _db = db,
       _notes = notes,
       _schedule = schedule,
       _exercises = exercises,
       _outbox = outbox,
       _clock = clock,
       _sessionRows = sessionRows;

  final AppDatabase _db;
  final ExerciseNoteRepository _notes;
  final ScheduleRepository _schedule;
  final ExerciseRepository _exercises;
  final OutboxWriter _outbox;
  final Clock _clock;
  final SessionExerciseRepository? _sessionRows;

  static const _codec = ExerciseNoteCodec();

  Future<ExerciseNote?> call(LocalDate date, String exerciseId, String text) =>
      _db.transaction(() async {
        final existing = await _notes.get(date, exerciseId);
        final content = ExerciseNoteRules.normalize(
          ExerciseNoteRules.clip(text),
        );
        final error = ExerciseNoteRules.check(
          day: await _schedule.day(date),
          exercise: await _exercises.get(exerciseId),
          now: _clock.now(),
          exists: existing != null,
          sessionRows: await _sessionRows?.day(date) ?? const [],
          removing: content.isEmpty,
        );
        if (error != null) throw LiftException(error);
        final key = ExerciseNote.keyOf(date, exerciseId);
        if (content.isEmpty) {
          if (existing == null) return null;
          await _notes.delete(date, exerciseId);
          await _outbox.enqueue(
            SyncEntities.exerciseNote,
            key,
            SyncOp.delete,
            null,
          );
          return null;
        }
        final note = ExerciseNote(
          date: date,
          exerciseId: exerciseId,
          text: content,
        );
        if (note == existing) return note;
        await _notes.put(note);
        await _outbox.enqueue(
          SyncEntities.exerciseNote,
          key,
          SyncOp.upsert,
          _codec.encode(note),
        );
        return note;
      });
}

/// Lưu mức thoải mái của set cuối (F-33, 05 Bản 5 §6.4.2 `SaveExerciseFeel`):
/// [feel] = null là bỏ chọn (tombstone qua outbox, TD5-04). Cùng cửa sổ ghi
/// tạ ([FeelRules.check], gồm mở sớm khi tới gym); độc lập với mức tạ và ghi
/// chú (F33-R3); bài bụng chọn được (FC5-05). Không cần mạng (F33-R8). Ném
/// [LiftException]. Trả mức đã lưu, null khi đã bỏ chọn hoặc không có gì.
final class SaveExerciseFeel {
  SaveExerciseFeel({
    required AppDatabase db,
    required ExerciseFeelRepository feels,
    required ScheduleRepository schedule,
    required ExerciseRepository exercises,
    required OutboxWriter outbox,
    required Clock clock,
    SessionExerciseRepository? sessionRows,
  }) : _db = db,
       _feels = feels,
       _schedule = schedule,
       _exercises = exercises,
       _outbox = outbox,
       _clock = clock,
       _sessionRows = sessionRows;

  final AppDatabase _db;
  final ExerciseFeelRepository _feels;
  final ScheduleRepository _schedule;
  final ExerciseRepository _exercises;
  final OutboxWriter _outbox;
  final Clock _clock;
  final SessionExerciseRepository? _sessionRows;

  static const _codec = ExerciseFeelCodec();

  Future<ExerciseFeel?> call(LocalDate date, String exerciseId, Feel? feel) =>
      _db.transaction(() async {
        final existing = await _feels.get(date, exerciseId);
        if (existing?.feel == feel) return existing;
        final error = FeelRules.check(
          day: await _schedule.day(date),
          exercise: await _exercises.get(exerciseId),
          now: _clock.now(),
          exists: existing != null,
          sessionRows: await _sessionRows?.day(date) ?? const [],
          removing: feel == null,
        );
        if (error != null) throw LiftException(error);
        final key = ExerciseFeel.keyOf(date, exerciseId);
        if (feel == null) {
          await _feels.delete(date, exerciseId);
          await _outbox.enqueue(
            SyncEntities.exerciseFeel,
            key,
            SyncOp.delete,
            null,
          );
          return null;
        }
        final value = ExerciseFeel(
          date: date,
          exerciseId: exerciseId,
          feel: feel,
        );
        await _feels.put(value);
        await _outbox.enqueue(
          SyncEntities.exerciseFeel,
          key,
          SyncOp.upsert,
          _codec.encode(value),
        );
        return value;
      });
}

/// Một lần bấm Lưu ở bảng ghi tạ (F21-R49, FD3-01 = A, 04 Bản 5 S-64,
/// F21-R61): mức tạ, ghi chú và mức thoải mái độc lập, ghi trong cùng một
/// transaction. Hai ô tạ trống → chỉ lưu ghi chú / mức thoải mái, không báo
/// F21-V42; có số → kiểm F21-V41 → V45 như thường. [note] = null: không đụng
/// tới ghi chú; [feel] = null: không đụng tới mức thoải mái (`(value: null)`
/// = bỏ chọn). Lỗi bất kỳ → không lưu gì.
final class SaveLiftEntry {
  SaveLiftEntry({
    required AppDatabase db,
    required SaveLiftLog lift,
    required SaveExerciseNote note,
    SaveExerciseFeel? feel,
  }) : _db = db,
       _lift = lift,
       _note = note,
       _feel = feel;

  final AppDatabase _db;
  final SaveLiftLog _lift;
  final SaveExerciseNote _note;
  final SaveExerciseFeel? _feel;

  Future<({LiftLog? log, ExerciseNote? note, ExerciseFeel? feel})> call(
    LocalDate date,
    String exerciseId, {
    required String start,
    required String end,
    LiftUnit? unit,
    String? note,
    ({Feel? value})? feel,
  }) => _db.transaction(() async {
    final onlyNote = start.trim().isEmpty && end.trim().isEmpty;
    final log = onlyNote
        ? null
        : await _lift(date, exerciseId, start: start, end: end, unit: unit);
    final saved = note == null ? null : await _note(date, exerciseId, note);
    final savedFeel = feel == null || _feel == null
        ? null
        : await _feel(date, exerciseId, feel.value);
    return (log: log, note: saved, feel: savedFeel);
  });
}

/// Đổi đơn vị của bài (F21-R47, FA3-04, 05 Bản 3 §6.4.1): không cần cửa sổ
/// ghi tạ; con số đã ghi giữ nguyên, không quy đổi; `changedOn` = hôm nay.
/// Bài phải có ghi mức tạ. Trả đơn vị sau khi đổi.
final class ChangeExerciseUnit {
  ChangeExerciseUnit({
    required AppDatabase db,
    required ExerciseUnitRepository units,
    required ExerciseRepository exercises,
    required OutboxWriter outbox,
    required Clock clock,
    LiftChangeHooks hooks = const NoLiftChangeHooks(),
  }) : _db = db,
       _units = units,
       _exercises = exercises,
       _outbox = outbox,
       _clock = clock,
       _hooks = hooks;

  final AppDatabase _db;
  final ExerciseUnitRepository _units;
  final ExerciseRepository _exercises;
  final OutboxWriter _outbox;
  final Clock _clock;
  final LiftChangeHooks _hooks;

  static const _codec = ExerciseUnitCodec();

  Future<ExerciseUnit> call(String exerciseId, LiftUnit unit) async {
    final changed = await _db.transaction(() async {
      final exercise = await _exercises.get(exerciseId);
      if (exercise == null || !exercise.logsWeight) {
        throw const LiftException(LiftError.notAllowedForExercise);
      }
      final current = await _units.get(exerciseId);
      if (current?.unit == unit) return current!;
      final next = ExerciseUnit(
        exerciseId: exerciseId,
        unit: unit,
        changedOn: LocalDate.fromDateTime(_clock.now()),
      );
      await _units.put(next);
      await _outbox.enqueue(
        SyncEntities.exerciseUnit,
        exerciseId,
        SyncOp.upsert,
        _codec.encode(next),
      );
      return next;
    });
    await _hooks.unitChanged(exerciseId);
    return changed;
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
    LiftChangeHooks hooks = const NoLiftChangeHooks(),
  }) : _hooks = hooks;

  final LiftChangeHooks _hooks;

  /// Chỉ xóa mức tạ; ghi chú của bài trong buổi giữ nguyên (F26-R5).
  Future<void> call(LocalDate date, String exerciseId) async {
    await _db.transaction(() async {
      await _check(date, exerciseId, exists: true, removing: true);
      await _logs.delete(date, exerciseId);
      await _outbox.enqueue(
        SyncEntities.liftLog,
        LiftLog.keyOf(date, exerciseId),
        SyncOp.delete,
        null,
      );
    });
    await _hooks.liftChanged(date, exerciseId, deleted: true);
  }
}

final saveLiftLogProvider = Provider<SaveLiftLog>(
  (ref) => SaveLiftLog(
    db: ref.watch(databaseProvider),
    logs: ref.watch(liftLogRepositoryProvider),
    schedule: ref.watch(scheduleRepositoryProvider),
    exercises: ref.watch(exerciseRepositoryProvider),
    outbox: ref.watch(outboxWriterProvider),
    clock: ref.watch(clockProvider),
    sessionRows: ref.watch(sessionExerciseRepositoryProvider),
    units: ref.watch(exerciseUnitRepositoryProvider),
    hooks: ref.watch(liftChangeHooksProvider),
  ),
);

final saveExerciseNoteProvider = Provider<SaveExerciseNote>(
  (ref) => SaveExerciseNote(
    db: ref.watch(databaseProvider),
    notes: ref.watch(exerciseNoteRepositoryProvider),
    schedule: ref.watch(scheduleRepositoryProvider),
    exercises: ref.watch(exerciseRepositoryProvider),
    outbox: ref.watch(outboxWriterProvider),
    clock: ref.watch(clockProvider),
    sessionRows: ref.watch(sessionExerciseRepositoryProvider),
  ),
);

final saveExerciseFeelProvider = Provider<SaveExerciseFeel>(
  (ref) => SaveExerciseFeel(
    db: ref.watch(databaseProvider),
    feels: ref.watch(exerciseFeelRepositoryProvider),
    schedule: ref.watch(scheduleRepositoryProvider),
    exercises: ref.watch(exerciseRepositoryProvider),
    outbox: ref.watch(outboxWriterProvider),
    clock: ref.watch(clockProvider),
    sessionRows: ref.watch(sessionExerciseRepositoryProvider),
  ),
);

final saveLiftEntryProvider = Provider<SaveLiftEntry>(
  (ref) => SaveLiftEntry(
    db: ref.watch(databaseProvider),
    lift: ref.watch(saveLiftLogProvider),
    note: ref.watch(saveExerciseNoteProvider),
    feel: ref.watch(saveExerciseFeelProvider),
  ),
);

final changeExerciseUnitProvider = Provider<ChangeExerciseUnit>(
  (ref) => ChangeExerciseUnit(
    db: ref.watch(databaseProvider),
    units: ref.watch(exerciseUnitRepositoryProvider),
    exercises: ref.watch(exerciseRepositoryProvider),
    outbox: ref.watch(outboxWriterProvider),
    clock: ref.watch(clockProvider),
    hooks: ref.watch(liftChangeHooksProvider),
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
    hooks: ref.watch(liftChangeHooksProvider),
  ),
);
