import 'package:domain/domain.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/time_ticker.dart';
import '../../../data/sync/sync_providers.dart';
import '../../schedule/application/schedule_providers.dart';
import 'lift_unit.dart';

/// Vì sao S-63 chỉ xem (04 Bản 2 S-63, bảng dòng trạng thái, UA2-16).
enum LiftReadOnly {
  /// Buổi theo lịch hôm nay, chưa đến giờ: "Ghi mức tạ được từ {giờ}".
  opensLater,

  /// Buổi của ngày tương lai: "Chỉ xem · Buổi chưa đến".
  future,

  /// Đã qua 00:00 ngày sau (kể cả buổi của Bản 1): "Chỉ xem · Mức tạ của
  /// buổi này đã khóa".
  locked,

  /// Buổi tập thêm cho ngày đã qua: "Chỉ xem · Buổi tập thêm cho ngày đã qua
  /// không ghi mức tạ" (F20-E4).
  pastExtra,
}

/// Một buổi tập (05 Bản 2 §6.4.2 `sessionProvider`): nhóm cơ của buổi, trạng
/// thái đánh dấu, cửa sổ ghi tạ, đã chốt hay chưa.
final class SessionView {
  SessionView(this.day, DateTime now)
    : status = SessionStatus.derive(day, now),
      window = LiftWindow.of(day, now),
      _today = LocalDate.fromDateTime(now);

  final PlanDay day;

  /// null với buổi tập thêm.
  final SessionStatus? status;
  final LiftWindow window;
  final LocalDate _today;

  LocalDate get date => day.date;

  /// Buổi tập thêm (ngày nghỉ có `extraMuscles`).
  bool get isExtra => !day.isWorkout;

  /// Nhóm cơ của buổi (03 Bản 2 §6.1, F20-R2, F20-E5).
  List<MuscleGroup> get muscles => MuscleGroup.ordered(day.sessionMuscles);

  /// Buổi đã chốt (UR2-06): không còn nút đổi trạng thái.
  bool get isLocked => SessionLock.of(day);

  bool get canLog => window.isOpen;

  /// Nút "Đã tập" ở thanh đáy S-63 (UA2-09): buổi theo lịch đang "Chờ đánh
  /// dấu" (đã đến giờ).
  bool get canMarkDone => status?.state == SessionState.awaitingMark;

  /// Dòng trạng thái đầu S-63; null khi đang trong cửa sổ ghi tạ.
  LiftReadOnly? get readOnly => switch (window) {
    LiftWindowOpen() => null,
    LiftWindowNotOpen() =>
      date == _today ? LiftReadOnly.opensLater : LiftReadOnly.future,
    LiftWindowClosed(reason: LiftClosedReason.pastExtra) =>
      LiftReadOnly.pastExtra,
    LiftWindowClosed() => LiftReadOnly.locked,
  };
}

/// Buổi tập ngày [date]; null khi ngày đó không có buổi (ngày nghỉ chưa có
/// buổi tập thêm, chủ nhật, ngày chưa có lịch) hoặc chưa đọc xong.
final sessionProvider = Provider.family<SessionView?, LocalDate>((ref, date) {
  final day = ref.watch(dayProvider(date)).value;
  if (!LiftLogRules.isSession(day)) return null;
  return SessionView(day!, ref.watch(nowProvider));
});

/// Bản ghi mức tạ của buổi ngày [date].
final dayLiftLogsProvider = StreamProvider.family<List<LiftLog>, LocalDate>(
  (ref, date) => ref.watch(liftLogRepositoryProvider).watchDay(date),
);

/// Mọi bản ghi mức tạ, cũ → mới (buổi trước, bản ghi gần nhất).
final allLiftLogsProvider = StreamProvider<List<LiftLog>>(
  (ref) => ref.watch(liftLogRepositoryProvider).watchAll(),
);

/// Mọi bài trong thư viện, kể cả bài đã rời thư viện (F20-E1, F19-E2).
final allExercisesProvider = StreamProvider<List<Exercise>>(
  (ref) => ref.watch(exerciseRepositoryProvider).watchAll(),
);

