import 'package:domain/domain.dart';
import 'package:test/test.dart';

void main() {
  LocalDate w(int month, int day) => LocalDate(2026, month, day);
  WeightPoint p(int month, int day, int kgX10) =>
      (week: w(month, day), kgX10: kgX10);

  // Mock S-40: 75,0 (14/09) … 72,9 (28/09), 72,5 (05/10); tuần 21/09 trống.
  final log = WeightLog([
    p(10, 5, 725),
    p(9, 14, 736),
    p(9, 28, 729),
    p(9, 7, 750),
  ]);

  test('F07-R4, F07-R7: số cân mới nhất, chênh so với lần trước và so với '
      'ban đầu; danh sách sắp theo tuần', () {
    expect(log.points.map((x) => x.week), [
      w(9, 7),
      w(9, 14),
      w(9, 28),
      w(10, 5),
    ]);
    expect(log.latest, p(10, 5, 725));
    expect(log.changeFromPrevious, -4);
    expect(log.changeFromInitial, -25);
  });

  test('F07-E1: mới có 1 số cân → không có chênh so với lần trước', () {
    final one = WeightLog([p(10, 5, 800)]);
    expect(one.changeFromPrevious, isNull);
    expect(one.changeFromInitial, 0);
  });

  group('F07-V2: chênh hơn 5 kg so với lần trước', () {
    test('F07-AC3: ghi 80 kg khi lần trước 72 kg → hỏi (chênh 8 kg)', () {
      final l = WeightLog([p(9, 28, 720)]);
      expect(l.bigChange(w(10, 5), 800), 80);
    });

    test('đúng 5 kg không hỏi; tuần đã có số thì so với số đang có (mock '
        'S-41-2: 72,5 → 78,0 chênh 5,5)', () {
      expect(log.bigChange(w(10, 12), 775), isNull);
      expect(log.bigChange(w(10, 5), 780), 55);
    });

    test('ghi tuần trống ở giữa → so với tuần gần nhất trước nó', () {
      expect(log.baseFor(w(9, 21)), p(9, 14, 736));
    });
  });

  test('F07-AC5, F07-R3: không xóa được số cân duy nhất còn lại', () {
    expect(WeightLog([p(10, 5, 800)]).canDelete(w(10, 5)), isFalse);
    expect(log.canDelete(w(10, 5)), isTrue);
    expect(log.canDelete(w(9, 21)), isFalse, reason: 'tuần chưa ghi');
  });

  test('F07-R5: chỉ thay đổi ở tuần mới nhất (hoặc mới hơn) mới đổi số cân '
      'mới nhất', () {
    expect(log.affectsLatest(w(10, 5)), isTrue);
    expect(log.affectsLatest(w(10, 12)), isTrue);
    expect(log.affectsLatest(w(9, 28)), isFalse);
    expect(log.affectsLatest(w(9, 21)), isFalse);
    expect(WeightLog(const []).affectsLatest(w(10, 5)), isTrue);
  });

  group('F07-R2, F07-AC2: tuần ghi được', () {
    final setup = w(9, 9); // thứ 4; tuần thiết lập 07/09.
    final today = w(10, 7);

    test('không ghi được cho tuần sau, cho tuần trước tuần thiết lập', () {
      expect(
        WeightLog.canLog(w(10, 12), setupDate: setup, today: today),
        isFalse,
      );
      expect(
        WeightLog.canLog(w(8, 31), setupDate: setup, today: today),
        isFalse,
      );
      expect(WeightLog.canLog(w(9, 7), setupDate: setup, today: today), isTrue);
      expect(
        WeightLog.canLog(w(10, 5), setupDate: setup, today: today),
        isTrue,
      );
    });

    test('danh sách tuần ở S-40: tuần hiện tại → tuần thiết lập', () {
      expect(WeightLog.weeks(setupDate: setup, today: today), [
        w(10, 5),
        w(9, 28),
        w(9, 21),
        w(9, 14),
        w(9, 7),
      ]);
    });
  });
}
