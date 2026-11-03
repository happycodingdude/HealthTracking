import '../exercise/exercise.dart';
import '../lift_log/exercise_unit.dart';
import '../lift_log/lift_kg.dart';
import '../lift_log/lift_log.dart';
import '../schedule/weekly_template.dart';
import '../session/session_exercise.dart';
import '../session/session_list.dart';
import '../widget_state/widget_state.dart';

/// Bài vừa ghi trên thẻ: tên + "{a} → {b} {đơn vị}".
typedef LiveActivityLift = ({String name, String lift});

/// Bài kế tiếp: tên + mức buổi trước (null = "Buổi trước: chưa ghi").
typedef LiveActivityNext = ({String name, String? prev});

/// Nội dung thẻ màn hình khóa S-71 (`content-state`, 05 Bản 3 §6.9.2): server
/// dựng lúc bật thẻ, app dựng lại sau mỗi lần lưu / sửa / xóa mức tạ (F25-R5).
/// Swift chỉ vẽ, không biết đơn vị (ED3-07); không có ghi chú (F25-R8).
final class LiveActivityContent {
  const LiveActivityContent({
    required this.lastLogged,
    required this.next,
    required this.allLogged,
    required this.absOnly,
  });

  /// [groups]: nhóm cơ của buổi theo thứ tự trong lịch; [library]: thư viện;
  /// [today]: bản ghi mức tạ hôm nay theo **thời điểm lưu** tăng dần (bản cuối
  /// là "bài vừa ghi", F25-R4); [previous]: bản ghi buổi trước của từng bài
  /// (FA3-01); [units]: đơn vị hiện tại của từng bài (FA3-04); [rows]: bài
  /// đổi / bỏ qua / thêm của buổi (Bản 5, TD5-03).
  ///
  /// Danh sách bài theo [SessionList.build] (ED5-03): "Kế tiếp" là
  /// [SessionList.nextExercise] (bỏ bài bỏ qua, bài bụng; gồm bài thay, bài
  /// thêm — F25-R65); "Vừa ghi" là [SessionList.lastLogged].
  factory LiveActivityContent.of({
    required List<MuscleGroup> groups,
    required Iterable<Exercise> library,
    required List<LiftLog> today,
    required Map<String, LiftLog> previous,
    required Map<String, ExerciseUnit> units,
    Iterable<SessionExerciseRow> rows = const [],
  }) {
    final byId = {for (final e in library) e.id: e};
    String lift(LiftLog l) => LiftFormat.range(
      l.startKgX10,
      l.endKgX10,
      units[l.exerciseId]?.unit ?? LiftUnit.kg,
    );
    final logged = {for (final l in today) l.exerciseId};
    // Thứ tự thư viện (F18-R43): server đọc thư viện không theo thứ tự.
    final ordered = [...library]
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    final items = SessionList.build(
      library: ordered,
      groups: groups,
      rows: rows,
      loggedToday: logged,
    );
    LiveActivityLift? lastLogged;
    if (SessionList.lastLogged(items, today) case final l?) {
      if (byId[l.exerciseId] case final e?) {
        lastLogged = (name: e.nameVi, lift: lift(l));
      }
    }
    LiveActivityNext? next;
    if (SessionList.nextExercise(items, logged) case final it?) {
      final prev = previous[it.id];
      next = (name: it.exercise.nameVi, prev: prev == null ? null : lift(prev));
    }
    return LiveActivityContent(
      lastLogged: lastLogged,
      next: next,
      allLogged: next == null,
      // Buổi chỉ có Bụng (F25-E3): bài thêm có ghi tạ (Bản 5) thì có "Kế
      // tiếp" như buổi thường.
      absOnly:
          groups.isNotEmpty &&
          groups.every((g) => g == MuscleGroup.abs) &&
          !items.any((it) => it.exercise.logsWeight && !it.skipped),
    );
  }

  /// FA3-16: các nhóm theo thứ tự trong lịch, trong mỗi nhóm là bài còn trong
  /// thư viện theo thứ tự thư viện.
  static List<Exercise> sessionOrder(
    List<MuscleGroup> groups,
    Iterable<Exercise> library,
  ) => [
    for (final g in groups)
      ...([
        for (final e in library)
          if (e.active && e.group == g) e,
      ]..sort((a, b) => a.sortOrder.compareTo(b.sortOrder))),
  ];

  /// "Ngực + Tay sau" (F24-R4, F25 nội dung thẻ).
  static String groupsTitle(List<MuscleGroup> groups) =>
      groups.map(VietnameseLabels.muscle).join(' + ');

  final LiveActivityLift? lastLogged;
  final LiveActivityNext? next;

  /// Hết bài để ghi (F25-E2): "Đã ghi hết bài".
  final bool allLogged;

  /// Buổi chỉ có Bụng (F25-E3, UA3-15).
  final bool absOnly;

  /// `content-state` của push và của ActivityKit.
  Map<String, Object?> toJson() => {
    'lastLogged': switch (lastLogged) {
      final l? => {'name': l.name, 'lift': l.lift},
      null => null,
    },
    'next': switch (next) {
      final n? => {'name': n.name, 'prev': n.prev},
      null => null,
    },
    'allLogged': allLogged,
    'absOnly': absOnly,
  };

  @override
  bool operator ==(Object other) =>
      other is LiveActivityContent &&
      other.lastLogged == lastLogged &&
      other.next == next &&
      other.allLogged == allLogged &&
      other.absOnly == absOnly;

  @override
  int get hashCode => Object.hash(lastLogged, next, allLogged, absOnly);
}
