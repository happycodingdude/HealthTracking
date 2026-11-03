import '../day_lock.dart';
import '../exercise/exercise.dart';
import '../exercise/muscle_region.dart';
import '../lift_log/lift_log.dart';
import '../schedule/month_plan.dart';
import '../schedule/weekly_template.dart';
import '../time/local_date.dart';
import 'session_exercise.dart';

/// Một bài trong danh sách bài của buổi (03 Bản 5 §6.1, 05 Bản 5 §6.4.1).
final class SessionItem {
  const SessionItem({
    required this.exercise,
    required this.role,
    required this.position,
    this.replaces,
    this.skipped = false,
  });

  /// Bài đang đứng ở chỗ này (bài gốc, bài thay hoặc bài thêm).
  final Exercise exercise;
  final SessionExerciseRole role;

  /// Bài gốc bị thay; chỉ có với [SessionExerciseRole.replacement].
  final Exercise? replaces;

  /// Bỏ qua hôm nay (F-29).
  final bool skipped;

  /// Bài gốc / bài thay: chỗ của bài gốc trong danh sách gốc (0, 1, …); bài
  /// thêm: `position` của dòng (thứ tự thêm).
  final int position;

  String get id => exercise.id;

  /// Bài gốc của chỗ này: chính nó (bài gốc) hoặc bài bị thay (bài thay);
  /// null với bài thêm.
  Exercise? get original => switch (role) {
    SessionExerciseRole.original => exercise,
    SessionExerciseRole.replacement => replaces,
    SessionExerciseRole.extra => null,
  };

  /// Nhóm cơ của chỗ trong buổi (tiêu đề nhóm ở buổi nhiều nhóm): nhóm của
  /// bài gốc; bài thêm nối cuối, không thuộc nhóm nào.
  MuscleGroup? get slotGroup => original?.group;

  SessionItem copyWith({bool? skipped}) => SessionItem(
    exercise: exercise,
    role: role,
    position: position,
    replaces: replaces,
    skipped: skipped ?? this.skipped,
  );

  @override
  bool operator ==(Object other) =>
      other is SessionItem &&
      other.exercise.id == exercise.id &&
      other.role == role &&
      other.replaces?.id == replaces?.id &&
      other.skipped == skipped &&
      other.position == position;

  @override
  int get hashCode =>
      Object.hash(exercise.id, role, replaces?.id, skipped, position);

  @override
  String toString() =>
      'SessionItem(${exercise.id}, ${role.wire}'
      '${replaces == null ? '' : ' ← ${replaces!.id}'}'
      '${skipped ? ', bỏ qua' : ''})';
}

/// Lý do không đổi / bỏ qua / thêm bài được (F28-R1, R2, R7; 05 Bản 5
/// §6.4.2).
enum SessionEditError {
  /// Không phải buổi theo lịch của hôm nay (ngày khác, ngày nghỉ, buổi tập
  /// thêm — F28-R9), hoặc đã hết ngày (DayLock).
  notToday,

  /// Buổi đã "Đã tập" (BR5-13).
  done,

  /// Bài không có trong danh sách của buổi.
  notInSession,

  /// Bài chọn đang có trong buổi, là bài gốc đang bị thay, hoặc không còn
  /// trong thư viện (F28-R2, FC5-04, C5-03).
  notPickable,
}

final class SessionEditException implements Exception {
  const SessionEditException(this.error);

  final SessionEditError error;

  @override
  String toString() => 'SessionEditException(${error.name})';
}

