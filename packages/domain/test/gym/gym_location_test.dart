import 'package:domain/domain.dart';
import 'package:domain/testing.dart';
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

  group('GymArrivalRules.decide (VS59-T01, FC5-10, §6.9.4, TAC5-06)', () {
    final wed = ClockV5.backDay;
    final sat = PlanDay(date: LocalDate(2026, 11, 7), kind: DayKind.rest);
    final sun = PlanDay(date: LocalDate(2026, 11, 8), kind: DayKind.rest);
    GymArrivalDecision decide(
      PlanDay? day,
      DateTime now, {
      LocalDate? date,
      bool token = true,
      bool schedule = true,
      bool paused = false,
      bool started = false,
    }) => GymArrivalRules.decide(
      GymArrivalServerState(
        date: date ?? LocalDate.fromDateTime(now),
        localNow: now,
        hasToken: token,
        hasSchedule: schedule,
        paused: paused,
        day: day,
        startedToday: started,
      ),
    );

    test('F25-AC61, F25-E61: ngày Lưng 18:00, tới gym 17:20 → thẻ buổi tập, '
        'mở buổi sớm; lần hai (đã bật) → không', () {
      expect(
        decide(wed, ClockV5.gymArrival),
        const GymArrivalDecision(GymArrivalOutcome.session, openEarly: true),
      );
      expect(
        decide(wed, DateTime(2026, 11, 4, 17, 30), started: true),
        const GymArrivalDecision.none(
          GymArrivalReason.alreadyStarted,
          openEarly: true,
        ),
      );
    });

    test('F25-E61: sau giờ tập, thẻ theo giờ đã hiện → không hiện thêm; chưa '
        'hiện (không có dòng) → bật, không mở sớm', () {
      expect(
        decide(wed, ClockV5.t1900, started: true),
        const GymArrivalDecision.none(GymArrivalReason.alreadyStarted),
      );
      expect(
        decide(wed, ClockV5.t1900),
        const GymArrivalDecision(GymArrivalOutcome.session),
      );
    });

    test('F25-AC63: thứ 7 nghỉ → thẻ ngày nghỉ; đã có Buổi tập thêm → không; '
        'F25-E62: Chủ nhật → không', () {
      final at = DateTime(2026, 11, 7, 17);
      expect(
        decide(sat, at),
        const GymArrivalDecision(GymArrivalOutcome.extra),
      );
      expect(
        decide(sat.withExtra(const [MuscleGroup.shoulders], loggedAt: at), at),
        const GymArrivalDecision.none(GymArrivalReason.extraLogged),
      );
      expect(
        decide(sat, at, started: true),
        const GymArrivalDecision.none(GymArrivalReason.alreadyStarted),
      );
      expect(
        decide(sun, DateTime(2026, 11, 8, 17)),
        const GymArrivalDecision.none(GymArrivalReason.sunday),
      );
    });

    test('F25-AC64, A5-07: tạm dừng → không thẻ (vẫn mở buổi sớm); đã đánh '
        'dấu, chưa có lịch, không token, ngày lệch → không', () {
      expect(
        decide(wed, ClockV5.gymArrival, paused: true),
        const GymArrivalDecision.none(GymArrivalReason.paused, openEarly: true),
      );
      expect(
        decide(
          wed.withMark(DayMark.done, markedAt: ClockV5.gymArrival),
          ClockV5.gymArrival,
        ).outcome,
        GymArrivalOutcome.none,
      );
      expect(
        decide(wed, ClockV5.gymArrival, schedule: false).reason,
        GymArrivalReason.noSchedule,
      );
      expect(
        decide(wed, ClockV5.gymArrival, token: false),
        const GymArrivalDecision.none(
          GymArrivalReason.noToken,
          openEarly: true,
        ),
      );
      expect(
        decide(wed, ClockV5.gymArrival, date: LocalDate(2026, 11, 3)),
        const GymArrivalDecision.none(GymArrivalReason.notToday),
      );
      expect(decide(null, ClockV5.gymArrival).reason, GymArrivalReason.noDay);
    });

    test('opensEarly (FD5-01): chỉ ngày có buổi, chưa đánh dấu, trước giờ '
        'tập, đúng ngày', () {
      expect(GymArrivalRules.opensEarly(wed, ClockV5.gymArrival), isTrue);
      expect(GymArrivalRules.opensEarly(wed, ClockV5.start), isFalse);
      expect(
        GymArrivalRules.opensEarly(wed, DateTime(2026, 11, 3, 17)),
        isFalse,
      );
      expect(
        GymArrivalRules.opensEarly(sat, DateTime(2026, 11, 7, 9)),
        isFalse,
      );
      expect(
        GymArrivalRules.opensEarly(
          wed.withMark(DayMark.skipped, markedAt: ClockV5.gymArrival),
          ClockV5.gymArrival,
        ),
        isFalse,
      );
      expect(GymArrivalRules.opensEarly(null, ClockV5.gymArrival), isFalse);
    });

    test('F25-E61, TAC5-04: openedAt 17:20 → cửa sổ ghi tạ và "Đã tập" mở '
        'từ 17:20', () {
      final opened = wed.withOpenedAt(ClockV5.gymArrival);
      final at1725 = DateTime(2026, 11, 4, 17, 25);
      expect(LiftWindow.of(opened, at1725).isOpen, isTrue);
      expect(LiftWindow.of(wed, at1725).isOpen, isFalse);
      expect(SessionRules.canMarkDone(opened, at1725), isTrue);
      expect(SessionRules.canMarkDone(wed, at1725), isFalse);
    });
  });
}
