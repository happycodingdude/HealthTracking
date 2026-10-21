import 'package:domain/domain.dart';
import 'package:test/test.dart';

Exercise _ex(
  MuscleRegion r, {
  String suffix = 'a',
  int? seconds = 45,
  List<String> steps = const ['Một', 'Hai', 'Ba'],
  List<String> safety = const ['Một', 'Hai'],
  bool active = true,
}) => Exercise(
  id: '${r.id}-$suffix'.replaceAll('_', '-'),
  region: r,
  nameVi: 'Bài ${r.id} $suffix',
  youtubeVideoId: 'abcdefghijk',
  videoChannel: 'Kênh',
  videoDurationS: seconds,
  guideSteps: steps,
  guideSafety: safety,
  approvedAt: LocalDate(2026, 10, 11),
  active: active,
);

void main() {
  group('LIB-R1: id và tên không trùng (Bản 3 bỏ quy tắc máy/tạ, F18-R41)', () {
    test('mỗi vùng một bài, kể cả vùng chân, không có lỗi', () {
      final lib = [for (final r in MuscleRegion.values) _ex(r)];
      expect(lib, hasLength(19));
      expect(LibraryRules.coverageErrors(lib), isEmpty);
    });

    test('vùng không có bài hay nhiều bài cùng vùng là bình thường '
        '(A3-01, F18-E41)', () {
      final lib = [
        _ex(MuscleRegion.biceps),
        _ex(MuscleRegion.biceps, suffix: 'b'),
        _ex(MuscleRegion.biceps, suffix: 'c'),
      ];
      expect(LibraryRules.coverageErrors(lib), isEmpty);
    });

    test(
      'bài đã rời thư viện không tính; trùng id, tên trong các bài đang có',
      () {
        final lib = [
          _ex(MuscleRegion.lats),
          _ex(MuscleRegion.lats, active: false),
        ];
        expect(LibraryRules.coverageErrors(lib), isEmpty);
        final dup = [_ex(MuscleRegion.lats), _ex(MuscleRegion.lats)];
        expect(
          LibraryRules.coverageErrors(dup).map((i) => i.rule),
          containsAll(['id trùng', 'nameVi trùng']),
        );
      },
    );
  });

  group('cấu trúc bài (05 Bản 2 §6.10.2 bước 1) và cổng phát hành', () {
    test('LIB-R4: 3–6 bước, 2–4 ý; video ≤ 60 giây', () {
      const r = MuscleRegion.chestMid;
      expect(LibraryRules.entryErrors(_ex(r)), isEmpty);
      expect(LibraryRules.entryErrors(_ex(r, steps: const ['a', 'b'])), [
        'guide.steps',
      ]);
      expect(
        LibraryRules.entryErrors(
          _ex(r, safety: const ['a', 'b', 'c', 'd', 'e']),
        ),
        ['guide.safety'],
      );
      expect(LibraryRules.entryErrors(_ex(r, seconds: 61)), [
        'video.durationSeconds',
      ]);
      expect(
        LibraryRules.entryErrors(_ex(r, seconds: null)),
        isEmpty,
        reason: 'chưa đo vẫn nạp được trong lúc dev',
      );
    });

    test('LIB-AC2, LIB-AC3: cổng phát hành cần độ dài đã đo và hướng dẫn '
        'không có con số đi kèm kg, hiệp, lần', () {
      const r = MuscleRegion.backMid;
      expect(LibraryRules.releaseErrors(_ex(r)), isEmpty);
      expect(LibraryRules.releaseErrors(_ex(r, seconds: null)), [
        'video.durationSeconds',
      ]);
      for (final bad in [
        'Lặp lại 12 lần',
        'Tập 3 hiệp',
        'Bắt đầu với 2,5 kg',
        'Khoảng 10KG',
      ]) {
        expect(LibraryRules.releaseErrors(_ex(r, steps: ['Một', 'Hai', bad])), [
          'guide',
        ], reason: bad);
      }
      expect(
        LibraryRules.releaseErrors(
          _ex(
            r,
            steps: const ['Lặp lại với nhịp đều', 'Mỗi lần hạ chậm', '2 tay'],
          ),
        ),
        isEmpty,
      );
    });
  });

  test('TD3-07, F18-R43, PD3-02: nhóm theo thứ tự thư viện, trong nhóm theo '
      'thứ tự trong file; sortOrder = nhóm × 100 + vị trí', () {
    final file = [
      _ex(MuscleRegion.calves),
      _ex(MuscleRegion.chestMid, suffix: 'b'),
      _ex(MuscleRegion.lats),
      _ex(MuscleRegion.chestUpper),
      _ex(MuscleRegion.absMid),
      _ex(MuscleRegion.quads),
      _ex(MuscleRegion.chestMid),
    ];
    final sorted = LibraryRules.sorted(file);
    expect(sorted.map((e) => e.id), [
      'chest-mid-b',
      'chest-upper-a',
      'chest-mid-a',
      'lats-a',
      'abs-mid-a',
      'calves-a',
      'quads-a',
    ]);
    expect(sorted.map((e) => e.sortInGroup), [1, 2, 3, 1, 1, 1, 2]);
    expect(sorted.map((e) => e.sortOrder), [101, 102, 103, 201, 601, 701, 702]);
  });

  test('UR3-04, UA3-10: thứ tự thư viện khác thứ tự bộ chọn, Chân ở cuối', () {
    expect(MuscleGroup.libraryOrder, [
      MuscleGroup.chest,
      MuscleGroup.back,
      MuscleGroup.shoulders,
      MuscleGroup.biceps,
      MuscleGroup.triceps,
      MuscleGroup.abs,
      MuscleGroup.legs,
    ]);
    expect(MuscleGroup.pickerOrder, [
      MuscleGroup.chest,
      MuscleGroup.triceps,
      MuscleGroup.shoulders,
      MuscleGroup.abs,
      MuscleGroup.back,
      MuscleGroup.biceps,
      MuscleGroup.legs,
    ]);
    expect(LibraryRules.groupOrder, MuscleGroup.libraryOrder);
  });

  test('FR2-12, BR3-11: bài bụng không ghi mức tạ, bài chân có', () {
    expect(_ex(MuscleRegion.absMid).logsWeight, isFalse);
    expect(_ex(MuscleRegion.biceps).logsWeight, isTrue);
    expect(_ex(MuscleRegion.hamstrings).logsWeight, isTrue);
  });

  test('ED3-04: 14 bài bỏ, 15 bài giữ, không giao nhau', () {
    expect(LibraryV3.removedV2Ids, hasLength(14));
    expect(LibraryV3.keptV2Ids, hasLength(15));
    expect(LibraryV3.removedV2Ids.intersection(LibraryV3.keptV2Ids), isEmpty);
  });
}
