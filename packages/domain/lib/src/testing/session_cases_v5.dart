import '../exercise/exercise.dart';
import '../exercise/muscle_region.dart';
import '../schedule/weekly_template.dart';
import '../session/session_exercise.dart';
import '../time/local_date.dart';

/// Một tổ hợp của bảng [SessionCasesV5]: các dòng `session_exercise` của buổi
/// Ngực và danh sách bài mong đợi (mỗi phần tử: `id`, vai trò, bài gốc bị
/// thay, bỏ qua).
typedef SessionCaseV5 = ({
  String name,
  List<MuscleGroup> groups,
  List<SessionExerciseRow> rows,
  List<(String, SessionExerciseRole, String?, bool)> expected,
});

/// Bảng test chung cho danh sách bài của buổi (06 Bản 5 ED5-03, §6.10.2
/// `sessionCasesV5`): buổi Ngực 4 bài × tổ hợp đổi bài 2, bỏ qua bài 3, thêm
/// Plank + 1 bài chân, đổi tiếp, chọn lại gốc, đổi nhóm cơ sau khi đổi bài.
/// Domain, server và app dùng cùng một bảng. Id bài là id thật của thư viện.
abstract final class SessionCasesV5 {
  static final date = LocalDate(2026, 11, 4);

  static const chest1 = 'chest-mid-machine-pec-deck';
  static const chest2 = 'chest-mid-free-weight-flat-barbell-bench-press';
  static const chest3 = 'chest-upper-machine-incline-machine-chest-press';
  static const chest4 = 'chest-chest-lower-decline-plate-loaded-press';
  static const back1 = 'lats-machine-lat-pulldown';
  static const backPlate = 'back-back-mid-plate-loaded-row-machine';
  static const plank = 'abs-mid-bodyweight-forearm-plank';
  static const legPress = 'legs-quads-leg-press';

  static Exercise _ex(String id, MuscleRegion region, String name, int sort) =>
      Exercise(
        id: id,
        region: region,
        nameVi: name,
        youtubeVideoId: 'v',
        videoChannel: 'c',
        guideSteps: const ['a'],
        guideSafety: const ['b'],
        approvedAt: LocalDate(2026, 10, 11),
        sortInGroup: sort,
        sortOrder: sort,
      );

  /// Thư viện rút gọn theo thứ tự thư viện (F18-R43).
  static final library = [
    _ex(chest1, MuscleRegion.chestMid, 'Máy ép ngực', 1),
    _ex(chest2, MuscleRegion.chestMid, 'Nằm ghế ngang đẩy thanh tạ', 2),
    _ex(chest3, MuscleRegion.chestUpper, 'Nằm máy dốc lên có gắn bánh tạ', 3),
    _ex(chest4, MuscleRegion.chestLower, 'Nằm máy dốc xuống có gắn bánh tạ', 4),
    _ex(back1, MuscleRegion.lats, 'Ngồi kéo cáp dọc xuống', 5),
    _ex(backPlate, MuscleRegion.backMid, 'Máy dốc gắn bánh tạ', 6),
    _ex(plank, MuscleRegion.absMid, 'Plank', 7),
    _ex(legPress, MuscleRegion.quads, 'Nằm máy đạp chân', 8),
  ];

  static SessionExerciseRow replace(String id, String of) => SessionExerciseRow(
    date: date,
    exerciseId: id,
    role: SessionExerciseRole.replacement,
    replacesExerciseId: of,
    position: [chest1, chest2, chest3, chest4].indexOf(of),
  );

  static SessionExerciseRow skip(String id) => SessionExerciseRow(
    date: date,
    exerciseId: id,
    role: SessionExerciseRole.original,
    skipped: true,
  );

  static SessionExerciseRow extra(String id, int position) =>
      SessionExerciseRow(
        date: date,
        exerciseId: id,
        role: SessionExerciseRole.extra,
        position: position,
      );

  static const _o = SessionExerciseRole.original;
  static const _r = SessionExerciseRole.replacement;
  static const _x = SessionExerciseRole.extra;

  static final cases = <SessionCaseV5>[
    (
      name: 'buổi không đụng gì: 4 bài gốc theo thư viện',
      groups: const [MuscleGroup.chest],
      rows: const [],
      expected: const [
        (chest1, _o, null, false),
        (chest2, _o, null, false),
        (chest3, _o, null, false),
        (chest4, _o, null, false),
      ],
    ),
    (
      name: 'F28-AC1: đổi bài 2 sang bài lưng → bài thay đứng chỗ bài 2',
      groups: const [MuscleGroup.chest],
      rows: [replace(backPlate, chest2)],
      expected: const [
        (chest1, _o, null, false),
        (backPlate, _r, chest2, false),
        (chest3, _o, null, false),
        (chest4, _o, null, false),
      ],
    ),
    (
      name: 'F20-AC61: đổi bài 2, bỏ qua bài 3, thêm Plank + bài chân',
      groups: const [MuscleGroup.chest],
      rows: [
        extra(legPress, 2),
        replace(backPlate, chest2),
        skip(chest3),
        extra(plank, 1),
      ],
      expected: const [
        (chest1, _o, null, false),
        (backPlate, _r, chest2, false),
        (chest3, _o, null, true),
        (chest4, _o, null, false),
        (plank, _x, null, false),
        (legPress, _x, null, false),
      ],
    ),
    (
      name: 'F28-R6: đổi tiếp — vẫn một chỗ thay cho bài 2',
      groups: const [MuscleGroup.chest],
      rows: [replace(back1, chest2)],
      expected: const [
        (chest1, _o, null, false),
        (back1, _r, chest2, false),
        (chest3, _o, null, false),
        (chest4, _o, null, false),
      ],
    ),
    (
      name: 'FC5-04: chọn lại bài gốc (dòng thay đã tombstone) → về gốc',
      groups: const [MuscleGroup.chest],
      rows: const [],
      expected: const [
        (chest1, _o, null, false),
        (chest2, _o, null, false),
        (chest3, _o, null, false),
        (chest4, _o, null, false),
      ],
    ),
    (
      name:
          '05 §6.17: đổi nhóm cơ sang Lưng sau khi đổi bài → bỏ dòng thay, '
          'giữ bài thêm',
      groups: const [MuscleGroup.back],
      rows: [replace(legPress, chest2), skip(chest3), extra(plank, 1)],
      expected: const [
        (back1, _o, null, false),
        (backPlate, _o, null, false),
        (plank, _x, null, false),
      ],
    ),
  ];
}
