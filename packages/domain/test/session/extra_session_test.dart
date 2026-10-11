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

  group('buổi tập thêm Bản 2 (F05-R31 → R35, F05-V21)', () {
    test('F05-R32, F05-E29: không thêm được cho ngày mai, chủ nhật, ngày đã có '
        'buổi theo lịch', () {
      final fridayNoon = DateTime(2026, 10, 9, 12);
      expect(
        ExtraSessionRules.validate(sat, null, fridayNoon),
        ExtraError.future,
      );
      expect(
        ExtraSessionRules.validate(sun, null, DateTime(2026, 10, 11, 12)),
        ExtraError.notRestDay,
      );
      expect(
        ExtraSessionRules.validate(fri, null, fridayNoon),
        ExtraError.notRestDay,
      );
    });

    test('F05-R32, F05-R35: ngày nghỉ hôm nay (bất kỳ lúc nào) hoặc trong 7 '
        'ngày trước', () {
      expect(
        ExtraSessionRules.canAdd(sat, DateTime(2026, 10, 10, 0, 1)),
        isTrue,
      );
      expect(ExtraSessionRules.canAdd(thu, satNoon), isTrue);
      expect(
        ExtraSessionRules.canAdd(thu, DateTime(2026, 10, 15, 23, 59)),
        isTrue,
      );
      expect(
        ExtraSessionRules.validate(thu, null, DateTime(2026, 10, 16)),
        ExtraError.locked,
      );
    });

    test('F05-V21: phải chọn ít nhất 1 nhóm cơ', () {
      expect(
        ExtraSessionRules.validate(sat, const [], satNoon),
        ExtraError.noMuscles,
      );
      expect(
        () => ExtraSessionRules.add(sat, const [], now: satNoon),
        throwsA(isA<ExtraException>()),
      );
    });

    test('F05-AC26, F05-R34: lưu xong thì khóa — không thêm lại, không sửa; '
        'thứ tự nhóm cơ theo bộ chọn', () {
      final added = ExtraSessionRules.add(sat, const [
        MuscleGroup.back,
        MuscleGroup.chest,
      ], now: satNoon);
      expect(added.extraMuscles, [MuscleGroup.chest, MuscleGroup.back]);
      expect(added.extraLoggedAt, satNoon);
      expect(SessionLock.extra(added), isTrue);
      expect(ExtraSessionRules.canAdd(added, satNoon), isFalse);
      expect(
        () =>
            ExtraSessionRules.add(added, const [MuscleGroup.abs], now: satNoon),
        throwsA(
          isA<ExtraException>().having(
            (e) => e.error,
            'error',
            ExtraError.alreadyLogged,
          ),
        ),
      );
    });

    test('F05-R31, F05-AC27: chưa có lịch tuần → không thêm được', () {
      expect(
        ExtraSessionRules.validate(sat, null, satNoon, hasSchedule: false),
        ExtraError.noSchedule,
      );
      expect(
        ExtraSessionRules.canAdd(sat, satNoon, hasSchedule: false),
        isFalse,
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
