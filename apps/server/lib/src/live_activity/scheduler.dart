import 'package:api_contract/api_contract.dart';
import 'package:domain/domain.dart';
import 'package:postgres/postgres.dart';

import '../alerts.dart';
import '../logging/logger.dart';
import '../sync/schedule_handlers.dart';
import '../sync/shared_handlers.dart';
import '../sync/sync_entity_handler.dart';
import 'apns.dart';

/// Thẻ đã bật, chưa gửi tắt (`live_activity_sessions`).
typedef OpenLiveActivity = ({LocalDate date, DateTime endsAt});

/// Một tài khoản có token thẻ lúc job chạy (05 Bản 3 §6.9.4), đọc sẵn từ
/// database để [LiveActivityPlan.plan] không cần database (06 Bản 3 ED3-08).
final class LiveActivityAccount {
  const LiveActivityAccount({
    required this.userId,
    required this.environment,
    required this.pushToStartToken,
    this.activityPushToken,
    this.activityDate,
    required this.localNow,
    required this.tomorrowStart,
    required this.hasSchedule,
    this.today,
    this.startedToday = false,
    this.open = const [],
  });

  final String userId;
  final ApnsEnvironment environment;
  final String pushToStartToken;

  /// Token cập nhật của thẻ ngày [activityDate] (TA3-13).
  final String? activityPushToken;
  final LocalDate? activityDate;

  /// Giờ hiện tại theo timezone của tài khoản (giờ đồng hồ, không múi giờ).
  final DateTime localNow;

  /// 00:00 ngày mai theo timezone của tài khoản (thời điểm UTC): `stale-date`.
  final DateTime tomorrowStart;
  final bool hasSchedule;

  /// Bản ghi ngày hôm nay; null khi chủ nhật / chưa có.
  final PlanDay? today;

  /// Đã có dòng `live_activity_sessions` hôm nay.
  final bool startedToday;

  /// Thẻ đã bật, chưa gửi tắt; `endsAt` = 00:00 sau ngày đó (UTC).
  final List<OpenLiveActivity> open;

  LocalDate get localToday => LocalDate.fromDateTime(localNow);
}

sealed class LiveActivityAction {
  const LiveActivityAction(this.account, this.date);

  final LiveActivityAccount account;
  final LocalDate date;
}

/// Gửi `start` cho buổi hôm nay.
final class StartLiveActivity extends LiveActivityAction {
  const StartLiveActivity(super.account, super.date, this.day);

  final PlanDay day;
}

/// Gửi `end` (hoặc ghi `no_update_token` khi không có token cập nhật).
final class EndLiveActivity extends LiveActivityAction {
  const EndLiveActivity(
    super.account,
    super.date, {
    required this.token,
    required this.giveUp,
  });

  /// Token cập nhật của thẻ ngày [date]; null = không có (TA3-13).
  final String? token;

  /// Đã quá thời gian thử lại: lần này lỗi thì vẫn ghi `end_sent_at`.
  final bool giveUp;
}

/// Quyết định của job mỗi phút (05 Bản 3 §6.9.4, TD3-12), hàm thuần.
abstract final class LiveActivityPlan {
  /// Gửi lỗi thì thử lại mỗi phút trong 10 phút (TA3-01), rồi thôi.
  static const retryWindow = Duration(minutes: 10);

  static List<LiveActivityAction> plan(
    DateTime now,
    Iterable<LiveActivityAccount> accounts,
  ) => [
    for (final a in accounts) ...[
      if (_start(a) case final day?) StartLiveActivity(a, a.localToday, day),
      for (final o in a.open)
        if (!now.isBefore(o.endsAt))
          EndLiveActivity(
            a,
            o.date,
            token: a.activityDate == o.date ? a.activityPushToken : null,
            giveUp: !now.isBefore(o.endsAt.add(retryWindow)),
          ),
    ],
  ];

