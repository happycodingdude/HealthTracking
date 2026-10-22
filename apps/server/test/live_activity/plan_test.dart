import 'package:api_contract/api_contract.dart';
import 'package:domain/domain.dart';
import 'package:server/src/live_activity/scheduler.dart';
import 'package:server/testing.dart';
import 'package:test/test.dart';

/// 06 Bản 3 VS40-T04, ED3-08: quyết định của job mỗi phút là hàm thuần.
/// Giờ Việt Nam (UTC+7): thứ 2 12/10 Ngực 18:00 = 11:00 UTC.
void main() {
  final monday = LocalDate(2026, 10, 12);
  final chest = PlanDay(
    date: monday,
    kind: DayKind.workout,
    time: LocalTime(18, 0),
    muscles: const [MuscleGroup.chest],
  );
  final midnight = DateTime.utc(2026, 10, 12, 17); // 00:00 13/10 giờ VN
  final startToken = randomApnsToken();
  final updateToken = randomApnsToken();

  LiveActivityAccount account(
    DateTime local, {
    PlanDay? today,
    bool hasSchedule = true,
    bool startedToday = false,
    List<OpenLiveActivity> open = const [],
    String? update,
    LocalDate? activityDate,
  }) => LiveActivityAccount(
    userId: 'u1',
    environment: ApnsEnvironment.sandbox,
    pushToStartToken: startToken,
    activityPushToken: update,
    activityDate: activityDate,
    localNow: local,
    tomorrowStart: midnight,
    hasSchedule: hasSchedule,
    today: today,
    startedToday: startedToday,
    open: open,
  );

  List<LiveActivityAction> plan(DateTime nowUtc, LiveActivityAccount a) =>
      LiveActivityPlan.plan(nowUtc, [a]);

  test(
    'TAC3-07: 17:59 không gửi; 18:00 gửi start; đã bật rồi thì không gửi lại',
    () {
      expect(
        plan(
          DateTime.utc(2026, 10, 12, 10, 59),
          account(DateTime(2026, 10, 12, 17, 59), today: chest),
        ),
        isEmpty,
      );
      final start = plan(
        DateTime.utc(2026, 10, 12, 11),
        account(DateTime(2026, 10, 12, 18), today: chest),
      );
      expect(start.single, isA<StartLiveActivity>());
      expect(start.single.date, monday);
      expect(
        plan(
          DateTime.utc(2026, 10, 12, 11, 1),
          account(
            DateTime(2026, 10, 12, 18, 1),
            today: chest,
            startedToday: true,
          ),
        ),
        isEmpty,
      );
    },
  );

  test('F25-R2, FA3-12: ngày nghỉ (kể cả sửa riêng), buổi tập thêm, đã đánh '
      'dấu, Chưa có lịch → không gửi', () {
    final at = DateTime(2026, 10, 12, 18, 30);
    final utc = DateTime.utc(2026, 10, 12, 11, 30);
    final rest = PlanDay(
      date: monday,
      kind: DayKind.rest,
      source: DaySource.override,
    ).withExtra(const [MuscleGroup.abs], loggedAt: DateTime(2026, 10, 12, 18));
    expect(plan(utc, account(at, today: rest)), isEmpty);
    for (final mark in DayMark.values) {
      expect(
        plan(utc, account(at, today: chest.withMark(mark, markedAt: at))),
        isEmpty,
        reason: mark.name,
      );
    }
    expect(plan(utc, account(at, today: chest, hasSchedule: false)), isEmpty);
    expect(plan(utc, account(at)), isEmpty, reason: 'chủ nhật / chưa có ngày');
  });

  test('TA3-01: lỗi thì thử lại tới 18:10, sau đó thôi', () {
    expect(
      plan(
        DateTime.utc(2026, 10, 12, 11, 10),
        account(DateTime(2026, 10, 12, 18, 10), today: chest),
      ),
      hasLength(1),
    );
    expect(
      plan(
        DateTime.utc(2026, 10, 12, 11, 11),
        account(DateTime(2026, 10, 12, 18, 11), today: chest),
      ),
      isEmpty,
    );
  });

  test('F25-R9: sửa riêng giờ tập hôm nay → bật theo giờ mới', () {
    final moved = PlanDay(
      date: monday,
      kind: DayKind.workout,
      time: LocalTime(19, 30),
      muscles: const [MuscleGroup.chest],
      source: DaySource.override,
    );
    expect(
      plan(
        DateTime.utc(2026, 10, 12, 11),
        account(DateTime(2026, 10, 12, 18), today: moved),
      ),
      isEmpty,
    );
    expect(
      plan(
        DateTime.utc(2026, 10, 12, 12, 30),
        account(DateTime(2026, 10, 12, 19, 30), today: moved),
      ),
      hasLength(1),
    );
  });

  test('F25-E6, FA3-11: 00:00 gửi end tới token cập nhật của đúng ngày; '
      'token của ngày khác → không có token', () {
    final open = [(date: monday, endsAt: midnight)];
    expect(
      plan(
        DateTime.utc(2026, 10, 12, 16, 59),
        account(
          DateTime(2026, 10, 12, 23, 59),
          open: open,
          update: updateToken,
          activityDate: monday,
        ),
      ),
      isEmpty,
    );
    final end =
        plan(
              midnight,
              account(
                DateTime(2026, 10, 13),
                open: open,
                update: updateToken,
                activityDate: monday,
              ),
            ).single
            as EndLiveActivity;
    expect((end.date, end.token, end.giveUp), (monday, updateToken, false));
    final stale =
        plan(
              midnight,
              account(
                DateTime(2026, 10, 13),
                open: open,
                update: updateToken,
                activityDate: LocalDate(2026, 10, 9),
              ),
            ).single
            as EndLiveActivity;
    expect(stale.token, isNull);
    final late =
        plan(
              midnight.add(const Duration(minutes: 10)),
              account(DateTime(2026, 10, 13, 0, 10), open: open),
            ).single
            as EndLiveActivity;
    expect(late.giveUp, isTrue);
  });
}
