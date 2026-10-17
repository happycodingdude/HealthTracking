import 'package:domain/domain.dart';
import 'package:test/test.dart';

void main() {
  final t1800 = LocalTime(18, 0);

  /// Buổi "Ngực 18:00" thứ 4 14/10/2026.
  final chestDay = PlanDay(
    date: LocalDate(2026, 10, 14),
    kind: DayKind.workout,
    time: t1800,
    muscles: const [MuscleGroup.chest],
  );

  Exercise ex(MuscleRegion region, Equipment equipment, {bool active = true}) =>
      Exercise(
        id: '${region.id}-${equipment.wire}',
        region: region,
        equipment: equipment,
        nameVi: 'Bài',
        youtubeVideoId: 'abcdefghijk',
        videoChannel: 'Kênh',
        guideSteps: const ['a', 'b', 'c'],
        guideSafety: const ['a', 'b'],
        approvedAt: LocalDate(2026, 10, 11),
        active: active,
      );

  final chestPress = ex(MuscleRegion.chestUpper, Equipment.freeWeight);
  final shoulderPress = ex(MuscleRegion.deltFront, Equipment.machine);
  final plank = ex(MuscleRegion.absMid, Equipment.bodyweight);

  group('LiftKg: nhập con số (F21-R6, F21-V1 → V4)', () {
    test('F21-E9: "72,5" và "72.5" đều là 72,5 kg', () {
      expect(LiftKg.check('72,5', LiftUnit.kg), (725, null));
      expect(LiftKg.check('72.5', LiftUnit.kg), (725, null));
      expect(LiftKg.check(' 12 ', LiftUnit.kg), (120, null));
      expect(LiftKg.check('72,50', LiftUnit.kg), (725, null));
    });

    test('F21-AC7: 0; 300,5; 72,3 bị từ chối với lỗi tương ứng; 0,5; 300; '
        '72,5 được', () {
      expect(LiftKg.check('0', LiftUnit.kg), (null, LiftInputError.outOfRange));
      expect(LiftKg.check('300,5', LiftUnit.kg), (
        null,
        LiftInputError.outOfRange,
      ));
      expect(LiftKg.check('72,3', LiftUnit.kg), (null, LiftInputError.notStep));
      expect(LiftKg.check('72,25', LiftUnit.kg), (
        null,
        LiftInputError.notStep,
      ));
      expect(LiftKg.check('0,5', LiftUnit.kg), (5, null));
      expect(LiftKg.check('300', LiftUnit.kg), (3000, null));
      expect(LiftKg.check('72,5', LiftUnit.kg), (725, null));
    });

    test('F21-V1, V4: trống → thiếu; chữ, dấu âm, hai dấu thập phân → không '
        'phải số', () {
      expect(LiftKg.check('', LiftUnit.kg), (null, LiftInputError.missing));
      expect(LiftKg.check('  ', LiftUnit.kg), (null, LiftInputError.missing));
      for (final bad in ['abc', '-5', '7,2,5', '12kg', '1e2', ',5']) {
        expect(LiftKg.check(bad, LiftUnit.kg), (
          null,
          LiftInputError.notNumber,
        ), reason: bad);
      }
    });

    test('F21-AC8: thiếu mức kết thúc → ô kết thúc báo thiếu', () {
      final input = LiftInput.of('12', '', LiftUnit.kg);
      expect(input.isValid, isFalse);
      expect(input.startError, isNull);
      expect(input.endError, LiftInputError.missing);
      final ok = LiftInput.of('12', '14', LiftUnit.kg);
      expect((ok.startX10, ok.endX10, ok.isValid), (120, 140, true));
    });

    test('UA2-10: − / + theo bước 0,5, chặn ở 0,5 và 300', () {
      expect(LiftKg.stepped(120, 1, LiftUnit.kg), 125);
      expect(LiftKg.stepped(120, -1, LiftUnit.kg), 115);
      expect(LiftKg.stepped(5, -1, LiftUnit.kg), 5);
      expect(LiftKg.stepped(3000, 1, LiftUnit.kg), 3000);
      expect(LiftKg.format(725), '72,5');
      expect(LiftKg.format(120), '12');
      expect(LiftKg.format(5), '0,5');
    });

    test('BR2-24 sửa 13/10: bài với máy ghi số thanh, bài với tạ ghi kg', () {
      expect(shoulderPress.liftUnit, LiftUnit.plates);
      expect(chestPress.liftUnit, LiftUnit.kg);
    });

    test('số thanh: số nguyên 1–30, không có số lẻ', () {
      const u = LiftUnit.plates;
      expect(LiftKg.check('7', u), (70, null));
      expect(LiftKg.check('1', u), (10, null));
      expect(LiftKg.check('30', u), (300, null));
      expect(LiftKg.check('0', u), (null, LiftInputError.outOfRange));
      expect(LiftKg.check('31', u), (null, LiftInputError.outOfRange));
      expect(LiftKg.check('7,5', u), (null, LiftInputError.notStep));
      expect(LiftKg.check('', u), (null, LiftInputError.missing));
      final input = LiftInput.of('7', '8,5', u);
      expect((input.startX10, input.endError), (70, LiftInputError.notStep));
    });

    test('số thanh: − / + mỗi lần 1 thanh, chặn ở 1 và 30', () {
      const u = LiftUnit.plates;
      expect(LiftKg.stepped(70, 1, u), 80);
      expect(LiftKg.stepped(70, -1, u), 60);
      expect(LiftKg.stepped(10, -1, u), 10);
      expect(LiftKg.stepped(300, 1, u), 300);
      expect(LiftKg.format(70), '7');
    });

    test('bản ghi kiểm tra theo đơn vị của bài (app và server cùng dùng)', () {
      LiftLog of(int start, int end) => LiftLog(
        date: LocalDate(2026, 10, 14),
        exerciseId: 'x',
        startKgX10: start,
        endKgX10: end,
      );
      expect(of(70, 80).invalidField(LiftUnit.plates), isNull);
      expect(of(75, 80).invalidField(LiftUnit.plates), 'startKgX10');
      expect(of(70, 310).invalidField(LiftUnit.plates), 'endKgX10');
      expect(of(75, 310).invalidField(LiftUnit.kg), isNull);
    });
  });

  group('cửa sổ ghi tạ (03 Bản 2 §6.1, 05 Bản 2 §6.4.3)', () {
    test('F21-AC1: buổi Ngực 18:00 → 17:59 chưa mở (mở lúc 18:00); 18:00 '
        'mở đến 00:00 ngày sau', () {
      expect(
        LiftWindow.of(chestDay, DateTime(2026, 10, 14, 17, 59)),
        LiftWindowNotOpen(DateTime(2026, 10, 14, 18)),
      );
      expect(
        LiftWindow.of(chestDay, DateTime(2026, 10, 14, 18)),
        LiftWindowOpen(DateTime(2026, 10, 15)),
      );
    });

    test('F21-AC9: "Đã tập" lúc 19:00 vẫn ghi được lúc 20:00; 00:00 hôm sau '
        'đóng (F21-R5)', () {
      final done = SessionRules.markDone(
        chestDay,
        now: DateTime(2026, 10, 14, 19),
      );
      expect(LiftWindow.of(done, DateTime(2026, 10, 14, 20)).isOpen, isTrue);
      expect(
        LiftWindow.of(done, DateTime(2026, 10, 15)),
        const LiftWindowClosed(LiftClosedReason.ended),
      );
      // Không tập cũng không đổi cửa sổ (F21-R4, AP-9).
      final skipped = SessionRules.markSkipped(
        chestDay,
        now: DateTime(2026, 10, 14, 19),
      );
      expect(
        LiftWindow.of(skipped, DateTime(2026, 10, 14, 23, 59)).isOpen,
        isTrue,
      );
    });

    test('F21-E2: giờ tập 23:30 → cửa sổ chỉ còn 30 phút', () {
      final late = PlanDay(
        date: chestDay.date,
        kind: DayKind.workout,
        time: LocalTime(23, 30),
        muscles: const [MuscleGroup.chest],
      );
      expect(
        LiftWindow.of(late, DateTime(2026, 10, 14, 23, 29)).isOpen,
        isFalse,
      );
      expect(
        LiftWindow.of(late, DateTime(2026, 10, 14, 23, 59)).isOpen,
        isTrue,
      );
      expect(LiftWindow.of(late, DateTime(2026, 10, 15)).isOpen, isFalse);
    });

    test('buổi tập thêm hôm nay mở từ lúc lưu (FA2-11); F21-AC10: buổi tập '
        'thêm cho hôm qua không bao giờ mở', () {
      final rest = PlanDay(date: LocalDate(2026, 10, 15), kind: DayKind.rest);
      final today = rest.withExtra(const [
        MuscleGroup.back,
      ], loggedAt: DateTime(2026, 10, 15, 20));
      expect(
        LiftWindow.of(today, DateTime(2026, 10, 15, 19, 59)),
        LiftWindowNotOpen(DateTime(2026, 10, 15, 20)),
      );
      expect(LiftWindow.of(today, DateTime(2026, 10, 15, 20)).isOpen, isTrue);
      final yesterday = rest.withExtra(const [
        MuscleGroup.back,
      ], loggedAt: DateTime(2026, 10, 16, 9));
      expect(
        LiftWindow.of(yesterday, DateTime(2026, 10, 16, 9, 1)),
        const LiftWindowClosed(LiftClosedReason.pastExtra),
      );
    });

    test('ngày nghỉ không có buổi, chủ nhật → không có buổi', () {
      final rest = PlanDay(date: LocalDate(2026, 10, 15), kind: DayKind.rest);
      expect(
        LiftWindow.of(rest, DateTime(2026, 10, 15, 20)),
        const LiftWindowClosed(LiftClosedReason.noSession),
      );
      expect(
        LiftWindow.of(null, DateTime(2026, 10, 18, 20)),
        const LiftWindowClosed(LiftClosedReason.noSession),
      );
    });
  });

  group('ghi mức tạ (F21-R2 → R5, 05 Bản 2 §6.6.2)', () {
    final at = DateTime(2026, 10, 14, 18, 30);

    test('đúng buổi, đúng bài, trong cửa sổ → ghi được; ghi tạ không đổi '
        'trạng thái buổi (F21-AC12)', () {
      expect(
        LiftLogRules.check(day: chestDay, exercise: chestPress, now: at),
        isNull,
      );
      expect(
        SessionStatus.derive(chestDay, at)!.state,
        SessionState.awaitingMark,
      );
    });

    test('F21-AC13: bài bụng → không ghi được; F21-AC14: buổi Ngực không ghi '
        'bài Vai', () {
      final abs = PlanDay(
        date: chestDay.date,
        kind: DayKind.workout,
        time: t1800,
        muscles: const [MuscleGroup.chest, MuscleGroup.abs],
      );
      expect(
        LiftLogRules.check(day: abs, exercise: plank, now: at),
        LiftError.notAllowedForExercise,
      );
      expect(
        LiftLogRules.check(day: chestDay, exercise: shoulderPress, now: at),
        LiftError.exerciseNotInSession,
      );
    });

    test('thứ tự kiểm tra: không phải buổi → ngoài cửa sổ → bài → nhóm cơ', () {
      final rest = PlanDay(date: chestDay.date, kind: DayKind.rest);
      expect(
        LiftLogRules.check(day: rest, exercise: chestPress, now: at),
        LiftError.noSession,
      );
      expect(
        LiftLogRules.check(
          day: chestDay,
          exercise: shoulderPress,
          now: DateTime(2026, 10, 14, 17),
        ),
        LiftError.windowClosed,
      );
      expect(
        LiftLogRules.check(day: chestDay, exercise: null, now: at),
        LiftError.notAllowedForExercise,
      );
    });

    test('F21-E7: bài đã rời thư viện → không tạo mới; đã có bản ghi thì sửa, '
        'xóa được', () {
      final gone = ex(
        MuscleRegion.chestUpper,
        Equipment.freeWeight,
        active: false,
      );
      expect(
        LiftLogRules.check(day: chestDay, exercise: gone, now: at),
        LiftError.notAllowedForExercise,
      );
      expect(
        LiftLogRules.check(
          day: chestDay,
          exercise: gone,
          now: at,
          exists: true,
        ),
        isNull,
      );
    });

    test('F05-R38: buổi Bản 1 đã ghi nhóm cơ thực tế khác lịch → ghi theo '
        'nhóm cơ thực tế; buổi tập thêm theo nhóm cơ của buổi tập thêm', () {
      final legacy = chestDay.withMark(
        DayMark.done,
        actual: const [MuscleGroup.shoulders],
        markedAt: DateTime(2026, 10, 14, 19),
      );
      expect(
        LiftLogRules.check(day: legacy, exercise: shoulderPress, now: at),
        isNull,
      );
      expect(
        LiftLogRules.check(day: legacy, exercise: chestPress, now: at),
        LiftError.exerciseNotInSession,
      );
      final extra = PlanDay(date: LocalDate(2026, 10, 15), kind: DayKind.rest)
          .withExtra(const [
            MuscleGroup.shoulders,
          ], loggedAt: DateTime(2026, 10, 15, 20));
      expect(
        LiftLogRules.check(
          day: extra,
          exercise: shoulderPress,
          now: DateTime(2026, 10, 15, 21),
        ),
        isNull,
      );
    });
  });

  group('buổi trước và cảnh báo (FR2-06, F21-R8)', () {
    LiftLog log(int month, int day, int end, {String id = 'press'}) => LiftLog(
      date: LocalDate(2026, month, day),
      exerciseId: id,
      startKgX10: 100,
      endKgX10: end,
    );

    test('buổi trước = bản ghi gần nhất trước ngày đang xét của cùng bài, kể '
        'cả buổi "Không tập (tự động)" có bản ghi (F21-E5)', () {
      final logs = [
        log(10, 5, 120),
        log(10, 7, 140),
        log(10, 9, 999, id: 'other'),
        log(10, 14, 160),
      ];
      final prev = LiftLogRules.previousSession(
        logs,
        'press',
        LocalDate(2026, 10, 14),
      );
      expect(prev!.date, LocalDate(2026, 10, 7));
      expect(
        LiftLogRules.previousSession(logs, 'press', LocalDate(2026, 10, 5)),
        isNull,
      );
    });

    test('F21-AC4: buổi trước 14 kg, hôm nay 12 → thấp hơn 2 kg', () {
      expect(
        EndWarning.of(140, 120, LiftUnit.kg),
        const EndWarning(EndWarningKind.lower, 20),
      );
      expect(
        EndWarning.of(140, 135, LiftUnit.kg),
        const EndWarning(EndWarningKind.lower, 5),
      );
    });

    test('F21-AC5: 14 → 26 cảnh báo cao hơn 12 kg; 14 → 24 không cảnh báo; '
        'bằng nhau không cảnh báo', () {
      expect(
        EndWarning.of(140, 260, LiftUnit.kg),
        const EndWarning(EndWarningKind.muchHigher, 120),
      );
      expect(EndWarning.of(140, 240, LiftUnit.kg), isNull);
      expect(
        EndWarning.of(140, 245, LiftUnit.kg),
        const EndWarning(EndWarningKind.muchHigher, 105),
      );
      expect(EndWarning.of(140, 140, LiftUnit.kg), isNull);
    });

    test('bài với máy: cao hơn buổi trước quá 3 thanh mới cảnh báo; thấp hơn '
        'bất kỳ mức nào thì cảnh báo', () {
      const u = LiftUnit.plates;
      expect(EndWarning.of(70, 100, u), isNull);
      expect(
        EndWarning.of(70, 110, u),
        const EndWarning(EndWarningKind.muchHigher, 40),
      );
      expect(
        EndWarning.of(70, 60, u),
        const EndWarning(EndWarningKind.lower, 10),
      );
      expect(EndWarning.of(70, 70, u), isNull);
    });

    test('F21-AC6: lần ghi đầu tiên → không cảnh báo', () {
      expect(EndWarning.of(null, 5, LiftUnit.kg), isNull);
    });

    test('F21-AC3: ghi lại cùng bài cùng buổi là ghi đè (khóa ngày + bài)', () {
      final a = log(10, 14, 140);
      final b = a.copyWith(endKgX10: 160);
      expect(a.key, b.key);
      expect(a.key, '2026-10-14:press');
      expect(LiftLog.parseKey(a.key), (LocalDate(2026, 10, 14), 'press'));
      expect(LiftLog.parseKey('x'), isNull);
    });
  });
}