  /// Buổi theo lịch hôm nay đã tới giờ, chưa đánh dấu, chưa bật thẻ (F25-R1,
  /// R2, FA3-12): không ngày nghỉ (kể cả sửa riêng thành nghỉ), không buổi
  /// tập thêm, không tài khoản Chưa có lịch.
  static PlanDay? _start(LiveActivityAccount a) {
    final day = a.today;
    if (!a.hasSchedule || a.startedToday || day == null) return null;
    if (!day.isWorkout || day.time == null || day.mark != null) return null;
    final startsAt = day.date.atTime(day.time!);
    if (a.localNow.isBefore(startsAt)) return null;
    if (a.localNow.isAfter(startsAt.add(retryWindow))) return null;
    return day;
  }
}

/// Nội dung push (05 Bản 3 §6.9.2, §6.9.3). Không tên, số điện thoại, cân
/// nặng, ghi chú (TA3-06).
abstract final class LiveActivityPayload {
  static int _seconds(DateTime t) => t.toUtc().millisecondsSinceEpoch ~/ 1000;

  static Map<String, Object?> start({
    required DateTime now,
    required LocalDate date,
    required List<MuscleGroup> groups,
    required LiveActivityContent content,
    required DateTime staleAt,
  }) {
    final title = LiveActivityContent.groupsTitle(groups);
    return {
      'aps': {
        'timestamp': _seconds(now),
        'event': 'start',
        'attributes-type': 'IronlySessionAttributes',
        'attributes': {'date': DateCodec.encode(date), 'groups': title},
        'content-state': content.toJson(),
        'stale-date': _seconds(staleAt),
        'alert': {'title': 'Buổi tập hôm nay', 'body': title},
      },
    };
  }

  static Map<String, Object?> end(DateTime now) => {
    'aps': {
      'timestamp': _seconds(now),
      'event': 'end',
      'dismissal-date': _seconds(now),
    },
  };
}

/// Job `LiveActivityScheduler` (05 Bản 3 §6.9.4): đọc tài khoản → [plan] →
/// gửi APNs → ghi `live_activity_sessions`. Log chỉ có user id, ngày, kết quả.
final class LiveActivityScheduler {
  LiveActivityScheduler({
    required Pool<void> pool,
    required Apns apns,
    required Clock clock,
    required Logger logger,
    required Alerts alerts,
  }) : _pool = pool,
       _apns = apns,
       _clock = clock,
       _log = logger,
       _alerts = alerts;

  final Pool<void> _pool;
  final Apns _apns;
  final Clock _clock;
  final Logger _log;
  final Alerts _alerts;

  /// Lỗi liên tiếp theo (tài khoản, ngày, loại push): báo Sentry ở lần thứ 3.
  final _failures = <String, int>{};

  Future<void> run() async {
    final now = _clock.now().toUtc();
    final actions = LiveActivityPlan.plan(now, await accounts(now));
    for (final action in actions) {
      switch (action) {
        case StartLiveActivity():
          await _start(now, action);
        case EndLiveActivity():
          await _end(now, action);
      }
    }
  }

