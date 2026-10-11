import 'package:domain/domain.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/time_ticker.dart';
import '../../../data/sync/sync_providers.dart';
import '../../schedule/application/schedule_providers.dart';

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

/// Một bài trong buổi kèm bản ghi của buổi đó (F20-R9).
typedef SessionExercise = ({Exercise exercise, LiftLog? log});

/// Một vùng cơ và các bài của vùng trong buổi.
typedef SessionRegion = ({MuscleRegion region, List<SessionExercise> items});

/// Một nhóm cơ của buổi và các vùng của nhóm.
typedef SessionGroup = ({MuscleGroup group, List<SessionRegion> regions});

/// Bài của buổi (05 Bản 2 §6.4.2 `sessionExercisesProvider`).
final class SessionExercises {
  const SessionExercises(this.groups);

  final List<SessionGroup> groups;

  Iterable<SessionExercise> get _all => [
    for (final g in groups)
      for (final r in g.regions) ...r.items,
  ];

  /// Số bài ghi mức tạ được (không tính bài bụng, 04 Bản 2 S-63).
  int get total => _all.where((i) => i.exercise.logsWeight).length;

  /// Số bài đã có mức tạ trong buổi.
  int get logged => _all.where((i) => i.log != null).length;
}

/// Bài của buổi ngày [date]: nhóm cơ của buổi → vùng → bài, thứ tự F18-R9,
/// chỉ bài thuộc nhóm cơ của buổi (F20-R5); bài đã rời thư viện chỉ hiện khi
/// buổi có bản ghi của bài đó (F20-E1). Sửa riêng nhóm cơ hôm nay thì danh
/// sách đổi theo ngay (F20-E2). Đọc từ Drift, không chờ mạng (UR2-10).
final sessionExercisesProvider = Provider.family<SessionExercises?, LocalDate>((
  ref,
  date,
) {
  final session = ref.watch(sessionProvider(date));
  final library = ref.watch(allExercisesProvider).value;
  final logs = ref.watch(dayLiftLogsProvider(date)).value;
  if (session == null || library == null || logs == null) return null;
  final byExercise = {for (final l in logs) l.exerciseId: l};
  return SessionExercises([
    for (final group in session.muscles)
      (
        group: group,
        regions: [
          for (final region in MuscleRegion.of(group))
            if ([
                  for (final e in library)
                    if (e.region == region &&
                        (e.active || byExercise.containsKey(e.id)))
                      (exercise: e, log: byExercise[e.id]),
                ]
                case final items when items.isNotEmpty)
              (region: region, items: items),
        ],
      ),
  ]);
});
