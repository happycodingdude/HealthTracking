import '../exercise/exercise.dart';
import '../lift_log/lift_log.dart';
import '../schedule/weekly_template.dart';
import '../time/local_date.dart';

/// Vai trò của một bài trong buổi (05 Bản 5 TD5-03, 03 Bản 5 §6.1).
enum SessionExerciseRole {
  /// Bài gốc theo thư viện của nhóm cơ (chỉ có dòng khi bỏ qua).
  original('original'),

  /// Bài thay cho một bài gốc, chỉ buổi đó (F-28).
  replacement('replacement'),

  /// Bài lẻ nối cuối, chỉ buổi đó (F-30).
  extra('extra');

  const SessionExerciseRole(this.wire);

  /// Giá trị trong API và database.
  final String wire;

  static SessionExerciseRole? tryParse(String? wire) {
    for (final r in values) {
      if (r.wire == wire) return r;
    }
    return null;
  }
}

/// Một dòng "bài trong buổi" (entity `session_exercise`, key
/// `{date}:{exerciseId}`, 05 Bản 5 TD5-03). Bài gốc không bỏ qua, không bị
/// thay thì **không có dòng** (AP-20): danh sách gốc vẫn suy từ thư viện +
/// nhóm cơ. Hủy đổi / xóa bài thêm / hủy bỏ qua = tombstone.
final class SessionExerciseRow {
  const SessionExerciseRow({
    required this.date,
    required this.exerciseId,
    required this.role,
    this.replacesExerciseId,
    this.position = 0,
    this.skipped = false,
  });

  final LocalDate date;
  final String exerciseId;
  final SessionExerciseRole role;

  /// Bài gốc bị thay; chỉ (và bắt buộc) với [SessionExerciseRole.replacement].
  final String? replacesExerciseId;

  /// Thứ tự bài thêm (nối cuối theo thứ tự thêm, A5-02); bài gốc / bài thay
  /// đứng đúng chỗ bài gốc nên giá trị này không dùng để xếp.
  final int position;

  /// Bỏ qua hôm nay (F-29).
  final bool skipped;

  String get key => keyOf(date, exerciseId);

  /// Cùng dòng, đổi trạng thái bỏ qua (F-29: bỏ qua / hủy bỏ qua bài thay,
  /// bài thêm giữ vai trò và chỗ).
  SessionExerciseRow withSkipped(bool value) => SessionExerciseRow(
    date: date,
    exerciseId: exerciseId,
    role: role,
    replacesExerciseId: replacesExerciseId,
    position: position,
    skipped: value,
  );

  /// Cùng dạng key với `lift_log`.
  static String keyOf(LocalDate date, String exerciseId) =>
      LiftLog.keyOf(date, exerciseId);

  static (LocalDate, String)? parseKey(String key) => LiftLog.parseKey(key);

  /// Giới hạn cột `position smallint`.
  static const maxPosition = 32767;

  /// Trường sai về cấu trúc (05 Bản 5 §6.7 CHECK); null = hợp lệ.
  String? get invalidField {
    if ((role == SessionExerciseRole.replacement) !=
        (replacesExerciseId != null)) {
      return 'replacesExerciseId';
    }
    if (replacesExerciseId == exerciseId) return 'replacesExerciseId';
    if (position < 0 || position > maxPosition) return 'position';
    return null;
  }

  @override
  bool operator ==(Object other) =>
      other is SessionExerciseRow &&
      other.date == date &&
      other.exerciseId == exerciseId &&
      other.role == role &&
      other.replacesExerciseId == replacesExerciseId &&
      other.position == position &&
      other.skipped == skipped;

  @override
  int get hashCode => Object.hash(
    date,
    exerciseId,
    role,
    replacesExerciseId,
    position,
    skipped,
  );

  @override
  String toString() =>
      'SessionExerciseRow($key, ${role.wire}'
      '${replacesExerciseId == null ? '' : ' ← $replacesExerciseId'}'
      '${skipped ? ', bỏ qua' : ''})';
}

