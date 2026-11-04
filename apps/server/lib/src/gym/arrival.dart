import 'package:api_contract/api_contract.dart';
import 'package:domain/domain.dart';
import 'package:postgres/postgres.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import '../auth/auth_middleware.dart';
import '../auth/token_service.dart';
import '../db/transaction.dart';
import '../http/json.dart';
import '../logging/logger.dart';
import '../sync/schedule_handlers.dart';
import '../sync/session_v5_handlers.dart';
import '../sync/sync_service.dart';

/// Gửi `start` thẻ khi tới phòng gym (giao cho `LiveActivityScheduler`).
typedef GymArrivalStarter =
    Future<void> Function(String userId, GymArrivalOutcome outcome);

/// `POST /v1/me/gym-arrival` (05 Bản 5 TD5-14, §6.9.4, §6.10): app báo "đã tới
/// phòng gym hôm nay" (ngày + giờ máy, không tọa độ — AP-18, TR5-04). Server:
/// mở buổi sớm (`days.opened_at`, mốc sớm hơn thắng — TD5-07, TA5-02), quyết
/// bật thẻ theo FC5-10 ([GymArrivalRules.decide]) và bật qua [starter]. Luôn
/// 204, không lộ lý do (F25-R66).
final class GymArrivalService {
  GymArrivalService({
    required Pool<void> pool,
    required Clock clock,
    required Logger logger,
  }) : _pool = pool,
       _clock = clock,
       _log = logger;

  final Pool<void> _pool;
  final Clock _clock;
  final Logger _log;

  /// Bật thẻ; null khi server không có khóa APNs (dev, CI — ED3-15): vẫn mở
  /// buổi sớm, không bật thẻ.
  GymArrivalStarter? starter;

  /// Tối đa 10 lần / ngày / tài khoản (05 Bản 5 §6.10, §6.13); vượt → 204,
  /// không xử lý.
  static const dailyLimit = 10;

  final _calls = <String, int>{};

  /// Xử lý một lần gọi của [userId] với thân [body]. Không ném lỗi nghiệp vụ.
  Future<void> arrive(String userId, Object? body) async {
    final req = _parse(body);
    if (req == null) return _report(userId, null, 'invalid');
    final key = '$userId:${req.date.toKey()}';
    final n = _calls[key] = (_calls[key] ?? 0) + 1;
    if (_calls.length > 10000) _calls.removeWhere((k, _) => k != key);
    if (n > dailyLimit) return _report(userId, req.date, 'rate_limited');

    final now = _clock.now().toUtc();
    final ctx = await _pool.execute(
      Sql.named('''
        SELECT to_char(@now::timestamptz AT TIME ZONE z.tz, 'YYYY-MM-DD"T"HH24:MI:SS'),
               EXISTS (SELECT 1 FROM weekly_templates w
                       WHERE w.user_id = @user::uuid AND NOT w.deleted),
               EXISTS (SELECT 1 FROM live_activity_tokens t
                       WHERE t.user_id = @user::uuid)
        FROM (SELECT @user::uuid AS u) x
        LEFT JOIN profiles p ON p.user_id = x.u AND NOT p.deleted
        CROSS JOIN LATERAL (
          SELECT CASE WHEN p.timezone IN (SELECT name FROM pg_timezone_names)
                      THEN p.timezone ELSE 'Asia/Ho_Chi_Minh' END AS tz) z'''),
      parameters: {'now': now, 'user': userId},
    );
    final row = ctx.single;
    final localNow = DateTime.parse(row[0]! as String);
    final today = LocalDate.fromDateTime(localNow);
    final change = await const DayHandler().read(_pool, userId, today.toKey());
    final day = change == null || change.deleted
        ? null
        : const DayCodec().decode(change.key, change.data!);
    final started = await _pool.execute(
      Sql.named('''
        SELECT 1 FROM live_activity_sessions
        WHERE user_id = @user AND date = @date::date'''),
      parameters: {'user': userId, 'date': today.toKey()},
    );
    final decision = GymArrivalRules.decide(
      GymArrivalServerState(
        date: req.date,
        localNow: localNow,
        hasToken: row[2]! as bool,
        hasSchedule: row[1]! as bool,
        paused: PauseRules.isPaused(
          today,
          await SchedulePauseHandler.pauses(_pool, userId),
        ),
        day: day,
        startedToday: started.isNotEmpty,
      ),
    );
    if (decision.openEarly) await _openEarly(userId, today, now);
    final start = starter;
    if (decision.outcome != GymArrivalOutcome.none && start != null) {
      await start(userId, decision.outcome);
    }
    _report(
      userId,
      req.date,
      decision.outcome.name,
      reason: decision.outcome == GymArrivalOutcome.none
          ? decision.reason?.name
          : start == null
          ? 'apns_disabled'
          : null,
    );
  }

  /// `days.opened_at = min(opened_at, now)` (TD5-07, TA5-02) + `server_version`
  /// mới để app khác pull về; cùng khóa tài khoản như đồng bộ (ED-03).
  Future<void> _openEarly(String userId, LocalDate date, DateTime now) =>
      inTransaction(_pool, (conn) async {
        await SyncService.lockUser(conn, userId);
        await conn.execute(
          Sql.named('''
            UPDATE days SET opened_at = @now,
                            server_version = nextval('sync_version_seq'),
                            updated_at = now()
            WHERE user_id = @user AND date = @date::date AND NOT deleted
              AND kind = 'workout' AND mark IS NULL
              AND (opened_at IS NULL OR opened_at > @now)'''),
          parameters: {'now': now, 'user': userId, 'date': date.toKey()},
        );
      });

  /// Log chỉ có user id, ngày, kết quả + mã lý do; không giờ chính xác, không
  /// tọa độ (05 Bản 5 §6.14, TAC5-10).
  void _report(
    String userId,
    LocalDate? date,
    String result, {
    String? reason,
  }) => _log.info('gym_arrival', {
    'userId': userId,
    'date': ?date?.toKey(),
    'result': result,
    'reason': ?reason,
  });

  static ({LocalDate date, LocalTime localTime})? _parse(Object? body) {
    try {
      final r = JsonReader(body);
      final date = LocalDate.tryParse(r.string('date'));
      final time = LocalTime.tryParse(r.string('localTime'));
      if (date == null || time == null) return null;
      return (date: date, localTime: time);
    } on ContractFormatException {
      return null;
    }
  }
}

/// Route `POST /v1/me/gym-arrival`: cần access token; luôn 204 (TD5-14).
void addGymArrivalRoutes(
  Router router,
  GymArrivalService service,
  TokenService tokens,
) {
  router.post(
    '/v1/me/gym-arrival',
    authenticated(tokens, (request, userId) async {
      await service.arrive(userId, await readJson(request));
      return Response(204);
    }),
  );
}
