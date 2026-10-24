import 'package:domain/domain.dart';
import 'package:test/test.dart';

/// 06 Bản 2 VS28-T06 (domain): F22-AC1 → AC3, F22-E1, E2, E4, F23-AC1, AC2,
/// F23-E1, E2, F23-AC5.
void main() {
  Exercise ex(
    MuscleRegion region,
    String kind, {
    int order = 0,
    bool active = true,
  }) => Exercise(
    id: '${region.id}-$kind',
    region: region,
    nameVi: 'Bài',
    youtubeVideoId: 'abcdefghijk',
    videoChannel: 'Kênh',
    guideSteps: const ['a', 'b', 'c'],
    guideSafety: const ['a', 'b'],
    approvedAt: LocalDate(2026, 10, 11),
    sortOrder: order,
    active: active,
  );

  final press = ex(MuscleRegion.chestUpper, 'free-weight', order: 2);
  final machine = ex(MuscleRegion.chestUpper, 'machine', order: 1);
  final lats = ex(MuscleRegion.lats, 'machine', order: 7);
  final row = ex(MuscleRegion.backMid, 'free-weight', order: 9);
  final shoulder = ex(MuscleRegion.deltFront, 'machine', order: 13);
  final plank = ex(MuscleRegion.absMid, 'bodyweight', order: 28);
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

    test('F22-R9 (sửa 24/10/2026, mock S-69-1): nối các buổi trong tháng, '
        'kể cả khi giữa hai buổi có ngày không tập', () {
      final chart = MonthlyLiftChart.of(
        [
          log(press, 10, 5, 100, 120),
          log(press, 10, 6, 100, 120),
          log(press, 10, 9, 100, 120),
          log(press, 10, 16, 100, 120),
        ],
        press.id,
        YearMonth(2026, 10),
      );
      List<List<int>> days(List<List<LiftLog>> segments) => [
        for (final s in segments) [for (final l in s) l.date.day],
      ];
      expect(days(chart.segments()), [
        [5, 6, 9, 16],
      ]);
      // UA3-13: không nối qua mốc đổi đơn vị.
      expect(days(chart.segments(unitChangeOn: LocalDate(2026, 10, 9))), [
        [5, 6],
        [9, 16],
      ]);
      expect(days(chart.segments(unitChangeOn: LocalDate(2026, 10, 1))), [
        [5, 6, 9, 16],
      ]);
      expect(days(chart.segments(unitChangeOn: LocalDate(2026, 10, 20))), [
        [5, 6, 9, 16],
      ]);
    });

    test('F22-AC2, F22-AC3: tháng sớm nhất là tháng có bản ghi đầu tiên; '
        'ngày 02/11 chỉ 1 điểm của tháng 11 (F22-E2)', () {
      final all = [...logs, log(press, 11, 2, 120, 125)];
      expect(MonthlyLiftChart.earliestMonth(all, press.id), YearMonth(2026, 9));
      expect(MonthlyLiftChart.earliestMonth(all, plank.id), isNull);
      final nov = MonthlyLiftChart.of(all, press.id, YearMonth(2026, 11));
      expect(nov.logs, hasLength(1));
      expect(nov.segments(), hasLength(1));
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

  group('Bản 3: đơn vị trên biểu đồ, Tiến bộ (06 Bản 3 VS37-T05)', () {
    ExerciseUnit unit(Exercise e, LiftUnit u, int month, int day) =>
        ExerciseUnit(
          exerciseId: e.id,
          unit: u,
          changedOn: LocalDate(2026, month, day),
        );

    test('F22-AC42: 3 điểm kg rồi đổi sang nấc 26/10 → 3 điểm giữ nguyên số, '
        'mốc "Đổi sang nấc" đúng ngày', () {
      final logs = [
        log(machine, 10, 10, 400, 450),
        log(machine, 10, 17, 420, 470),
        log(machine, 10, 24, 450, 500),
      ];
      final chart = MonthlyLiftChart.of(logs, machine.id, YearMonth(2026, 10));
      expect([for (final l in chart.logs) l.endKgX10], [450, 470, 500]);
      expect(
        MonthlyLiftChart.unitChange(
          logs,
          unit(machine, LiftUnit.steps, 10, 26),
        ),
        (on: LocalDate(2026, 10, 26), to: LiftUnit.steps),
      );
    });

    test('đơn vị gắn ở lần ghi đầu không có mốc; F22-E41: đổi hai lần → chỉ '
        'mốc của lần gần nhất', () {
      final first = [log(machine, 10, 12, 80, 100)];
      expect(
        MonthlyLiftChart.unitChange(
          first,
          unit(machine, LiftUnit.steps, 10, 12),
        ),
        isNull,
      );
      expect(MonthlyLiftChart.unitChange(first, null), isNull);
      final logs = [
        log(machine, 10, 12, 80, 100),
        log(machine, 10, 19, 400, 450),
        log(machine, 10, 26, 90, 100),
      ];
      expect(
        MonthlyLiftChart.unitChange(
          logs,
          unit(machine, LiftUnit.steps, 10, 26),
        ),
        (on: LocalDate(2026, 10, 26), to: LiftUnit.steps),
      );
    });

    test('F23-AC42: cùng ngày ghi "Ngồi máy đẩy vai" và "Máy ép ngực" → bài '
        'ngực đứng trước (thứ tự thư viện Bản 3)', () {
      final items = ProgressList.of([
        log(shoulder, 10, 12, 300, 350),
        log(machine, 10, 12, 400, 450),
      ], library);
      expect([for (final i in items) i.exercise.id], [machine.id, shoulder.id]);
    });
  });
}