/// Kiểm tra một dòng `session_exercise` so với buổi (05 Bản 5 §6.6.2 bước 4,
/// TD5-03, FC5-04, C5-03). App (UI chặn trước) và server cùng dùng (AP-4).
abstract final class SessionExerciseRules {
  /// [row] định ghi cho buổi theo lịch có nhóm cơ [groups]; [exercise] là bài
  /// của dòng (null = không có trong thư viện); [library] là thư viện (kể cả
  /// bài đã rời); [others] là các dòng còn hiệu lực khác của cùng ngày (không
  /// gồm key của [row]). Trả tên trường sai, null = hợp lệ.
  ///
  /// - Bài phải có trong thư viện và còn dùng (`active`).
  /// - `original`: bài thuộc nhóm cơ của buổi; bài gốc đang bị thay không có
  ///   dòng bỏ qua.
  /// - `replacement`: bài gốc bị thay thuộc nhóm cơ buổi và chưa bị bài khác
  ///   thay, chưa có dòng bỏ qua; bài thay không phải bài gốc nào của buổi
  ///   (kể cả bài gốc đang bị thay — FC5-04) và không trùng bài thay / bài
  ///   thêm khác.
  /// - `extra`: không phải bài gốc nào của buổi, không trùng bài thay / bài
  ///   thêm khác (C5-03).
  static String? check({
    required SessionExerciseRow row,
    required Set<MuscleGroup> groups,
    required Exercise? exercise,
    required Iterable<Exercise> library,
    required Iterable<SessionExerciseRow> others,
  }) {
    if (exercise == null || !exercise.active) return 'exerciseId';
    final originals = {
      for (final e in library)
        if (e.active && groups.contains(e.group)) e.id,
    };
    final added = {
      for (final o in others)
        if (o.role != SessionExerciseRole.original) o.exerciseId,
    };
    bool replaced(String id) => others.any(
      (o) =>
          o.role == SessionExerciseRole.replacement &&
          o.replacesExerciseId == id,
    );
    bool skippedOriginal(String id) => others.any(
      (o) =>
          o.role == SessionExerciseRole.original &&
          o.exerciseId == id &&
          o.skipped,
    );
    switch (row.role) {
      case SessionExerciseRole.original:
        if (!originals.contains(row.exerciseId)) return 'exerciseId';
        if (row.skipped && replaced(row.exerciseId)) return 'skipped';
      case SessionExerciseRole.replacement:
        final target = row.replacesExerciseId!;
        if (!originals.contains(target) ||
            replaced(target) ||
            skippedOriginal(target)) {
          return 'replacesExerciseId';
        }
        if (originals.contains(row.exerciseId) ||
            added.contains(row.exerciseId)) {
          return 'exerciseId';
        }
      case SessionExerciseRole.extra:
        if (originals.contains(row.exerciseId) ||
            added.contains(row.exerciseId)) {
          return 'exerciseId';
        }
    }
    return null;
  }

  /// TD5-09 (05 Bản 5 §6.6.2): bài [exercise] được ghi mức tạ / ghi chú / mức
  /// thoải mái trong buổi có nhóm cơ [groups] khi **(a)** thuộc nhóm cơ của
  /// buổi và không có dòng đánh dấu bị thay hoặc bỏ qua, **hoặc (b)** có dòng
  /// bài thay / bài thêm của ngày đó và không bỏ qua. [rows] là các dòng còn
  /// hiệu lực của ngày.
  static bool inSession({
    required Exercise exercise,
    required Iterable<MuscleGroup> groups,
    required Iterable<SessionExerciseRow> rows,
  }) {
    final id = exercise.id;
    for (final r in rows) {
      if (r.exerciseId == id && r.role != SessionExerciseRole.original) {
        return !r.skipped;
      }
    }
    if (!groups.contains(exercise.group)) return false;
    return !rows.any(
      (r) =>
          (r.role == SessionExerciseRole.replacement &&
              r.replacesExerciseId == id) ||
          (r.role == SessionExerciseRole.original &&
              r.exerciseId == id &&
              r.skipped),
    );
  }
}
