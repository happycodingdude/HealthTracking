import 'package:domain/domain.dart';
import 'package:test/test.dart';

/// 06 Bản 3 ED3-11, VS36-T06 (domain): mỗi dòng bảng S-63 của `04` Bản 3 có
/// ít nhất một test (F20-R42, FA3-09).
void main() {
  // Buổi Ngực 18:00 thứ 4 21/10/2026.
  final day = PlanDay(
    date: LocalDate(2026, 10, 21),
    kind: DayKind.workout,
    time: LocalTime(18, 0),
    muscles: const [MuscleGroup.chest],
  );
  LiftWindow at(int dayOfMonth, int hour, [int minute = 0]) =>
      LiftWindow.of(day, DateTime(2026, 10, dayOfMonth, hour, minute));
  final open = at(21, 18, 30);
  final beforeTime = at(21, 17, 59);
  final locked = at(22, 0, 1);
  final future = LiftWindow.of(day, DateTime(2026, 10, 20, 9));
  LiftLog log(int dayOfMonth, int start, int end) => LiftLog(
    date: LocalDate(2026, 10, dayOfMonth),
    exerciseId: 'chest-mid-machine-pec-deck',
    startKgX10: start,
    endKgX10: end,
  );
  final previous = log(17, 400, 450);
  final today = log(21, 400, 475);

  LiftRowState state(
    LiftWindow window, {
    bool logsWeight = true,
    bool active = true,
    LiftLog? sessionLog,
    LiftLog? previous,
  }) => LiftRowRules.of(
    window: window,
    logsWeight: logsWeight,
    active: active,
    sessionLog: sessionLog,
    previous: previous,
  );

  test('F20-AC41, UX-AC46: trong cửa sổ, chưa ghi, có buổi trước → '
      '"BUỔI TRƯỚC"', () {
    expect(state(open, previous: previous), LiftRowState.prev);
  });

  test('F20-AC42: đã ghi hôm nay → con số đậm; F20-E42: xóa bản ghi hôm nay '
      '→ quay về buổi trước', () {
    expect(
      state(open, sessionLog: today, previous: previous),
      LiftRowState.today,
    );
    expect(state(open, previous: previous), LiftRowState.prev);
  });

  test('F20-AC43: chưa từng ghi → trong cửa sổ nút "Ghi", ngoài cửa sổ '
      '"Chưa ghi"', () {
    expect(state(open), LiftRowState.none);
    expect(state(beforeTime), LiftRowState.none);
  });

  test('FA3-09: hôm nay chưa đến giờ / buổi tương lai → "GẦN NHẤT"', () {
    expect(state(beforeTime, previous: previous), LiftRowState.latest);
    expect(state(future, previous: previous), LiftRowState.latest);
  });

  test('F20-AC46: buổi đã qua → con số của buổi đó, không "buổi trước"; không '
      'có bản ghi → trống', () {
    expect(
      state(locked, sessionLog: today, previous: previous),
      LiftRowState.past,
    );
    expect(state(locked, previous: previous), LiftRowState.none);
  });

  test('UA3-08: bài bụng trong cửa sổ → "Ghi chú"; ngoài cửa sổ → trống', () {
    expect(state(open, logsWeight: false), LiftRowState.absNote);
    expect(state(beforeTime, logsWeight: false), LiftRowState.absNone);
    expect(state(locked, logsWeight: false), LiftRowState.absNone);
  });

  test('UA2-18: bài gỡ sau ra mắt có bản ghi trong buổi → con số + "Không '
      'còn trong thư viện"', () {
    expect(state(open, active: false, sessionLog: today), LiftRowState.removed);
    expect(
      state(locked, active: false, sessionLog: today),
      LiftRowState.removed,
    );
  });

  test('F20-E44: buổi tập thêm hôm nay → như buổi theo lịch từ lúc lưu', () {
    final extra = PlanDay(date: LocalDate(2026, 10, 21), kind: DayKind.rest)
        .withExtra(const [
          MuscleGroup.chest,
        ], loggedAt: DateTime(2026, 10, 21, 10));
    final window = LiftWindow.of(extra, DateTime(2026, 10, 21, 10, 5));
    expect(state(window, previous: previous), LiftRowState.prev);
  });

  test('F20-R43, F20-AC44: biểu tượng ghi chú mờ khi chỉ buổi trước có, rõ '
      'khi buổi này có', () {
    final note = ExerciseNote(
      date: LocalDate(2026, 10, 17),
      exerciseId: 'x',
      text: 'máy 2 hỏng',
    );
    expect(LiftRowRules.noteMark(), NoteMark.none);
    expect(LiftRowRules.noteMark(previousNote: note), NoteMark.previous);
    expect(
      LiftRowRules.noteMark(sessionNote: note, previousNote: note),
      NoteMark.today,
    );
  });
}