/// Danh sách bài của buổi — **nguồn duy nhất** cho app (S-10, S-63, thẻ, đếm
/// n / m) và server (nội dung thẻ, kiểm tra bài hợp lệ) (06 Bản 5 ED5-03).
abstract final class SessionList {
  /// Danh sách bài của buổi có nhóm cơ [groups] (theo thứ tự hiển thị): bắt
  /// đầu từ danh sách gốc — bài của từng nhóm theo thứ tự [library] (F18-R43),
  /// bài đã rời thư viện chỉ khi có trong [loggedToday] (F20-E1) — rồi áp các
  /// dòng [rows] của ngày (05 Bản 5 §6.4.1):
  ///
  /// - `replacement` → thay bài gốc `replacesExerciseId` tại chỗ;
  /// - `original` + `skipped` → đánh dấu bài gốc bỏ qua;
  /// - `extra` → nối cuối theo `position` (thứ tự thêm, A5-02).
  ///
  /// Dòng trỏ bài gốc không còn trong buổi (đổi nhóm cơ sau khi đã đổi bài,
  /// 05 Bản 5 §6.17), bài không có trong [library], bài trùng: bỏ qua dòng
  /// đó. Bài thêm giữ nguyên khi đổi nhóm cơ.
  static List<SessionItem> build({
    required Iterable<Exercise> library,
    required Iterable<MuscleGroup> groups,
    required Iterable<SessionExerciseRow> rows,
    Set<String> loggedToday = const {},
  }) {
    final byId = {for (final e in library) e.id: e};
    final items = <SessionItem>[
      for (final g in groups)
        for (final e in library)
          if (e.group == g && (e.active || loggedToday.contains(e.id)))
            SessionItem(
              exercise: e,
              role: SessionExerciseRole.original,
              position: 0,
            ),
    ];
    for (var i = 0; i < items.length; i++) {
      final it = items[i];
      items[i] = SessionItem(exercise: it.exercise, role: it.role, position: i);
    }
    final slot = {for (final (i, it) in items.indexed) it.id: i};
    final ids = {for (final it in items) it.id};
    for (final r in rows) {
      if (r.role != SessionExerciseRole.original) continue;
      final i = slot[r.exerciseId];
      if (i != null) items[i] = items[i].copyWith(skipped: r.skipped);
    }
    for (final r in rows) {
      if (r.role != SessionExerciseRole.replacement) continue;
      final i = slot[r.replacesExerciseId];
      final e = byId[r.exerciseId];
      if (i == null || e == null || ids.contains(e.id)) continue;
      final current = items[i];
      if (current.role != SessionExerciseRole.original) continue;
      ids
        ..remove(current.id)
        ..add(e.id);
      items[i] = SessionItem(
        exercise: e,
        role: SessionExerciseRole.replacement,
        position: i,
        replaces: current.exercise,
        skipped: r.skipped,
      );
    }
    final extras =
        [
          for (final r in rows)
            if (r.role == SessionExerciseRole.extra) r,
        ]..sort((a, b) {
          final p = a.position.compareTo(b.position);
          return p != 0 ? p : a.exerciseId.compareTo(b.exerciseId);
        });
    for (final r in extras) {
      final e = byId[r.exerciseId];
      if (e == null || ids.contains(e.id)) continue;
      ids.add(e.id);
      items.add(
        SessionItem(
          exercise: e,
          role: SessionExerciseRole.extra,
          position: r.position,
          skipped: r.skipped,
        ),
      );
    }
    return items;
  }

  /// Bài kế tiếp (03 Bản 5 §6.1, F25-R65, 05 Bản 5 §6.4.1 `nextExercise`):
  /// bài đầu tiên trong danh sách [items] **có ghi tạ, chưa bỏ qua, chưa có
  /// bản ghi hôm nay** ([loggedToday]); gồm bài thay, bài thêm; bỏ qua bài
  /// bụng và bài bỏ qua (FC5-05). null = hết bài để ghi.
  static SessionItem? nextExercise(
    Iterable<SessionItem> items,
    Set<String> loggedToday,
  ) {
    for (final it in items) {
      if (it.exercise.logsWeight &&
          !it.skipped &&
          !loggedToday.contains(it.id)) {
        return it;
      }
    }
    return null;
  }

