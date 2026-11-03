import 'package:domain/domain.dart';
import 'package:domain/testing.dart';
import 'package:test/test.dart';

/// 05 Bản 5 TD5-07, TD5-08, FC5-01, FD5-01 với bộ mốc `clockV5` (IA5-08).
void main() {
  final day = ClockV5.backDay;

  group('DayLock (FC5-01, TD5-08)', () {
    test('mở đến 23:59, khóa từ 00:00 ngày sau', () {
      expect(DayLock.isOpen(ClockV5.wed, ClockV5.t2359), isTrue);
      expect(DayLock.isOpen(ClockV5.wed, ClockV5.midnight), isFalse);
      expect(DayLock.isOpen(ClockV5.wed, ClockV5.t0001), isFalse);
      expect(DayLock.endOf(ClockV5.wed), ClockV5.midnight);
      expect(
        DayLock.isOpen(ClockV5.wed, DateTime(2026, 11, 4)),
        isTrue,
        reason: 'đầu ngày',
      );
    });
  });

  group('LiftWindow (FD5-01 = A, TD5-07)', () {
    test('không tới gym: chưa mở trước 18:00, mở 18:00 → 00:00', () {
      expect(
        LiftWindow.of(day, ClockV5.gymArrival),
        LiftWindowNotOpen(ClockV5.start),
      );
      expect(
        LiftWindow.of(day, ClockV5.start),
        LiftWindowOpen(ClockV5.midnight),
      );
      expect(
        LiftWindow.of(day, ClockV5.midnight),
        const LiftWindowClosed(LiftClosedReason.ended),
      );
    });

    test('F25-E61: tới gym 17:20 → cửa sổ mở từ 17:20', () {
      final opened = day.withOpenedAt(ClockV5.gymArrival);
      expect(
        LiftWindow.of(opened, DateTime(2026, 11, 4, 17, 19)),
        LiftWindowNotOpen(ClockV5.gymArrival),
      );
      expect(
        LiftWindow.of(opened, ClockV5.gymArrival),
        LiftWindowOpen(ClockV5.midnight),
      );
      expect(
        LiftWindow.of(opened, DateTime(2026, 11, 4, 17, 25)).isOpen,
        isTrue,
      );
      expect(
        LiftWindow.of(opened, ClockV5.t0001),
        const LiftWindowClosed(LiftClosedReason.ended),
      );
    });

    test('mốc UTC của openedAt đổi sang giờ máy', () {
      final utc = ClockV5.gymArrival.toUtc();
      expect(SessionRules.opensAt(day.withOpenedAt(utc)), ClockV5.gymArrival);
    });
  });

  group('ExtraSessionRules (F05-R64)', () {
    final thu = PlanDay(date: LocalDate(2026, 11, 5), kind: DayKind.rest);

    test(
      'F05-E66: thứ 7 tập mà chủ nhật mới mở app → không thêm cho hôm qua',
      () {
        final sat = PlanDay(date: LocalDate(2026, 11, 7), kind: DayKind.rest);
        expect(
          ExtraSessionRules.validate(sat, null, DateTime(2026, 11, 8, 9)),
          ExtraError.locked,
        );
      },
    );

    test('F05-E65: lưu 20:00 Vai, 21:00 sửa thành Lưng; 00:00 khóa', () {
      final saved = ExtraSessionRules.add(thu, const [
        MuscleGroup.shoulders,
      ], now: DateTime(2026, 11, 5, 20));
      final edited = ExtraSessionRules.edit(saved, const [
        MuscleGroup.back,
      ], now: DateTime(2026, 11, 5, 21));
      expect(edited.extraMuscles, [MuscleGroup.back]);
      expect(
        ExtraSessionRules.validateEdit(edited, null, DateTime(2026, 11, 6)),
        ExtraError.locked,
      );
    });
  });
}
