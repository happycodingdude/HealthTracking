import 'package:domain/domain.dart';
import 'package:test/test.dart';

/// F32-R1, 05 Bản 5 §6.6.2 `gym_location`.
void main() {
  final at = DateTime.utc(2026, 11, 4, 10);

  test('lat ∈ [−90, 90], lng ∈ [−180, 180]', () {
    expect(
      GymLocation(lat: 10.77, lng: 106.69, savedAt: at).invalidField,
      isNull,
    );
    expect(GymLocation(lat: 90.1, lng: 0, savedAt: at).invalidField, 'lat');
    expect(GymLocation(lat: 0, lng: -180.5, savedAt: at).invalidField, 'lng');
    expect(
      GymLocation(lat: double.nan, lng: 0, savedAt: at).invalidField,
      'lat',
    );
  });

  test('TAC5-10: toString không có tọa độ', () {
    final g = GymLocation(lat: 10.770123, lng: 106.690456, savedAt: at);
    expect(g.toString(), isNot(contains('10.77')));
    expect(g.toString(), isNot(contains('106.69')));
    expect(g.withEnabled(false).enabled, isFalse);
  });

  group('GymArrivalRules.shouldCall (VS58-T01, §6.4.2, FC5-10)', () {
    final today = LocalDate(2026, 11, 4);
    final gym = GymLocation(lat: 10.77, lng: 106.69, savedAt: at);
    final wed = PlanDay(
      date: today,
      kind: DayKind.workout,
      muscles: const [MuscleGroup.back],
      time: LocalTime(18, 0),
    );
    GymArrivalAppState state({
      GymLocation? location,
      bool noLocation = false,
      bool called = false,
      bool paused = false,
      PlanDay? day,
    }) => GymArrivalAppState(
      today: today,
      location: noLocation ? null : location ?? gym,
      alreadyCalled: called,
      paused: paused,
      day: day ?? wed,
    );

    test('lần vào vùng đầu tiên hôm nay → báo', () {
      expect(GymArrivalRules.shouldCall(today, state()), isTrue);
    });

    test('một lần / ngày: đã báo hôm nay → không (A5-09)', () {
      expect(GymArrivalRules.shouldCall(today, state(called: true)), isFalse);
    });

    test('chưa lưu vị trí / công tắc tắt → không (F32-R4, F32-AC4)', () {
      expect(
        GymArrivalRules.shouldCall(today, state(noLocation: true)),
        isFalse,
      );
      expect(
        GymArrivalRules.shouldCall(
          today,
          state(location: gym.withEnabled(false)),
        ),
        isFalse,
      );
    });

    test('sự kiện của ngày khác hôm nay → không', () {
      expect(GymArrivalRules.shouldCall(today.addDays(-1), state()), isFalse);
    });

    test('tạm dừng → không (F31-R4, A5-07)', () {
      expect(GymArrivalRules.shouldCall(today, state(paused: true)), isFalse);
    });

    test('đã "Đã tập" / "Không tập" hoặc đã có buổi tập thêm → không', () {
      final done = wed.withMark(DayMark.done, markedAt: at);
      expect(GymArrivalRules.shouldCall(today, state(day: done)), isFalse);
      final skipped = wed.withMark(DayMark.skipped, markedAt: at);
      expect(GymArrivalRules.shouldCall(today, state(day: skipped)), isFalse);
      final rest = PlanDay(
        date: today,
        kind: DayKind.rest,
      ).withExtra(const [MuscleGroup.shoulders], loggedAt: at);
      expect(GymArrivalRules.shouldCall(today, state(day: rest)), isFalse);
      expect(
        GymArrivalRules.shouldCall(
          today,
          state(
            day: PlanDay(date: today, kind: DayKind.rest),
          ),
        ),
        isTrue,
      );
    });
  });
}