  /// Bài vừa ghi (F25-R4, F25-R65): bản ghi cuối cùng trong [todayInSaveOrder]
  /// (bản ghi hôm nay theo thứ tự lưu, cũ → mới) của một bài đang có trong
  /// danh sách [items] và không bỏ qua — có thể là bài thay / bài thêm.
  static LiftLog? lastLogged(
    Iterable<SessionItem> items,
    List<LiftLog> todayInSaveOrder,
  ) {
    final live = {
      for (final it in items)
        if (!it.skipped) it.id,
    };
    for (final l in todayInSaveOrder.reversed) {
      if (live.contains(l.exerciseId)) return l;
    }
    return null;
  }

  /// "Đã ghi n / m" (FC5-05, F20-R64): m = số bài có ghi tạ trong buổi, gồm
  /// bài thay và bài thêm, **trừ** bài bỏ qua; n = số bài trong m đã có bản
  /// ghi mức tạ hôm nay ([loggedToday]). Bài chỉ có ghi chú không tính.
  static ({int logged, int total}) loggedCount(
    Iterable<SessionItem> items,
    Set<String> loggedToday,
  ) {
    var total = 0, logged = 0;
    for (final it in items) {
      if (!it.exercise.logsWeight || it.skipped) continue;
      total++;
      if (loggedToday.contains(it.id)) logged++;
    }
    return (logged: logged, total: total);
  }

  /// Sơ đồ cơ của buổi (FC5-06, A5-04, 05 Bản 5 §6.4.1 `activeRegions`): vùng
  /// cơ của mọi bài **có bản ghi mức tạ** hôm nay ([loggedToday]); bài bụng
  /// (không ghi tạ) tô khi có ghi chú ([notedToday]) hoặc mức thoải mái
  /// ([feltToday]). Bài bỏ qua không tô. Nhóm cơ của buổi vẫn theo lịch.
  static Set<MuscleRegion> activeRegions(
    Iterable<SessionItem> items, {
    required Set<String> loggedToday,
    Set<String> notedToday = const {},
    Set<String> feltToday = const {},
  }) => {
    for (final it in items)
      if (!it.skipped &&
          (it.exercise.logsWeight
              ? loggedToday.contains(it.id)
              : notedToday.contains(it.id) || feltToday.contains(it.id)))
        it.exercise.region,
  };

  /// Mọi bài của buổi đều bỏ qua (FC5-03, F29-R5): bấm "Đã tập" thì hộp S-79
  /// và buổi lưu "Không tập". Danh sách trống → false.
  static bool allSkipped(Iterable<SessionItem> items) =>
      items.isNotEmpty && items.every((it) => it.skipped);

  /// Bài chọn được ở S-75 (F28-R2, F30-R2, FC5-04): bài còn trong thư viện,
  /// bất kỳ nhóm cơ, trừ bài đang có trong buổi (gốc chưa bị thay, thay,
  /// thêm, kể cả bài bỏ qua) và bài gốc đang bị thay. Giữ thứ tự [library].
  static List<Exercise> pickable(
    Iterable<Exercise> library,
    Iterable<SessionItem> items,
  ) {
    final taken = {
      for (final it in items) ...[it.id, ?it.replaces?.id],
    };
    return [
      for (final e in library)
        if (e.active && !taken.contains(e.id)) e,
    ];
  }

  /// Buổi [day] cho đổi / bỏ qua / thêm bài lúc [now] (giờ trên iPhone)?
  /// Chỉ buổi theo lịch của hôm nay, còn trong ngày, chưa "Đã tập" (F28-R1,
  /// R7, R9; F29-R1; F30-R1, R7). Xem được danh sách thì đổi được, kể cả
  /// trước giờ tập. Trả null khi được.
  static SessionEditError? editError(PlanDay? day, DateTime now) {
    if (day == null ||
        !day.isWorkout ||
        day.date != LocalDate.fromDateTime(now) ||
        !DayLock.isOpen(day.date, now)) {
      return SessionEditError.notToday;
    }
    if (day.mark == DayMark.done) return SessionEditError.done;
    return null;
  }

  static bool canEdit(PlanDay? day, DateTime now) =>
      editError(day, now) == null;
}
