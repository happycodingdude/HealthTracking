import 'package:domain/domain.dart';
import 'package:test/test.dart';

/// 05 Bản 5 §6.6.2 bước 4, TD5-03, FC5-04, C5-03: kiểm tra dòng
/// `session_exercise` (server dùng ngay từ VS-52, ED5-01).
void main() {
  Exercise ex(String id, MuscleGroup g, {bool active = true}) => Exercise(
    id: id,
    region: MuscleRegion.values.firstWhere((r) => r.group == g),
    nameVi: id,
    youtubeVideoId: 'v',
    videoChannel: 'c',
    videoAvailable: true,
    guideSteps: const ['a'],
    guideSafety: const ['b'],
    approvedAt: LocalDate(2026, 10, 1),
    sortInGroup: 0,
    sortOrder: 0,
    active: active,
  );
  final library = [
    ex('c1', MuscleGroup.chest),
    ex('c2', MuscleGroup.chest),
    ex('b1', MuscleGroup.back),
    ex('a1', MuscleGroup.abs),
    ex('old', MuscleGroup.back, active: false),
  ];
  final date = LocalDate(2026, 11, 4);
  final chest = {MuscleGroup.chest};
  Exercise? find(String id) => library.where((e) => e.id == id).firstOrNull;
  String? check(
    SessionExerciseRow row, [
    List<SessionExerciseRow> others = const [],
  ]) => SessionExerciseRules.check(
    row: row,
    groups: chest,
    exercise: find(row.exerciseId),
    library: library,
    others: others,
  );
  SessionExerciseRow replace(String id, String of) => SessionExerciseRow(
    date: date,
    exerciseId: id,
    role: SessionExerciseRole.replacement,
    replacesExerciseId: of,
  );
  SessionExerciseRow extra(String id, [int pos = 1]) => SessionExerciseRow(
    date: date,
    exerciseId: id,
    role: SessionExerciseRole.extra,
    position: pos,
  );
  SessionExerciseRow skip(String id) => SessionExerciseRow(
    date: date,
    exerciseId: id,
    role: SessionExerciseRole.original,
    skipped: true,
  );

  test('cấu trúc: replacement ⇔ có bài gốc; bài thay khác bài gốc', () {
    expect(
      SessionExerciseRow(
        date: date,
        exerciseId: 'b1',
        role: SessionExerciseRole.replacement,
      ).invalidField,
      'replacesExerciseId',
    );
    expect(replace('c1', 'c1').invalidField, 'replacesExerciseId');
    expect(extra('b1', -1).invalidField, 'position');
    expect(replace('b1', 'c1').invalidField, isNull);
  });

  test('đổi bài gốc sang bài bất kỳ nhóm (BR5-10)', () {
    expect(check(replace('b1', 'c1')), isNull);
    expect(check(replace('a1', 'c2')), isNull);
  });

  test('FC5-04: bài thay không được là bài gốc (kể cả đang bị thay), không '
      'trùng bài thay / bài thêm khác; một bài gốc một chỗ thay', () {
    expect(check(replace('c2', 'c1')), 'exerciseId');
    expect(check(replace('c1', 'c2'), [replace('b1', 'c1')]), 'exerciseId');
    expect(check(replace('b1', 'c2'), [extra('b1')]), 'exerciseId');
    expect(
      check(replace('a1', 'c1'), [replace('b1', 'c1')]),
      'replacesExerciseId',
    );
    expect(
      check(replace('b1', 'a1')),
      'replacesExerciseId',
      reason: 'a1 không phải bài gốc',
    );
  });

  test('bài gốc đang bỏ qua thì không thay; bài gốc bị thay không bỏ qua', () {
    expect(check(replace('b1', 'c1'), [skip('c1')]), 'replacesExerciseId');
    expect(check(skip('c1'), [replace('b1', 'c1')]), 'skipped');
    expect(check(skip('c1')), isNull);
    expect(check(skip('b1')), 'exerciseId', reason: 'không thuộc nhóm cơ buổi');
  });

  test('C5-03: bài thêm không trùng bài đang có trong buổi', () {
    expect(check(extra('a1')), isNull);
    expect(check(extra('c1')), 'exerciseId');
    expect(check(extra('b1'), [replace('b1', 'c1')]), 'exerciseId');
    expect(check(extra('old')), 'exerciseId', reason: 'bài đã rời thư viện');
  });

  test('TD5-09: bài hợp lệ để ghi mức tạ / ghi chú / mức thoải mái', () {
    bool inSession(String id, List<SessionExerciseRow> rows) =>
        SessionExerciseRules.inSession(
          exercise: find(id)!,
          groups: chest,
          rows: rows,
        );
    expect(inSession('c1', const []), isTrue);
    expect(inSession('b1', const []), isFalse);
    expect(
      inSession('c1', [replace('b1', 'c1')]),
      isFalse,
      reason: 'gốc bị thay',
    );
    expect(inSession('b1', [replace('b1', 'c1')]), isTrue, reason: 'bài thay');
    expect(inSession('a1', [extra('a1')]), isTrue, reason: 'bài thêm');
    expect(inSession('c2', [skip('c2')]), isFalse, reason: 'bỏ qua');
    final skippedExtra = SessionExerciseRow(
      date: date,
      exerciseId: 'a1',
      role: SessionExerciseRole.extra,
      skipped: true,
    );
    expect(inSession('a1', [skippedExtra]), isFalse);
  });
}