  /// Tài khoản có token, kèm giờ theo timezone, ngày hôm nay, thẻ đang mở.
  Future<List<LiveActivityAccount>> accounts(DateTime now) async {
    final rows = await _pool.execute(
      Sql.named('''
        SELECT t.user_id, t.push_to_start_token, t.activity_push_token,
               to_char(t.activity_date, 'YYYY-MM-DD'), t.environment,
               to_char(@now::timestamptz AT TIME ZONE z.tz, 'YYYY-MM-DD"T"HH24:MI:SS'),
               (((@now::timestamptz AT TIME ZONE z.tz)::date + 1)::timestamp AT TIME ZONE z.tz),
               EXISTS (SELECT 1 FROM weekly_templates w
                       WHERE w.user_id = t.user_id AND NOT w.deleted),
               z.tz
        FROM live_activity_tokens t
        JOIN profiles p ON p.user_id = t.user_id AND NOT p.deleted
        CROSS JOIN LATERAL (
          SELECT CASE WHEN p.timezone IN (SELECT name FROM pg_timezone_names)
                      THEN p.timezone ELSE 'Asia/Ho_Chi_Minh' END AS tz) z'''),
      parameters: {'now': now},
    );
    final out = <LiveActivityAccount>[];
    for (final r in rows) {
      final userId = r[0]! as String;
      final localNow = DateTime.parse(r[5]! as String);
      final today = LocalDate.fromDateTime(localNow);
      final change = await const DayHandler().read(
        _pool,
        userId,
        today.toKey(),
      );
      final sessions = await _pool.execute(
        Sql.named('''
          SELECT to_char(date, 'YYYY-MM-DD'), end_sent_at IS NULL,
                 ((date + 1)::timestamp AT TIME ZONE @tz)
          FROM live_activity_sessions WHERE user_id = @user'''),
        parameters: {'user': userId, 'tz': r[8]! as String},
      );
      out.add(
        LiveActivityAccount(
          userId: userId,
          pushToStartToken: r[1]! as String,
          activityPushToken: r[2] as String?,
          activityDate: r[3] == null ? null : LocalDate.parse(r[3]! as String),
          environment: ApnsEnvironment.tryParse(r[4]! as String)!,
          localNow: localNow,
          tomorrowStart: r[6]! as DateTime,
          hasSchedule: r[7]! as bool,
          today: change == null || change.deleted
              ? null
              : const DayCodec().decode(change.key, change.data!),
          startedToday: sessions.any((s) => s[0] == today.toKey()),
          open: [
            for (final s in sessions)
              if (s[1]! as bool)
                (
                  date: LocalDate.parse(s[0]! as String),
                  endsAt: s[2]! as DateTime,
                ),
          ],
        ),
      );
    }
    return out;
  }

  /// Nội dung lúc bật thẻ: nhóm cơ, bài kế tiếp và mức buổi trước (TD3-12).
  Future<LiveActivityContent> content(String userId, PlanDay day) async {
    final library = [
      for (final r in await _pool.execute(
        Sql.named('SELECT * FROM (${const ExerciseHandler().pullSql}) c'),
        parameters: {'cursor': 0},
      ))
        if (changeFromRow(r) case final c when !c.deleted)
          const ExerciseCodec().decode(c.key, c.data!),
    ];
    LiftLog log(ResultRow r) => LiftLog(
      date: LocalDate.parse(r[0]! as String),
      exerciseId: r[1]! as String,
      startKgX10: r[2]! as int,
      endKgX10: r[3]! as int,
    );
    final params = {'user': userId, 'date': day.date.toKey()};
    final today = [
      for (final r in await _pool.execute(
        Sql.named('''
          SELECT to_char(date, 'YYYY-MM-DD'), exercise_id, start_kg_x10, end_kg_x10
          FROM lift_logs
          WHERE user_id = @user AND date = @date::date AND NOT deleted
          ORDER BY client_updated_at'''),
        parameters: params,
      ))
        log(r),
    ];
    final previous = {
      for (final r in await _pool.execute(
        Sql.named('''
          SELECT DISTINCT ON (exercise_id)
                 to_char(date, 'YYYY-MM-DD'), exercise_id, start_kg_x10, end_kg_x10
          FROM lift_logs
          WHERE user_id = @user AND date < @date::date AND NOT deleted
          ORDER BY exercise_id, date DESC'''),
        parameters: params,
      ))
        r[1]! as String: log(r),
    };
    final units = {
      for (final r in await _pool.execute(
        Sql.named('''
          SELECT exercise_id, unit, to_char(changed_on, 'YYYY-MM-DD')
          FROM exercise_units WHERE user_id = @user AND NOT deleted'''),
        parameters: {'user': userId},
      ))
        r[0]! as String: ExerciseUnit(
          exerciseId: r[0]! as String,
          unit: LiftUnit.values.firstWhere((u) => u.wire == r[1]),
          changedOn: LocalDate.parse(r[2]! as String),
        ),
    };
    return LiveActivityContent.of(
      groups: day.sessionMuscles,
      library: library,
      today: today,
      previous: previous,
      units: units,
    );
  }

