import 'package:domain/domain.dart';
import 'package:test/test.dart';

Exercise _ex(
  MuscleRegion r,
  Equipment e, {
  String suffix = 'a',
  int? seconds = 45,
  List<String> steps = const ['Một', 'Hai', 'Ba'],
  List<String> safety = const ['Một', 'Hai'],
  bool active = true,
}) => Exercise(
  id: '${r.id}-${e.wire}-$suffix'.replaceAll('_', '-'),
  region: r,
  equipment: e,
  nameVi: 'Bài ${r.id} ${e.wire} $suffix',
  youtubeVideoId: 'abcdefghijk',
  videoChannel: 'Kênh',
  videoDurationS: seconds,
  guideSteps: steps,
  guideSafety: safety,
  approvedAt: LocalDate(2026, 10, 11),
  active: active,
);

/// 13 vùng × (1 máy + 1 tạ) + 3 bài bụng.
List<Exercise> _min() => [
  for (final r in MuscleRegion.values)
    if (r.group == MuscleGroup.abs)
      _ex(r, Equipment.bodyweight)
    else ...[
      _ex(r, Equipment.machine),
      _ex(r, Equipment.freeWeight),
    ],
];

void main() {
  group('F18-R1, LIB-R8: đủ bài mỗi vùng', () {
    test(
      'F18-AC1: tối thiểu (29 bài) đạt; tối đa 2 máy + 2 tạ mỗi vùng đạt',
      () {
        expect(_min(), hasLength(29));
        expect(LibraryRules.coverageErrors(_min()), isEmpty);
        final max = [
          ..._min(),
          for (final r in MuscleRegion.values)
            if (r.group != MuscleGroup.abs) ...[
              _ex(r, Equipment.machine, suffix: 'b'),
              _ex(r, Equipment.freeWeight, suffix: 'b'),
            ],
        ];
        expect(max, hasLength(55));
        expect(LibraryRules.coverageErrors(max), isEmpty);
      },
    );

    test('thiếu bài tạ ở một vùng → lỗi đúng vùng', () {
      final lib = _min()
        ..removeWhere(
          (e) =>
              e.region == MuscleRegion.chestUpper &&
              e.equipment == Equipment.freeWeight,
        );
      final issues = LibraryRules.coverageErrors(lib);
      expect(issues, hasLength(1));
      expect(issues.single.rule, contains('chest_upper'));
      expect(issues.single.rule, contains('free_weight'));
    });

    test('thừa: 3 bài máy ở một vùng; vùng bụng 2 bài; bài không dụng cụ '
        'ngoài bụng', () {
      final three = [
        ..._min(),
        _ex(MuscleRegion.lats, Equipment.machine, suffix: 'b'),
        _ex(MuscleRegion.lats, Equipment.machine, suffix: 'c'),
      ];
      expect(LibraryRules.coverageErrors(three), hasLength(1));
      final abs2 = [
        ..._min(),
        _ex(MuscleRegion.obliques, Equipment.machine, suffix: 'b'),
      ];
      expect(LibraryRules.coverageErrors(abs2), hasLength(1));
      expect(
        LibraryRules.entryErrors(
          _ex(MuscleRegion.biceps, Equipment.bodyweight),
        ),
        ['equipment'],
      );
    });

    test('bài đã rời thư viện không tính; tên trùng trong các bài đang có '
        '(LIB-R1)', () {
      final lib = _min()
        ..add(_ex(MuscleRegion.lats, Equipment.machine, active: false));
      expect(LibraryRules.coverageErrors(lib), isEmpty);
      final dup = _min()..add(_min().first);
      expect(
        LibraryRules.coverageErrors(dup).map((i) => i.rule),
        containsAll(['id trùng', 'nameVi trùng']),
      );
    });
  });

  group('cấu trúc bài (05 Bản 2 §6.10.2 bước 1) và cổng phát hành', () {
    test('LIB-R4: 3–6 bước, 2–4 ý; video ≤ 60 giây', () {
      const r = MuscleRegion.chestMid;
      expect(LibraryRules.entryErrors(_ex(r, Equipment.machine)), isEmpty);
      expect(
        LibraryRules.entryErrors(
          _ex(r, Equipment.machine, steps: const ['a', 'b']),
        ),
        ['guide.steps'],
      );
      expect(
        LibraryRules.entryErrors(
          _ex(r, Equipment.machine, safety: const ['a', 'b', 'c', 'd', 'e']),
        ),
        ['guide.safety'],
      );
      expect(LibraryRules.entryErrors(_ex(r, Equipment.machine, seconds: 61)), [
        'video.durationSeconds',
      ]);
      expect(
        LibraryRules.entryErrors(_ex(r, Equipment.machine, seconds: null)),
        isEmpty,
        reason: 'chưa đo vẫn nạp được trong lúc dev',
      );
    });

    test('LIB-AC2, LIB-AC3: cổng phát hành cần độ dài đã đo và hướng dẫn '
        'không có con số đi kèm kg, hiệp, lần', () {
      const r = MuscleRegion.backMid;
      expect(LibraryRules.releaseErrors(_ex(r, Equipment.machine)), isEmpty);
      expect(
        LibraryRules.releaseErrors(_ex(r, Equipment.machine, seconds: null)),
        ['video.durationSeconds'],
      );
      for (final bad in [
        'Lặp lại 12 lần',
        'Tập 3 hiệp',
        'Bắt đầu với 2,5 kg',
        'Khoảng 10KG',
      ]) {
        expect(
          LibraryRules.releaseErrors(
            _ex(r, Equipment.machine, steps: ['Một', 'Hai', bad]),
          ),
          ['guide'],
          reason: bad,
        );
      }
      expect(
        LibraryRules.releaseErrors(
          _ex(
            r,
            Equipment.machine,
            steps: const ['Lặp lại với nhịp đều', 'Mỗi lần hạ chậm', '2 tay'],
          ),
        ),
        isEmpty,
      );
    });
  });

  test('F18-R9: thứ tự nhóm → vùng → máy trước tạ sau → thứ tự trong file', () {
    final shuffled = _min().reversed.toList()
      ..insert(0, _ex(MuscleRegion.chestUpper, Equipment.machine, suffix: 'z'));
    final sorted = LibraryRules.sorted(shuffled);
    expect(
      [for (final e in sorted) e.sortOrder],
      [for (var i = 1; i <= 30; i++) i],
    );
    expect(sorted.take(4).map((e) => e.id), [
      'chest-upper-machine-z',
      'chest-upper-machine-a',
      'chest-upper-free-weight-a',
      'chest-mid-machine-a',
    ]);
    final groups = sorted.map((e) => e.group).toSet().toList();
    expect(groups, LibraryRules.groupOrder);
    expect(sorted.last.region, MuscleRegion.obliques);
  });

  test('FR2-12: bài bụng không ghi mức tạ', () {
    expect(_ex(MuscleRegion.absMid, Equipment.bodyweight).logsWeight, isFalse);
    expect(_ex(MuscleRegion.biceps, Equipment.machine).logsWeight, isTrue);
  });
}
