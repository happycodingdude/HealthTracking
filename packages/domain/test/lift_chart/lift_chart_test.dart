import 'package:domain/domain.dart';
import 'package:test/test.dart';

/// 06 Bản 2 VS28-T06 (domain): F22-AC1 → AC3, F22-E1, E2, E4, F23-AC1, AC2,
/// F23-E1, E2, F23-AC5.
void main() {
  Exercise ex(
    MuscleRegion region,
    Equipment equipment, {
    int order = 0,
    bool active = true,
  }) => Exercise(
    id: '${region.id}-${equipment.wire}',
    region: region,
    equipment: equipment,
    nameVi: 'Bài',
    youtubeVideoId: 'abcdefghijk',
    videoChannel: 'Kênh',
    guideSteps: const ['a', 'b', 'c'],
    guideSafety: const ['a', 'b'],
    approvedAt: LocalDate(2026, 10, 11),
    sortOrder: order,
    active: active,
  );

  final press = ex(MuscleRegion.chestUpper, Equipment.freeWeight, order: 2);
  final machine = ex(MuscleRegion.chestUpper, Equipment.machine, order: 1);
  final lats = ex(MuscleRegion.lats, Equipment.machine, order: 7);
  final row = ex(MuscleRegion.backMid, Equipment.freeWeight, order: 9);
  final shoulder = ex(MuscleRegion.deltFront, Equipment.machine, order: 13);
  final plank = ex(MuscleRegion.absMid, Equipment.bodyweight, order: 28);
  final library = [press, machine, lats, row, shoulder, plank];

  LiftLog log(Exercise e, int month, int day, int start, int end) => LiftLog(
    date: LocalDate(2026, month, day),
    exerciseId: e.id,
    startKgX10: start,
    endKgX10: end,
  );

  group('MonthlyLiftChart (F-22)', () {
    final logs = [
      log(press, 10, 9, 120, 120),
      log(press, 10, 2, 100, 120),
      log(press, 10, 5, 120, 140),
      log(press, 10, 7, 100, 120),
      log(press, 9, 28, 90, 110),
      log(machine, 10, 5, 300, 350),
    ];

    test('F22-AC1: 4 bản ghi tháng 10 → 4 điểm mỗi chuỗi đúng ngày, đúng kg, '
        'chỉ của bài đó, cũ → mới', () {
      final chart = MonthlyLiftChart.of(logs, press.id, YearMonth(2026, 10));
      expect([for (final l in chart.logs) l.date.day], [2, 5, 7, 9]);
      expect([for (final l in chart.logs) l.endKgX10], [120, 140, 120, 120]);
      expect(chart.range, (100, 140));
      expect(chart.isEmpty, isFalse);
    });

    test('F22-R9: chỉ nối hai ngày liền nhau; ngày trống ngắt đường', () {
      final chart = MonthlyLiftChart.of(
        [
          log(press, 10, 5, 100, 120),
          log(press, 10, 6, 100, 120),
          log(press, 10, 9, 100, 120),
        ],
        press.id,
        YearMonth(2026, 10),
      );
      expect(
        [
          for (final s in chart.segments) [for (final l in s) l.date.day],
        ],
        [
          [5, 6],
          [9],
        ],
      );
    });

    test('F22-AC2, F22-AC3: tháng sớm nhất là tháng có bản ghi đầu tiên; '
        'ngày 02/11 chỉ 1 điểm của tháng 11 (F22-E2)', () {
      final all = [...logs, log(press, 11, 2, 120, 125)];
      expect(MonthlyLiftChart.earliestMonth(all, press.id), YearMonth(2026, 9));
      expect(MonthlyLiftChart.earliestMonth(all, plank.id), isNull);
      final nov = MonthlyLiftChart.of(all, press.id, YearMonth(2026, 11));
      expect(nov.logs, hasLength(1));
      expect(nov.segments, hasLength(1));
    });

    test('F22-E1: tháng giữa không có bản ghi → trống', () {
      final empty = MonthlyLiftChart.of(
        [log(press, 7, 3, 80, 90), ...logs],
        press.id,
        YearMonth(2026, 8),
      );
      expect(empty.isEmpty, isTrue);
      expect(empty.range, isNull);
    });
  });

  group('ProgressList (F-23)', () {
    test(
      'F23-AC1, F23-AC2, F23-R2: 3 bài hôm nay ở trên (thứ tự thư viện), 2 '
      'bài tuần trước sau; mỗi dòng là bản ghi gần nhất; không có bài bụng',
      () {
        final items = ProgressList.of([
          log(lats, 10, 5, 400, 450),
          log(row, 10, 7, 160, 180),
          log(press, 10, 5, 100, 120),
          log(press, 10, 12, 120, 140),
          log(shoulder, 10, 12, 250, 300),
          log(machine, 10, 12, 300, 350),
          log(plank, 10, 12, 0, 0),
        ], library);
        expect(
          [for (final i in items) i.exercise.id],
          [machine.id, press.id, shoulder.id, row.id, lats.id],
        );
        expect(items[1].latest.endKgX10, 140);
      },
    );

    test('F23-R5: bài đã rời thư viện vẫn có; F23-E2: xóa bản ghi duy nhất '
        '→ bài biến mất; F23-AC5: chưa có bản ghi → trống', () {
      final gone = machine.copyWith(active: false);
      expect(
        [
          for (final i in ProgressList.of(
            [log(machine, 10, 5, 300, 350)],
            [gone],
          ))
            i.exercise.active,
        ],
        [false],
      );
      expect(ProgressList.of(const [], library), isEmpty);
    });
  });
}