/// Mọi ghi chú, cũ → mới (ghi chú buổi trước, FA3-02).
final allExerciseNotesProvider = StreamProvider<List<ExerciseNote>>(
  (ref) => ref.watch(exerciseNoteRepositoryProvider).watchAll(),
);

/// Mọi mức thoải mái, cũ → mới (mức thoải mái hôm nay; FC5-14 xóa cùng bản
/// ghi khi đổi bài).
final allExerciseFeelsProvider = StreamProvider<List<ExerciseFeel>>(
  (ref) => ref.watch(exerciseFeelRepositoryProvider).watchAll(),
);

/// Các dòng bài đổi / bỏ qua / thêm của buổi ngày [date] (05 Bản 5 TD5-03).
final sessionRowsProvider =
    StreamProvider.family<List<SessionExerciseRow>, LocalDate>(
      (ref, date) =>
          ref.watch(sessionExerciseRepositoryProvider).watchDay(date),
    );

/// Một bài trong buổi (05 Bản 3 §6.4.2, 05 Bản 5 §6.4.3
/// `sessionExercisesProvider`): bài và vai trò trong buổi (gốc / thay / thêm,
/// bỏ qua — [SessionItem]), bản ghi và ghi chú của buổi, buổi trước
/// (FA3-01, theo bài đang đứng ở chỗ — F28-R3), ghi chú buổi trước (FA3-02),
/// mức thoải mái hôm nay và buổi trước (FC5-07, F20-R62), đơn vị hiện tại,
/// trạng thái dòng (ED3-11) và biểu tượng ghi chú.
typedef SessionExercise = ({
  Exercise exercise,
  SessionItem item,
  LiftLog? log,
  LiftLog? previous,
  ExerciseNote? note,
  ExerciseNote? previousNote,
  ExerciseFeel? feel,
  ExerciseFeel? previousFeel,
  LiftUnit? unit,
  LiftRowState state,
  NoteMark noteMark,
});

/// Một nhóm cơ của buổi và các bài của nhóm, danh sách phẳng (F20-R41); bài
/// thay đứng trong nhóm của bài gốc (F28-E3).
typedef SessionGroup = ({MuscleGroup group, List<SessionExercise> items});

/// Bài của buổi theo danh sách bài của buổi (05 Bản 5 §6.4.1, ED5-03).
final class SessionExercises {
  const SessionExercises(this.groups, {this.extras = const []});

  final List<SessionGroup> groups;

  /// Bài thêm, nối cuối danh sách theo thứ tự thêm (A5-02).
  final List<SessionExercise> extras;

  Iterable<SessionExercise> get all => [
    for (final g in groups) ...g.items,
    ...extras,
  ];

  /// Có bản ghi hôm nay (mức tạ, ghi chú, mức thoải mái) — FC5-14, S-78.
  static bool hasRecords(SessionExercise e) =>
      e.log != null || e.note != null || e.feel != null;

  /// m của "Đã ghi n / m" (FC5-05): bài có ghi mức tạ trong buổi, gồm bài
  /// thay và bài thêm, trừ bài bỏ qua.
  int get total =>
      all.where((i) => i.exercise.logsWeight && !i.item.skipped).length;

  /// n: số bài trong m đã có mức tạ; bài chỉ có ghi chú không tính (UA3-01).
  int get logged => all
      .where((i) => i.exercise.logsWeight && !i.item.skipped && i.log != null)
      .length;
}

