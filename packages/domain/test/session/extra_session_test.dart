import 'package:domain/domain.dart';
import 'package:test/test.dart';

void main() {
  // Tuần 05/10 – 10/10/2026: thứ 5 08/10, thứ 7 10/10 nghỉ; thứ 6 09/10 tập.
  final thu = PlanDay(date: LocalDate(2026, 10, 8), kind: DayKind.rest);
  final sat = PlanDay(date: LocalDate(2026, 10, 10), kind: DayKind.rest);
  final fri = PlanDay(
    date: LocalDate(2026, 10, 9),
    kind: DayKind.workout,
    time: LocalTime(18, 0),
    muscles: const [MuscleGroup.shoulders],
  );
  final sun = PlanDay(date: LocalDate(2026, 10, 11), kind: DayKind.rest);
  final satNoon = DateTime(2026, 10, 10, 12);

  group('buổi tập thêm (F05-R7 → R11, F05-V2)', () {
    test('F05-AC6: không thêm được cho ngày mai, chủ nhật, ngày đã có buổi '
        'theo lịch', () {
      final fridayNoon = DateTime(2026, 10, 9, 12);
      expect(
        ExtraSessionRules.validate(sat, const [MuscleGroup.abs], fridayNoon),
        ExtraError.future,
        reason: 'ngày mai',
      );
      expect(
        ExtraSessionRules.validate(sun, const [
          MuscleGroup.abs,
        ], DateTime(2026, 10, 11, 12)),
        ExtraError.notRestDay,
        reason: 'chủ nhật (F05-E6)',
      );
      expect(
        ExtraSessionRules.validate(fri, const [MuscleGroup.abs], satNoon),
        ExtraError.notRestDay,
        reason: 'ngày đã có buổi theo lịch (F05-E4)',
      );
      expect(ExtraSessionRules.canLog(sat, fridayNoon), isFalse);
      expect(ExtraSessionRules.canLog(fri, satNoon), isFalse);
    });

    test('F05-R7, F05-R9: ngày nghỉ hôm nay hoặc trong 7 ngày trước', () {
      expect(ExtraSessionRules.canLog(sat, satNoon), isTrue);
      expect(ExtraSessionRules.canLog(thu, satNoon), isTrue);
      // 08/10 ghi được đến hết 15/10, từ 00:00 16/10 bị khóa.
      expect(
        ExtraSessionRules.canLog(thu, DateTime(2026, 10, 15, 23, 59)),
        isTrue,
      );
      expect(
        ExtraSessionRules.validate(thu, null, DateTime(2026, 10, 16)),
        ExtraError.locked,
      );
    });

    test('F05-V2, F05-R10: phải chọn ít nhất 1 nhóm cơ', () {
      expect(
        ExtraSessionRules.validate(sat, const [], satNoon),
        ExtraError.noMuscles,
      );
      expect(
        () => ExtraSessionRules.log(sat, const [], now: satNoon),
        throwsA(
          isA<ExtraException>().having(
            (e) => e.error,
            'error',
            ExtraError.noMuscles,
          ),
        ),
      );
    });

    test('F05-R8: ghi lại thay buổi đã có (tối đa 1 buổi mỗi ngày); thứ tự '
        'nhóm cơ chuẩn hóa; xóa bỏ cả nhóm cơ và thời điểm ghi (ED-08)', () {
      final added = ExtraSessionRules.log(sat, const [
        MuscleGroup.abs,
        MuscleGroup.chest,
      ], now: satNoon);
      expect(added.extraMuscles, [MuscleGroup.chest, MuscleGroup.abs]);
      expect(added.extraLoggedAt, satNoon);
      expect(added.invalidField, isNull);

      final later = DateTime(2026, 10, 10, 20);
      final edited = ExtraSessionRules.log(added, const [
        MuscleGroup.back,
      ], now: later);
      expect(edited.extraMuscles, [MuscleGroup.back]);
      expect(edited.extraLoggedAt, later);

      final deleted = ExtraSessionRules.log(edited, null, now: later);
      expect(deleted.extraMuscles, isNull);
      expect(deleted.extraLoggedAt, isNull);
      expect(deleted.invalidField, isNull);
    });

    test('F05-R11: quá 7 ngày không sửa, không xóa được', () {
      final added = ExtraSessionRules.log(thu, const [
        MuscleGroup.abs,
      ], now: DateTime(2026, 10, 8, 20));
      final late = DateTime(2026, 10, 16, 8);
      expect(
        () => ExtraSessionRules.log(added, null, now: late),
        throwsA(isA<ExtraException>()),
      );
      expect(
        () => ExtraSessionRules.log(added, const [MuscleGroup.back], now: late),
        throwsA(isA<ExtraException>()),
      );
    });

    test('ràng buộc bản ghi: buổi tập thêm có nhóm cơ ⇔ có thời điểm ghi; '
        'ngày tập không có buổi tập thêm', () {
      expect(
        sat.withExtra(const [MuscleGroup.abs]).invalidField,
        'extraLoggedAt',
      );
      expect(
        sat.withExtra(null, loggedAt: satNoon).invalidField,
        'extraLoggedAt',
      );
      expect(
        fri.withExtra(const [MuscleGroup.abs], loggedAt: satNoon).invalidField,
        'extraMuscles',
      );
    });
  });
}