  Future<void> _start(DateTime now, StartLiveActivity a) async {
    final user = a.account.userId;
    final payload = LiveActivityPayload.start(
      now: now,
      date: a.date,
      groups: a.day.sessionMuscles,
      content: await content(user, a.day),
      staleAt: a.account.tomorrowStart,
    );
    final result = await _apns.send(
      ApnsPush(
        token: a.account.pushToStartToken,
        environment: a.account.environment,
        payload: payload,
      ),
    );
    _log.info('live_activity_start', {
      'userId': user,
      'date': a.date.toKey(),
      'result': result.outcome.name,
      if (result.status != null) 'status': result.status,
    });
    switch (result.outcome) {
      case ApnsOutcome.sent:
        _failures.remove('start:$user:${a.date}');
        await _pool.execute(
          Sql.named('''
            INSERT INTO live_activity_sessions (user_id, date, started_at)
            VALUES (@user, @date::date, @now) ON CONFLICT DO NOTHING'''),
          parameters: {'user': user, 'date': a.date.toKey(), 'now': now},
        );
      case ApnsOutcome.invalidToken:
        await _deleteToken(user, result);
      case ApnsOutcome.retry || ApnsOutcome.rejected:
        // Không ghi dòng: phút sau thử lại, quá 10 phút thì thôi (§6.9.4).
        await _failed('start', user, a.date, result);
    }
  }

  Future<void> _end(DateTime now, EndLiveActivity a) async {
    final user = a.account.userId;
    Future<void> mark(String? error) => _pool.execute(
      Sql.named('''
        UPDATE live_activity_sessions SET end_sent_at = @now, last_error = @error
        WHERE user_id = @user AND date = @date::date'''),
      parameters: {
        'now': now,
        'error': error,
        'user': user,
        'date': a.date.toKey(),
      },
    );
    final token = a.token;
    if (token == null) {
      // iOS không khởi động app ở nền sau `start` → rơi về `stale-date` (TA3-02).
      await mark('no_update_token');
      _log.info('live_activity_end', {
        'userId': user,
        'date': a.date.toKey(),
        'result': 'no_update_token',
      });
      await _alerts.warning('live_activity_no_update_token', {
        'userId': user,
        'date': a.date.toKey(),
      });
      return;
    }
    final result = await _apns.send(
      ApnsPush(
        token: token,
        environment: a.account.environment,
        payload: LiveActivityPayload.end(now),
      ),
    );
    _log.info('live_activity_end', {
      'userId': user,
      'date': a.date.toKey(),
      'result': result.outcome.name,
      if (result.status != null) 'status': result.status,
    });
    switch (result.outcome) {
      case ApnsOutcome.sent:
        _failures.remove('end:$user:${a.date}');
        await mark(null);
      case ApnsOutcome.invalidToken:
        await _pool.execute(
          Sql.named('''
            UPDATE live_activity_tokens
            SET activity_push_token = NULL, activity_date = NULL
            WHERE user_id = @user'''),
          parameters: {'user': user},
        );
        await mark(result.error);
      case ApnsOutcome.retry || ApnsOutcome.rejected:
        if (a.giveUp) {
          await mark(result.error);
        } else {
          await _pool.execute(
            Sql.named('''
              UPDATE live_activity_sessions SET last_error = @error
              WHERE user_id = @user AND date = @date::date'''),
            parameters: {
              'error': result.error,
              'user': user,
              'date': a.date.toKey(),
            },
          );
        }
        await _failed('end', user, a.date, result);
    }
  }

  /// 410 / 400 BadDeviceToken với push-to-start token → xóa token (§6.9.4).
  Future<void> _deleteToken(String user, ApnsResult result) async {
    await _pool.execute(
      Sql.named('DELETE FROM live_activity_tokens WHERE user_id = @user'),
      parameters: {'user': user},
    );
    _log.info('live_activity_token_deleted', {
      'userId': user,
      'reason': result.error,
    });
  }

  Future<void> _failed(
    String event,
    String user,
    LocalDate date,
    ApnsResult result,
  ) async {
    final key = '$event:$user:$date';
    final n = _failures[key] = (_failures[key] ?? 0) + 1;
    if (n == 3) {
      await _alerts.warning('live_activity_${event}_failing', {
        'userId': user,
        'date': date.toKey(),
        'error': result.error,
      });
    }
  }
}
