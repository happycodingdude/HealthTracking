import 'package:domain/domain.dart';
import 'package:domain/testing.dart';
import 'package:test/test.dart';

/// 06 Bản 5 VS55-T01, T05 (domain): mức thoải mái buổi trước (FC5-07,
/// F33-R5, F33-E2), cửa sổ và bài thuộc buổi (F33-R3, R4, F33-AC5), độc lập
/// với mức tạ (F33-AC4).
void main() {
  final library = SessionCasesV5.library;
  Exercise ex(String id) => library.firstWhere((e) => e.id == id);
  final chest = ex(SessionCasesV5.chest1);
  final plank = ex(SessionCasesV5.plank);

  final d1 = LocalDate(2026, 10, 21);
  final d2 = LocalDate(2026, 10, 28);
  final today = LocalDate(2026, 11, 4);

  LiftLog log(LocalDate d, String id, int s, int e) =>
      LiftLog(date: d, exerciseId: id, startKgX10: s, endKgX10: e);
  ExerciseFeel feel(LocalDate d, String id, Feel f) =>
      ExerciseFeel(date: d, exerciseId: id, feel: f);

  group('FeelRules.previous (FC5-07)', () {
    test('F33-AC2: bài có mức tạ → mức thoải mái của đúng buổi trước theo '
        'mức tạ', () {
      final previous = FeelRules.previous(
        feels: [feel(d1, chest.id, Feel.hard), feel(d2, chest.id, Feel.easy)],
        logs: [log(d1, chest.id, 350, 400), log(d2, chest.id, 400, 450)],
        exercise: chest,
        date: today,
      );
      expect(previous?.feel, Feel.easy);
      expect(previous?.date, d2);
    });

    test('F33-E2: buổi trước có mức tạ nhưng không chọn mức thoải mái; buổi '
        'xa hơn có → không có dấu', () {
      final previous = FeelRules.previous(
        feels: [feel(d1, chest.id, Feel.hard)],
        logs: [log(d1, chest.id, 350, 400), log(d2, chest.id, 400, 450)],
        exercise: chest,
        date: today,
      );
      expect(previous, isNull);
    });

    test('A5-03: bài bị đổi / bỏ qua hôm trước (không bản ghi) → buổi trước '
        'là buổi trước nữa', () {
      final previous = FeelRules.previous(
        feels: [
          feel(d1, chest.id, Feel.medium),
          // Mức thoải mái còn lại sau khi xóa mức tạ (F33-R3): không phải
          // "buổi trước" vì buổi d2 không có bản ghi mức tạ.
          feel(d2, chest.id, Feel.hard),
        ],
        logs: [log(d1, chest.id, 350, 400)],
        exercise: chest,
        date: today,
      );
      expect(previous?.feel, Feel.medium);
    });

    test('mức thoải mái của chính hôm nay không là "buổi trước"', () {
      final previous = FeelRules.previous(
        feels: [feel(today, chest.id, Feel.hard)],
        logs: [log(today, chest.id, 400, 450)],
        exercise: chest,
        date: today,
      );
      expect(previous, isNull);
    });

    test('FC5-07: bài bụng → buổi gần nhất có mức thoải mái trước ngày', () {
      final previous = FeelRules.previous(
        feels: [
          feel(d1, plank.id, Feel.hard),
          feel(d2, plank.id, Feel.medium),
          feel(today, plank.id, Feel.easy),
        ],
        logs: const [],
        exercise: plank,
        date: today,
      );
      expect(previous?.feel, Feel.medium);
    });
  });

  group('FeelRules.check (F33-R3, R4; 05 Bản 5 §6.6.2)', () {
    final day = ClockV5.backDay;
    final back = ex(SessionCasesV5.back1);
    final backPlate = ex(SessionCasesV5.backPlate);

    test('trước giờ tập → windowClosed; từ giờ tập → được; 00:00 → '
        'windowClosed (F33-AC5)', () {
      LiftError? at(DateTime now, {PlanDay? d}) =>
          FeelRules.check(day: d ?? day, exercise: back, now: now);
      expect(at(DateTime(2026, 11, 4, 17, 25)), LiftError.windowClosed);
      expect(at(ClockV5.t1805), isNull);
      expect(at(ClockV5.t2359), isNull);
      expect(at(ClockV5.midnight), LiftError.windowClosed);
      // Tới gym 17:20 (FD5-01 = A): cửa sổ mở từ lúc tới gym.
      expect(
        at(
          DateTime(2026, 11, 4, 17, 25),
          d: day.withOpenedAt(ClockV5.gymArrival),
        ),
        isNull,
      );
    });

    test('FC5-05: bài bụng thêm vào buổi chọn được (không xét logsWeight); '
        'bài ngoài buổi → exerciseNotInSession; bỏ chọn không xét', () {
      final rows = [
        SessionExerciseRow(
          date: day.date,
          exerciseId: plank.id,
          role: SessionExerciseRole.extra,
        ),
      ];
      expect(
        FeelRules.check(
          day: day,
          exercise: plank,
          now: ClockV5.t1805,
          sessionRows: rows,
        ),
        isNull,
      );
      expect(
        FeelRules.check(day: day, exercise: plank, now: ClockV5.t1805),
        LiftError.exerciseNotInSession,
      );
      expect(
        FeelRules.check(
          day: day,
          exercise: plank,
          now: ClockV5.t1805,
          removing: true,
        ),
        isNull,
      );
      expect(
        FeelRules.check(day: day, exercise: backPlate, now: ClockV5.t1805),
        isNull,
      );
    });
  });

  test('Feel.tryParse: chỉ 3 giá trị (F33-V1)', () {
    expect(Feel.values.map((f) => f.wire), ['easy', 'medium', 'hard']);
    expect(Feel.tryParse('medium'), Feel.medium);
    expect(Feel.tryParse('tired'), isNull);
    expect(Feel.tryParse(null), isNull);
  });
}
