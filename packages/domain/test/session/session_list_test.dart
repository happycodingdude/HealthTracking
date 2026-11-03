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
}
