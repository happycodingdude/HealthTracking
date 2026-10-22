import 'package:domain/domain.dart';
import 'package:test/test.dart';

/// 06 Bản 3 VS35-T08 (domain): đơn vị, bước, điền sẵn, cảnh báo, định dạng
/// (F-21 Bản 3) và ghi chú (F-26). App và server cùng bảng test (ED3-03).
void main() {
  LiftLog log(int day, String id, int start, int end) => LiftLog(
    date: LocalDate(2026, 11, day),
    exerciseId: id,
    startKgX10: start,
    endKgX10: end,
  );

  group('F21-R42, F21-V41 → V45: kiểm tra theo đơn vị', () {
    test('kg 0,5 → 300 bước 0,5, nhận "," và "."; nấc 1 → 50 số nguyên', () {
      expect(LiftKg.check('47,5', LiftUnit.kg), (475, null));
      expect(LiftKg.check('47.5', LiftUnit.kg), (475, null));
      expect(LiftKg.check('8', LiftUnit.steps), (80, null));
      // F21-AC47: 13,25 kg bị chặn (V43).
      expect(LiftKg.check('13,25', LiftUnit.kg).$2, LiftInputError.notStep);
      // F21-AC46: 8,5 nấc và 51 nấc cùng bị V44 chặn.
      expect(LiftKg.check('8,5', LiftUnit.steps).$2, LiftInputError.notStep);
      expect(LiftKg.check('51', LiftUnit.steps).$2, LiftInputError.outOfRange);
      expect(LiftKg.check('0', LiftUnit.steps).$2, LiftInputError.outOfRange);
      expect(LiftKg.check('abc', LiftUnit.steps).$2, LiftInputError.notNumber);
    });

    test('F21-V41, F21-AC43: chưa chọn đơn vị → lỗi đơn vị trước mọi lỗi '
        'khác; F21-V42: thiếu một số', () {
      final none = LiftInput.of('', '', null);
      expect((none.isValid, none.error), (false, LiftInputError.unitMissing));
      expect(LiftInput.of('8', '10', null).error, LiftInputError.unitMissing);
      expect(
        LiftInput.of('8', '', LiftUnit.steps).error,
        LiftInputError.missing,
      );
      final ok = LiftInput.of('8', '10', LiftUnit.steps);
      expect((ok.isValid, ok.startX10, ok.endX10), (true, 80, 100));
    });

    test('LiftRange.of: kg [5, 3000] bước 5; nấc [10, 500] bước 10', () {
      final kg = LiftRange.of(LiftUnit.kg);
      final steps = LiftRange.of(LiftUnit.steps);
      expect((kg.min, kg.max, kg.step), (5, 3000, 5));
      expect((steps.min, steps.max, steps.step), (10, 500, 10));
      expect(steps.contains(135), isTrue, reason: 'chỉ xét hai đầu');
      expect(steps.contains(510), isFalse);
    });
  });

  group('F21-R43, FA3-05, FA3-06: nút −bước / +bước', () {
    test('bước 2,5 kg; 1 nấc', () {
      expect(LiftStep.of(LiftUnit.kg), 25);
      expect(LiftStep.of(LiftUnit.steps), 10);
    });

    test('F21-AC41: 45 → 47,5; F21-AC47: 13 → 15,5; 12,5 → 15 (không làm '
        'tròn)', () {
      expect(LiftStep.apply(450, 1, LiftUnit.kg), 475);
      expect(LiftStep.apply(130, 1, LiftUnit.kg), 155);
      expect(LiftStep.apply(125, 1, LiftUnit.kg), 150);
      expect(LiftStep.apply(475, -1, LiftUnit.kg), 450);
    });

    test('F21-AC49: ô trống → không đổi; F21-E44: 300 kg +bước → không đổi; '
        'F21-E45: 1 nấc −bước → không đổi; kết quả ra ngoài khoảng → giữ '
        'nguyên', () {
      expect(LiftStep.apply(null, 1, LiftUnit.kg), isNull);
      expect(LiftStep.apply(null, -1, LiftUnit.steps), isNull);
      expect(LiftStep.apply(3000, 1, LiftUnit.kg), 3000);
      expect(LiftStep.apply(2990, 1, LiftUnit.kg), 2990);
      expect(LiftStep.apply(10, -1, LiftUnit.steps), 10);
      expect(LiftStep.apply(20, -1, LiftUnit.kg), 20, reason: '2 − 2,5 < 0,5');
    });

    test('F21-E43: đổi sang nấc, buổi trước 12,5 → +bước 13,5 → Lưu bị V44 '
        'chặn', () {
      final next = LiftStep.apply(125, 1, LiftUnit.steps)!;
      expect(next, 135);
      expect(
        LiftKg.check(LiftKg.format(next), LiftUnit.steps).$2,
        LiftInputError.notStep,
      );
    });
  });

  group('F21-R44, FA3-01: điền sẵn', () {
    const press = 'chest-mid-machine-pec-deck';

    test('F21-AC41, AC44: có buổi trước → hai ô = mức buổi trước', () {
      final previous = LiftLogRules.previousSession(
        [log(2, press, 400, 450), log(5, press, 80, 100)],
        press,
        LocalDate(2026, 11, 9),
      );
      expect(LiftPrefill.of(previous: previous), (
        startX10: 80,
        endX10: 100,
        fromPrevious: true,
      ));
    });

    test('F21-E46: đã có bản ghi hôm nay → hiện bản ghi hôm nay; F21-E47: '
        'xóa rồi mở lại → mức buổi trước; lần đầu → hai ô trống', () {
      final today = log(9, press, 420, 470);
      final previous = log(5, press, 400, 450);
      expect(LiftPrefill.of(today: today, previous: previous), (
        startX10: 420,
        endX10: 470,
        fromPrevious: false,
      ));
      expect(LiftPrefill.of(previous: previous).fromPrevious, isTrue);
      expect(LiftPrefill.of(), (
        startX10: null,
        endX10: null,
        fromPrevious: false,
      ));
    });

    test('FA3-09: buổi tương lai → mức gần nhất hiện có', () {
      expect(
        LiftLogRules.previousSession(
          [log(2, press, 400, 450), log(5, press, 420, 470)],
          press,
          LocalDate(2026, 11, 30),
        ),
        log(5, press, 420, 470),
      );
    });
  });

  group('F21-R45, FA3-07: cảnh báo mức kết thúc', () {
    test('F21-AC42: Lưu số điền sẵn không sửa → không cảnh báo', () {
      expect(EndWarning.of(450, 450, LiftUnit.kg, edited: false), isNull);
      expect(EndWarning.of(450, 300, LiftUnit.kg, edited: false), isNull);
    });

    test('F21-AC45: nấc buổi trước 10; 15 → cao hơn 5 nấc; 14 → không; 9 → '
        'thấp hơn 1 nấc', () {
      expect(
        EndWarning.of(100, 150, LiftUnit.steps),
        const EndWarning(EndWarningKind.muchHigher, 50),
      );
      expect(EndWarning.of(100, 140, LiftUnit.steps), isNull);
      expect(
        EndWarning.of(100, 90, LiftUnit.steps),
        const EndWarning(EndWarningKind.lower, 10),
      );
    });

    test('kg: cao hơn quá 10 kg hoặc thấp hơn → cảnh báo; lần đầu → không', () {
      expect(EndWarning.of(450, 550, LiftUnit.kg), isNull);
      expect(
        EndWarning.of(450, 555, LiftUnit.kg)?.kind,
        EndWarningKind.muchHigher,
      );
      expect(EndWarning.of(450, 445, LiftUnit.kg)?.kind, EndWarningKind.lower);
      expect(EndWarning.of(null, 450, LiftUnit.kg), isNull);
    });
  });

  test('ED3-03: định dạng "{a} → {b} {đơn vị}"', () {
    expect(LiftFormat.range(400, 475, LiftUnit.kg), '40 → 47,5 kg');
    expect(LiftFormat.range(80, 100, LiftUnit.steps), '8 → 10 nấc');
    expect(LiftFormat.range(125, 135, LiftUnit.steps), '12,5 → 13,5 nấc');
    expect(LiftFormat.value(475, LiftUnit.kg), '47,5 kg');
  });

  group('F-26: ghi chú', () {
    Exercise ex(MuscleRegion region, {bool active = true}) => Exercise(
      id: '${region.id}-a',
      region: region,
      nameVi: 'Bài',
      youtubeVideoId: 'abcdefghijk',
      videoChannel: 'Kênh',
      guideSteps: const ['a', 'b', 'c'],
      guideSafety: const ['a', 'b'],
      approvedAt: LocalDate(2026, 10, 11),
      active: active,
    );
    final press = ex(MuscleRegion.chestMid);
    final plank = ex(MuscleRegion.absMid);
    ExerciseNote note(int day, Exercise e, [String text = 'ghi chú']) =>
        ExerciseNote(
          date: LocalDate(2026, 11, day),
          exerciseId: e.id,
          text: text,
        );

    test('F26-V1, F26-AC3, F26-E1: tối đa 200 ký tự theo ký tự người đọc '
        'thấy; dán dài cắt còn 200', () {
      expect(ExerciseNoteRules.clip('a' * 201), 'a' * 200);
      expect(ExerciseNoteRules.length(ExerciseNoteRules.clip('a' * 201)), 200);
      // "ể" viết bằng ký tự tổ hợp và biểu tượng nhiều mã vẫn là 1 ký tự.
      const combined = 'ể';
      expect(ExerciseNoteRules.length(combined), 1);
      expect(ExerciseNoteRules.length('💪🏽'), 1);
      expect(ExerciseNoteRules.clip(combined * 250).length, 200 * 3);
      expect(ExerciseNoteRules.isValid('a' * 200), isTrue);
      expect(ExerciseNoteRules.isValid('a' * 201), isFalse);
    });

    test('F26-V2: chỉ khoảng trắng = trống (xóa ghi chú)', () {
      expect(ExerciseNoteRules.normalize('  \n '), '');
      expect(ExerciseNoteRules.normalize(' máy 2 hỏng '), 'máy 2 hỏng');
      expect(ExerciseNoteRules.isValid(''), isFalse);
    });

    test('FA3-02, F26-AC9: ghi chú buổi trước = của đúng buổi trước theo mức '
        'tạ; buổi đó không có ghi chú thì không hiện, dù buổi xa hơn có', () {
      final logs = [log(2, press.id, 400, 450), log(5, press.id, 400, 450)];
      expect(
        ExerciseNoteRules.previous(
          notes: [note(2, press)],
          logs: logs,
          exercise: press,
          date: LocalDate(2026, 11, 9),
        ),
        isNull,
      );
      expect(
        ExerciseNoteRules.previous(
          notes: [note(2, press), note(5, press, 'máy 5')],
          logs: logs,
          exercise: press,
          date: LocalDate(2026, 11, 9),
        ),
        note(5, press, 'máy 5'),
      );
    });

    test('F26-E2: buổi X có ghi chú không mức tạ, buổi Y trước X có mức tạ → '
        'ghi chú buổi trước là của Y; bài bụng: buổi gần nhất có ghi chú', () {
      expect(
        ExerciseNoteRules.previous(
          notes: [note(5, press, 'của X')],
          logs: [log(2, press.id, 400, 450)],
          exercise: press,
          date: LocalDate(2026, 11, 9),
        ),
        isNull,
      );
      expect(
        ExerciseNoteRules.previous(
          notes: [note(2, plank, 'cũ'), note(5, plank, 'mới'), note(9, plank)],
          logs: const [],
          exercise: plank,
          date: LocalDate(2026, 11, 9),
        ),
        note(5, plank, 'mới'),
      );
    });

    test('05 Bản 3 §6.6.4 bước 1 → 4: bài bụng có ghi chú; ngoài cửa sổ → '
        'khóa; bài đã rời thư viện chỉ sửa, xóa', () {
      final day = PlanDay(
        date: LocalDate(2026, 11, 9),
        kind: DayKind.workout,
        time: LocalTime(18, 0),
        muscles: const [MuscleGroup.chest, MuscleGroup.abs],
      );
      final at1830 = DateTime(2026, 11, 9, 18, 30);
      expect(
        ExerciseNoteRules.check(day: day, exercise: plank, now: at1830),
        isNull,
      );
      expect(
        ExerciseNoteRules.check(
          day: day,
          exercise: plank,
          now: DateTime(2026, 11, 10, 0, 1),
        ),
        LiftError.windowClosed,
      );
      expect(
        ExerciseNoteRules.check(day: null, exercise: plank, now: at1830),
        LiftError.noSession,
      );
      final gone = ex(MuscleRegion.chestUpper, active: false);
      expect(
        ExerciseNoteRules.check(day: day, exercise: gone, now: at1830),
        LiftError.notAllowedForExercise,
      );
      expect(
        ExerciseNoteRules.check(
          day: day,
          exercise: gone,
          now: at1830,
          exists: true,
        ),
        isNull,
      );
      expect(
        ExerciseNoteRules.check(
          day: day,
          exercise: ex(MuscleRegion.lats),
          now: at1830,
        ),
        LiftError.exerciseNotInSession,
      );
    });
  });
}
