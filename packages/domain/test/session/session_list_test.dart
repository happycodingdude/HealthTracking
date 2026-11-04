// TAC5-12: toàn bộ unit test packages/domain (session_list, window, day_lock,
// feel, pause, gym, week_progress, widget_state) phủ mọi AC logic của 03
// Bản 5; chạy trong tool/check.sh.
import 'package:domain/domain.dart';
import 'package:domain/testing.dart';
import 'package:test/test.dart';

/// 06 Bản 5 VS53-T01, T05 (domain): danh sách bài của buổi (05 Bản 5 §6.4.1,
/// ED5-03), bài chọn được (FC5-04), cho đổi bài không (F28-R1, R7, R9), bài
/// thuộc buổi khi ghi mức tạ / ghi chú (TD5-09).
void main() {
  const c = SessionCasesV5.chest1;
  final library = SessionCasesV5.library;

  List<SessionItem> build(
    List<SessionExerciseRow> rows, {
    List<MuscleGroup> groups = const [MuscleGroup.chest],
  }) => SessionList.build(library: library, groups: groups, rows: rows);

  group('sessionCasesV5 (buildSessionList)', () {
    for (final kase in SessionCasesV5.cases) {
      test(kase.name, () {
        final items = build(kase.rows, groups: kase.groups);
        expect([
          for (final i in items) (i.id, i.role, i.replaces?.id, i.skipped),
        ], kase.expected);
      });
    }
  });

  test('F28-AC1: bài thay giữ chỗ (position) của bài gốc; slotGroup = nhóm '
      'của bài gốc', () {
    final items = build([
      SessionCasesV5.replace(SessionCasesV5.backPlate, SessionCasesV5.chest2),
    ]);
    expect(items, hasLength(4));
    expect(items[1].id, SessionCasesV5.backPlate);
    expect(items[1].position, 1);
    expect(items[1].slotGroup, MuscleGroup.chest);
    expect(items[1].original?.id, SessionCasesV5.chest2);
  });

  test('F28-E3: buổi nhiều nhóm Ngực + Lưng → bài thay đứng đúng chỗ bài '
      'gốc trong nhóm của nó', () {
    final items = build(
      [SessionCasesV5.replace(SessionCasesV5.legPress, SessionCasesV5.back1)],
      groups: const [MuscleGroup.chest, MuscleGroup.back],
    );
    expect(
      [for (final i in items) i.id],
      [
        SessionCasesV5.chest1,
        SessionCasesV5.chest2,
        SessionCasesV5.chest3,
        SessionCasesV5.chest4,
        SessionCasesV5.legPress,
        SessionCasesV5.backPlate,
      ],
    );
    expect(items[4].slotGroup, MuscleGroup.back);
    expect(items[4].replaces?.id, SessionCasesV5.back1);
  });

  test('F28-AC3: buổi sau không có dòng nào → danh sách gốc (đổi bài chỉ '
      'thuộc buổi hôm nay)', () {
    expect(
      [for (final i in build(const [])) i.role],
      [for (var i = 0; i < 4; i++) SessionExerciseRole.original],
    );
  });

  test('dòng thay trỏ bài gốc đã bị thay, bài không có trong thư viện, bài '
      'trùng → bỏ dòng', () {
    final items = build([
      SessionCasesV5.replace(SessionCasesV5.backPlate, SessionCasesV5.chest2),
      SessionCasesV5.replace(SessionCasesV5.back1, SessionCasesV5.chest2),
      SessionCasesV5.replace('khong-co', SessionCasesV5.chest3),
      SessionCasesV5.extra(SessionCasesV5.backPlate, 1),
      SessionCasesV5.extra(c, 2),
    ]);
    expect(
      [for (final i in items) i.id],
      [
        c,
        SessionCasesV5.backPlate,
        SessionCasesV5.chest3,
        SessionCasesV5.chest4,
      ],
    );
  });

  test('bài đã rời thư viện chỉ có trong danh sách khi hôm nay có bản ghi '
      '(F20-E1)', () {
    final old = Exercise(
      id: 'chest-old',
      region: MuscleRegion.chestMid,
      nameVi: 'Bài cũ',
      youtubeVideoId: 'v',
      videoChannel: 'c',
      guideSteps: const ['a'],
      guideSafety: const ['b'],
      approvedAt: LocalDate(2026, 10, 1),
      active: false,
    );
    List<String> ids(Set<String> logged) => [
      for (final i in SessionList.build(
        library: [...library, old],
        groups: const [MuscleGroup.chest],
        rows: const [],
        loggedToday: logged,
      ))
        i.id,
    ];
    expect(ids(const {}), isNot(contains('chest-old')));
    expect(ids(const {'chest-old'}), contains('chest-old'));
  });

  group('pickable (S-75, FC5-04, F28-R2)', () {
    test('F28-AC1: đổi bài 2 → danh sách chọn không có 3 bài ngực còn lại, '
        'không có bài 2 gốc, không có bài thay', () {
      final items = build([
        SessionCasesV5.replace(SessionCasesV5.backPlate, SessionCasesV5.chest2),
      ]);
      expect(
        [for (final e in SessionList.pickable(library, items)) e.id],
        [SessionCasesV5.back1, SessionCasesV5.plank, SessionCasesV5.legPress],
      );
    });

    test('bài bỏ qua, bài thêm cũng bị ẩn; bài đã rời thư viện không chọn '
        'được', () {
      final items = build([
        SessionCasesV5.skip(SessionCasesV5.chest3),
        SessionCasesV5.extra(SessionCasesV5.plank, 1),
      ]);
      final picked = [
        for (final e in SessionList.pickable(library, items)) e.id,
      ];
      expect(picked, [
        SessionCasesV5.back1,
        SessionCasesV5.backPlate,
        SessionCasesV5.legPress,
      ]);
    });
  });

  group('editError (F28-R1, R7, R9; F28-AC5)', () {
    final chestDay = PlanDay(
      date: ClockV5.wed,
      kind: DayKind.workout,
      time: LocalTime(18, 0),
      muscles: const [MuscleGroup.chest],
    );

    test('hôm nay chưa chốt — kể cả trước giờ tập, "Không tập" → được', () {
      expect(SessionList.editError(chestDay, ClockV5.gymArrival), isNull);
      expect(SessionList.editError(chestDay, ClockV5.t1805), isNull);
      expect(
        SessionList.editError(
          chestDay.withMark(DayMark.skipped, markedAt: ClockV5.t1805),
          ClockV5.t1900,
        ),
        isNull,
      );
    });

    test('"Đã tập" → done; bỏ "Đã tập" → được lại; sau 00:00 → notToday', () {
      final done = chestDay.withMark(
        DayMark.done,
        actual: chestDay.muscles,
        markedAt: ClockV5.t1805,
      );
      expect(SessionList.editError(done, ClockV5.t1900), SessionEditError.done);
      expect(SessionList.editError(chestDay, ClockV5.t2359), isNull);
      expect(
        SessionList.editError(chestDay, ClockV5.midnight),
        SessionEditError.notToday,
      );
    });

    test('F28-R9: buổi tập thêm, ngày nghỉ, ngày khác → notToday', () {
      final rest = PlanDay(date: ClockV5.wed, kind: DayKind.rest);
      expect(
        SessionList.editError(rest, ClockV5.t1805),
        SessionEditError.notToday,
      );
      expect(
        SessionList.editError(
          rest.withExtra(const [MuscleGroup.chest], loggedAt: ClockV5.t1805),
          ClockV5.t1900,
        ),
        SessionEditError.notToday,
      );
      expect(
        SessionList.editError(chestDay, DateTime(2026, 11, 3, 19)),
        SessionEditError.notToday,
      );
      expect(
        SessionList.editError(null, ClockV5.t1805),
        SessionEditError.notToday,
      );
    });
  });

  group(
    'TD5-09 bài thuộc buổi khi ghi mức tạ / ghi chú (TAC5-03 phần thay)',
    () {
      final day = PlanDay(
        date: ClockV5.wed,
        kind: DayKind.workout,
        time: LocalTime(18, 0),
        muscles: const [MuscleGroup.chest],
      );
      Exercise ex(String id) => library.firstWhere((e) => e.id == id);
      final rows = [
        SessionCasesV5.replace(SessionCasesV5.backPlate, SessionCasesV5.chest2),
      ];
      LiftError? lift(
        String id, {
        bool removing = false,
        bool exists = false,
      }) => LiftLogRules.check(
        day: day,
        exercise: ex(id),
        now: ClockV5.t1805,
        sessionRows: rows,
        removing: removing,
        exists: exists,
      );

      test('bài thay (khác nhóm) → được; bài gốc bị thay → không; bài ngoài '
          'buổi → không', () {
        expect(lift(SessionCasesV5.backPlate), isNull);
        expect(lift(SessionCasesV5.chest2), LiftError.exerciseNotInSession);
        expect(lift(SessionCasesV5.back1), LiftError.exerciseNotInSession);
        expect(lift(SessionCasesV5.chest1), isNull);
      });

      test('xóa bản ghi của bài vừa bị thay (FC5-14) → được', () {
        expect(
          lift(SessionCasesV5.chest2, removing: true, exists: true),
          isNull,
        );
      });

      test(
        'ghi chú theo cùng quy tắc; bài bụng ghi chú được khi là bài thay',
        () {
          expect(
            ExerciseNoteRules.check(
              day: day,
              exercise: ex(SessionCasesV5.backPlate),
              now: ClockV5.t1805,
              sessionRows: rows,
            ),
            isNull,
          );
          expect(
            ExerciseNoteRules.check(
              day: day,
              exercise: ex(SessionCasesV5.chest2),
              now: ClockV5.t1805,
              sessionRows: rows,
            ),
            LiftError.exerciseNotInSession,
          );
          expect(
            ExerciseNoteRules.check(
              day: day,
              exercise: ex(SessionCasesV5.plank),
              now: ClockV5.t1805,
              sessionRows: [
                SessionCasesV5.replace(
                  SessionCasesV5.plank,
                  SessionCasesV5.chest4,
                ),
              ],
            ),
            isNull,
          );
        },
      );
    },
  );

  group('06 Bản 5 VS54-T01: bỏ qua, thêm bài, bài kế tiếp, đếm n / m, sơ đồ '
      'cơ', () {
    const c1 = SessionCasesV5.chest1;
    const c2 = SessionCasesV5.chest2;
    const c3 = SessionCasesV5.chest3;
    const c4 = SessionCasesV5.chest4;
    const plank = SessionCasesV5.plank;
    const leg = SessionCasesV5.legPress;
    const back = SessionCasesV5.backPlate;
    LiftLog log(String id) => LiftLog(
      date: SessionCasesV5.date,
      exerciseId: id,
      startKgX10: 400,
      endKgX10: 450,
    );

    test('F20-AC61, FC5-05: đổi bài 2, bỏ qua bài 3, thêm Plank → 5 dòng, '
        '"Đã ghi 0 / 3"', () {
      final items = build([
        SessionCasesV5.replace(back, c2),
        SessionCasesV5.skip(c3),
        SessionCasesV5.extra(plank, 0),
      ]);
      expect(
        [for (final i in items) (i.id, i.role, i.skipped)],
        [
          (c1, SessionExerciseRole.original, false),
          (back, SessionExerciseRole.replacement, false),
          (c3, SessionExerciseRole.original, true),
          (c4, SessionExerciseRole.original, false),
          (plank, SessionExerciseRole.extra, false),
        ],
      );
      expect(SessionList.loggedCount(items, const {}), (logged: 0, total: 3));
      expect(SessionList.loggedCount(items, {c1, back}), (logged: 2, total: 3));
    });

    test('F29-AC1: bỏ qua bài 4 → "Đã ghi 0 / 3"', () {
      final items = build([SessionCasesV5.skip(c4)]);
      expect(SessionList.loggedCount(items, const {}), (logged: 0, total: 3));
    });

    test('F29-E1: bỏ qua 3 / 4 bài, ghi 1 bài → "Đã ghi 1 / 1"', () {
      final items = build([
        SessionCasesV5.skip(c2),
        SessionCasesV5.skip(c3),
        SessionCasesV5.skip(c4),
      ]);
      expect(SessionList.loggedCount(items, {c1}), (logged: 1, total: 1));
      expect(SessionList.allSkipped(items), isFalse);
    });

    test('F29-E2, F29-E4, FC5-03: bỏ qua tất cả bài (kể cả bài thêm) → '
        'allSkipped; còn một bài không bỏ qua → không', () {
      final all = build([
        for (final id in [c1, c2, c3, c4]) SessionCasesV5.skip(id),
        SessionCasesV5.extra(plank, 0).withSkipped(true),
      ]);
      expect(SessionList.allSkipped(all), isTrue);
      final one = build([
        for (final id in [c1, c2, c3, c4]) SessionCasesV5.skip(id),
        SessionCasesV5.extra(plank, 0),
      ]);
      expect(SessionList.allSkipped(one), isFalse);
      expect(SessionList.allSkipped(const []), isFalse);
      // F29-E4: buổi Bụng chỉ một bài, bỏ qua → bỏ qua tất cả.
      final abs = build(
        [SessionCasesV5.skip(plank)],
        groups: const [MuscleGroup.abs],
      );
      expect(SessionList.allSkipped(abs), isTrue);
    });

    test('F25-AC65, F25-R65: bỏ qua bài 1 → kế tiếp là bài 2; bỏ bài bụng, '
        'bài đã ghi; gồm bài thay, bài thêm', () {
      expect(
        SessionList.nextExercise(
          build([SessionCasesV5.skip(c1)]),
          const {},
        )?.id,
        c2,
      );
      final items = build([
        SessionCasesV5.replace(back, c2),
        SessionCasesV5.skip(c3),
        SessionCasesV5.skip(c4),
        SessionCasesV5.extra(plank, 0),
        SessionCasesV5.extra(leg, 1),
      ]);
      expect(SessionList.nextExercise(items, {c1})?.id, back);
      expect(SessionList.nextExercise(items, {c1, back})?.id, leg);
      expect(SessionList.nextExercise(items, {c1, back, leg}), isNull);
    });

    test('F30-E2: thêm 6 bài → bài kế tiếp vẫn theo thứ tự danh sách', () {
      final items = build([
        SessionCasesV5.extra(leg, 0),
        SessionCasesV5.extra(back, 1),
        SessionCasesV5.extra(SessionCasesV5.back1, 2),
      ]);
      expect(SessionList.nextExercise(items, {c1, c2, c3, c4})?.id, leg);
      expect(SessionList.nextExercise(items, {c1, c2, c3, c4, leg})?.id, back);
    });

    test('F25-R65: bài vừa ghi có thể là bài thêm; bản ghi của bài không còn '
        'trong buổi không tính', () {
      final items = build([SessionCasesV5.extra(leg, 0)]);
      expect(
        SessionList.lastLogged(items, [log(c1), log(leg)])?.exerciseId,
        leg,
      );
      expect(
        SessionList.lastLogged(build(const []), [
          log(c1),
          log(leg),
        ])?.exerciseId,
        c1,
      );
      expect(SessionList.lastLogged(items, const []), isNull);
    });

    test('FC5-06, F28-E1: sơ đồ cơ tô theo bài có bản ghi (gồm bài thay khác '
        'nhóm); bài bụng tô khi có ghi chú / mức thoải mái; bài bỏ qua không '
        'tô', () {
      final items = build([
        SessionCasesV5.replace(back, c2),
        SessionCasesV5.skip(c3),
        SessionCasesV5.extra(plank, 0),
      ]);
      expect(SessionList.activeRegions(items, loggedToday: {c1, back, c3}), {
        MuscleRegion.chestMid,
        MuscleRegion.backMid,
      });
      expect(
        SessionList.activeRegions(
          items,
          loggedToday: const {},
          notedToday: {plank},
        ),
        {MuscleRegion.absMid},
      );
      expect(
        SessionList.activeRegions(
          items,
          loggedToday: const {},
          feltToday: {plank},
        ),
        {MuscleRegion.absMid},
      );
    });

    test('F30-E3: thêm bài rồi bỏ qua chính bài đó → vẫn nằm cuối, đánh dấu '
        'bỏ qua; F30-AC3: S-75 không có bài của buổi, bài đã thêm', () {
      final items = build([
        SessionCasesV5.extra(plank, 0).withSkipped(true),
        SessionCasesV5.extra(leg, 1),
      ]);
      expect(items[4].id, plank);
      expect(items[4].skipped, isTrue);
      expect(items.last.id, leg);
      final pick = {for (final e in SessionList.pickable(library, items)) e.id};
      expect(pick, isNot(contains(plank)));
      expect(pick, isNot(contains(leg)));
      expect(pick.intersection({c1, c2, c3, c4}), isEmpty);
    });
  });

  test('IA5-11: buildSessionList < 5 ms — thư viện 28 bài, buổi 12 dòng (bài '
      'thay, bỏ qua, 6 bài thêm), trung bình 1000 lần', () {
    Exercise ex(String id, MuscleRegion region, int sort) => Exercise(
      id: id,
      region: region,
      nameVi: id,
      youtubeVideoId: 'v',
      videoChannel: 'c',
      guideSteps: const ['a'],
      guideSafety: const ['b'],
      approvedAt: LocalDate(2026, 10, 11),
      sortInGroup: sort,
      sortOrder: sort,
    );
    const others = [MuscleRegion.lats, MuscleRegion.quads, MuscleRegion.absMid];
    final big = [
      for (var i = 0; i < 6; i++) ex('chest-$i', MuscleRegion.chestMid, i),
      for (var i = 0; i < 22; i++) ex('other-$i', others[i % 3], 10 + i),
    ];
    final rows = [
      SessionCasesV5.replace('other-0', 'chest-1'),
      SessionCasesV5.skip('chest-2'),
      for (var i = 1; i <= 6; i++) SessionCasesV5.extra('other-$i', i),
    ];
    List<SessionItem> run() => SessionList.build(
      library: big,
      groups: const [MuscleGroup.chest],
      rows: rows,
    );
    expect(run(), hasLength(12));
    for (var i = 0; i < 100; i++) {
      run(); // khởi động JIT
    }
    final watch = Stopwatch()..start();
    for (var i = 0; i < 1000; i++) {
      run();
    }
    expect(watch.elapsedMicroseconds / 1000 / 1000, lessThan(5));
  });
}
