import 'package:domain/domain.dart';
import 'package:test/test.dart';

void main() {
  final t1800 = LocalTime(18, 0);

  /// F03-AC2: T2 Ngực + Tay sau 18:00, T4 Lưng 18:00, T6 Vai 18:00.
  final ac2 = WeeklyTemplate({
    1: TemplateDay(
      enabled: true,
      time: t1800,
      muscles: const [MuscleGroup.triceps, MuscleGroup.chest],
    ),
    3: TemplateDay(
      enabled: true,
      time: t1800,
      muscles: const [MuscleGroup.back],
    ),
    5: TemplateDay(
      enabled: true,
      time: t1800,
      muscles: const [MuscleGroup.shoulders],
    ),
  });

  group('lịch tuần', () {
    test('F03-AC1, F03-R1: không có chủ nhật trong lịch tuần', () {
      expect(ac2.days.keys, [1, 2, 3, 4, 5, 6]);
      expect(
        () => WeeklyTemplate({7: const TemplateDay(enabled: false)}),
        throwsArgumentError,
      );
      expect(
        () => WeeklyTemplate.fromJson({
          '7': {'enabled': false},
        }),
        throwsFormatException,
      );
    });

    test('PR-02: nhóm cơ theo thứ tự cố định, bỏ trùng', () {
      expect(
        MuscleGroup.ordered([
          MuscleGroup.biceps,
          MuscleGroup.chest,
          MuscleGroup.abs,
          MuscleGroup.chest,
        ]),
        [MuscleGroup.chest, MuscleGroup.abs, MuscleGroup.biceps],
      );
    });

    test('F03-V1 → V3: lỗi theo từng thứ, thứ tự thứ 2 → thứ 7', () {
      expect(ac2.validate(), isEmpty);
      expect(WeeklyTemplate({}).validate(), [
        (issue: TemplateIssue.noWorkoutDay, weekday: null),
      ]);
      expect(
        WeeklyTemplate({
          2: const TemplateDay(enabled: true, muscles: [MuscleGroup.abs]),
          5: TemplateDay(enabled: true, time: t1800),
        }).validate(),
        [
          (issue: TemplateIssue.missingTime, weekday: 2),
          (issue: TemplateIssue.missingMuscles, weekday: 5),
        ],
      );
    });

    test(
      'contentHash: JSON chuẩn hóa → SHA-256, không phụ thuộc thứ tự nhập',
      () {
        final same = WeeklyTemplate({
          5: TemplateDay(
            enabled: true,
            time: t1800,
            muscles: const [MuscleGroup.shoulders],
          ),
          3: TemplateDay(
            enabled: true,
            time: t1800,
            muscles: const [MuscleGroup.back],
          ),
          1: TemplateDay(
            enabled: true,
            time: t1800,
            muscles: const [MuscleGroup.chest, MuscleGroup.triceps],
          ),
          // Thứ tắt: giờ và nhóm cơ đã chọn trước đó không ảnh hưởng.
          2: TemplateDay(
            enabled: false,
            time: t1800,
            muscles: const [MuscleGroup.abs],
          ),
        });
        expect(same.contentHash, ac2.contentHash);
        expect(ac2.contentHash, hasLength(64));
        expect(
          WeeklyTemplate.fromJson(ac2.toJson()).contentHash,
          ac2.contentHash,
        );
        expect(ac2.toJson()['1'], {
          'enabled': true,
          'time': '18:00',
          'muscles': ['chest', 'triceps'],
        });
        expect(ac2.toJson()['2'], {'enabled': false});
        final changed = WeeklyTemplate({
          ...ac2.days,
          3: TemplateDay(
            enabled: true,
            time: t1800,
            muscles: const [MuscleGroup.shoulders],
          ),
        });
        expect(changed.contentHash, isNot(ac2.contentHash));
      },
    );
  });

  group('MonthGenerator', () {
    test('F03-AC2: tháng 10/2026 có buổi ở mọi T2, T4, T6; còn lại nghỉ; '
        'không có chủ nhật', () {
      final m = MonthGenerator.month(
        ac2,
        YearMonth(2026, 10),
        DateTime(2026, 10, 1),
      );
      expect(m.plan.startDate, LocalDate(2026, 10, 1));
      expect(m.plan.templateHash, ac2.contentHash);
      expect(m.days.any((d) => d.date.isSunday), isFalse);
      // Tháng 10/2026: 31 ngày, 4 chủ nhật.
      expect(m.days, hasLength(27));
      for (final d in m.days) {
        final workout = {1, 3, 5}.contains(d.date.weekday);
        expect(d.isWorkout, workout, reason: '${d.date}');
        expect(d.source, DaySource.template);
        expect(d.invalidField, isNull);
      }
      final monday = m.days.firstWhere((d) => d.date == LocalDate(2026, 10, 5));
      expect(monday.time, t1800);
      expect(monday.muscles, [MuscleGroup.chest, MuscleGroup.triceps]);
    });

    test('F03-AC3, F03-R5: thiết lập 12:00 07/10 → bắt đầu từ 07/10; buổi '
        'hôm nay chỉ có nếu giờ tập sau 12:00', () {
      final m = MonthGenerator.first(ac2, DateTime(2026, 10, 7, 12));
      expect(m.plan.startDate, LocalDate(2026, 10, 7));
      expect(m.days.first.date, LocalDate(2026, 10, 7));
      expect(m.days.first.isWorkout, isTrue, reason: '18:00 > 12:00');
      expect(m.days.last.date, LocalDate(2026, 10, 31));

      final late = MonthGenerator.first(ac2, DateTime(2026, 10, 7, 18));
      expect(late.days.first.date, LocalDate(2026, 10, 7));
      expect(late.days.first.kind, DayKind.rest, reason: '18:00 đã đến');
      expect(late.days[2].isWorkout, isTrue, reason: 'thứ 6 09/10');
    });

    test(
      'F03-E3: thiết lập giữa tuần → không có ngày nào trước lúc thiết lập',
      () {
        final m = MonthGenerator.first(ac2, DateTime(2026, 10, 8, 9));
        expect(
          m.days.every((d) => !d.date.isBefore(LocalDate(2026, 10, 8))),
          isTrue,
        );
      },
    );

    test('F03-E7: thiết lập ngày cuối tháng → chỉ có hôm nay', () {
      final m = MonthGenerator.first(ac2, DateTime(2026, 10, 31, 7));
      expect([for (final d in m.days) d.date], [LocalDate(2026, 10, 31)]);
      // Chủ nhật cuối tháng: không có ngày nào.
      expect(MonthGenerator.first(ac2, DateTime(2026, 5, 31, 7)).days, isEmpty);
    });

    test('F03-AC4, F03-R6: tháng 11 chia cả tháng theo lịch tuần hiện tại; '
        'tháng 2 năm nhuận', () {
      final nov = MonthGenerator.month(
        ac2,
        YearMonth(2026, 11),
        DateTime(2026, 11, 1),
      );
      expect(
        nov.days.first.date,
        LocalDate(2026, 11, 2),
        reason: '01/11 là CN',
      );
      expect(nov.days.last.date, LocalDate(2026, 11, 30));
      final feb = MonthGenerator.month(
        ac2,
        YearMonth(2028, 2),
        DateTime(2028, 2, 1),
      );
      expect(feb.days.last.date, LocalDate(2028, 2, 29));
    });

    test('ràng buộc bản ghi ngày (05 §6.7.3)', () {
      final d = LocalDate(2026, 10, 7);
      expect(
        PlanDay(
          date: d,
          kind: DayKind.workout,
          muscles: const [MuscleGroup.abs],
        ).invalidField,
        'time',
      );
      expect(
        PlanDay(date: d, kind: DayKind.rest, time: t1800).invalidField,
        'time',
      );
      expect(
        PlanDay(date: LocalDate(2026, 10, 11), kind: DayKind.rest).invalidField,
        'key',
      );
      expect(
        PlanDay(date: d, kind: DayKind.rest, mark: DayMark.done).invalidField,
        'mark',
      );
    });
  });
}