/// Bài của buổi ngày [date]: danh sách bài của buổi ([SessionList.build]) —
/// nhóm cơ theo thứ tự trong lịch (FA3-16), mỗi nhóm là danh sách phẳng theo
/// thứ tự thư viện (F20-R41, F18-R43), bài thay đứng đúng chỗ bài gốc, bài
/// thêm nối cuối; bài đã rời thư viện chỉ hiện khi buổi có bản ghi của bài
/// đó (F20-E1). Sửa riêng nhóm cơ hôm nay thì danh sách đổi theo ngay
/// (F20-E2). Đọc từ Drift, không chờ mạng (UR2-10).
final sessionExercisesProvider = Provider.family<SessionExercises?, LocalDate>((
  ref,
  date,
) {
  final session = ref.watch(sessionProvider(date));
  final library = ref.watch(allExercisesProvider).value;
  final logs = ref.watch(allLiftLogsProvider).value;
  final notes = ref.watch(allExerciseNotesProvider).value;
  final feels = ref.watch(allExerciseFeelsProvider).value;
  final units = ref.watch(exerciseUnitsProvider).value;
  final rows = ref.watch(sessionRowsProvider(date)).value;
  if (session == null ||
      library == null ||
      logs == null ||
      notes == null ||
      feels == null ||
      units == null ||
      rows == null) {
    return null;
  }
  final dayLogs = {
    for (final l in logs)
      if (l.date == date) l.exerciseId: l,
  };
  final dayNotes = {
    for (final n in notes)
      if (n.date == date) n.exerciseId: n,
  };
  final dayFeels = {
    for (final f in feels)
      if (f.date == date) f.exerciseId: f,
  };
  SessionExercise entry(SessionItem it) {
    final e = it.exercise;
    final log = dayLogs[e.id];
    final previous = LiftLogRules.previousSession(logs, e.id, date);
    final note = dayNotes[e.id];
    final previousNote = ExerciseNoteRules.previous(
      notes: notes,
      logs: logs,
      exercise: e,
      date: date,
    );
    return (
      exercise: e,
      item: it,
      log: log,
      previous: previous,
      note: note,
      previousNote: previousNote,
      feel: dayFeels[e.id],
      previousFeel: FeelRules.previous(
        feels: feels,
        logs: logs,
        exercise: e,
        date: date,
      ),
      unit: units[e.id]?.unit,
      state: LiftRowRules.of(
        window: session.window,
        logsWeight: e.logsWeight,
        active: e.active,
        sessionLog: log,
        previous: previous,
      ),
      noteMark: LiftRowRules.noteMark(
        sessionNote: note,
        previousNote: previousNote,
      ),
    );
  }

  final items = SessionList.build(
    library: library,
    groups: session.muscles,
    // Buổi tập thêm không có đổi / bỏ / thêm bài (F28-R9).
    rows: session.isExtra ? const [] : rows,
    loggedToday: dayLogs.keys.toSet(),
  );
  return SessionExercises(
    [
      for (final group in session.muscles)
        (
          group: group,
          items: [
            for (final it in items)
              if (it.slotGroup == group) entry(it),
          ],
        ),
    ],
    extras: [
      for (final it in items)
        if (it.role == SessionExerciseRole.extra) entry(it),
    ],
  );
});

/// Buổi ngày [date] cho đổi / bỏ qua / thêm bài lúc này (05 Bản 5 §6.4.3
/// `sessionActionsProvider`): buổi theo lịch hôm nay, còn trong ngày, chưa
/// "Đã tập" (F28-R1, R7, R9; BR5-13). null khi được; ngược lại là lý do.
final sessionActionsProvider = Provider.family<SessionEditError?, LocalDate>(
  (ref, date) => SessionList.editError(
    ref.watch(dayProvider(date)).value,
    ref.watch(nowProvider),
  ),
);

/// Bài chọn được ở S-75 cho buổi ngày [date] (05 Bản 5 §6.4.3
/// `pickableExercisesProvider`, FC5-04): thư viện phẳng trừ bài trong buổi
/// và bài gốc đang bị thay.
final pickableExercisesProvider = Provider.family<List<Exercise>?, LocalDate>((
  ref,
  date,
) {
  final library = ref.watch(allExercisesProvider).value;
  final exercises = ref.watch(sessionExercisesProvider(date));
  if (library == null || exercises == null) return null;
  return SessionList.pickable(library, [for (final e in exercises.all) e.item]);
});
