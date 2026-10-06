import 'dart:convert';

import 'package:api_contract/api_contract.dart';
import 'package:domain/domain.dart';
import 'package:postgres/postgres.dart';

import '../db/transaction.dart';
import '../http/api_exception.dart';
import '../logging/logger.dart';
import '../sync/sync_service.dart';
import 'ai_config.dart';
import 'ai_provider.dart';
import 'budget_ledger.dart';
import 'prompt_builder.dart';

/// Tạo thực đơn AI (06 VS12-T07, 05 §6.9.2): kiểm tra → đặt trước chi phí
/// (transaction khóa dòng tháng) → gọi nhà cung cấp ngoài transaction →
/// quyết toán và lưu kết quả (transaction thứ hai).
final class MenuService {
  MenuService({
    required Pool<void> pool,
    required Clock clock,
    required AiProvider provider,
    required AiConfig config,
    required Logger logger,
  }) : _pool = pool,
       _clock = clock,
       _provider = provider,
       _config = config,
       _cost = CostEstimator(config),
       _log = logger;

  final Pool<void> _pool;
  final Clock _clock;
  final AiProvider _provider;
  final AiConfig _config;
  final CostEstimator _cost;
  final Logger _log;

  /// Yêu cầu đặt trước quá thời gian này coi như treo (05 §6.11).
  static const staleAfter = Duration(minutes: 10);

  static const _feature = AiDailyUsageCodec.menuFeature;

  static final _uuid = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  );

  AiProvider get provider => _provider;

  Future<GenerateMenuResponse> generate(
    String userId,
    GenerateMenuRequest req,
  ) async {
    if (!_uuid.hasMatch(req.requestId)) {
      throw ApiException(ErrorCode.validationFailed, field: 'requestId');
    }
    final step = await inTransaction(
      _pool,
      (conn) => _reserve(conn, userId, req, _clock.now().toUtc()),
    );
    final _Reserved reserved;
    switch (step) {
      case _Done(:final response):
        return response;
      case _Failed(:final code):
        throw ApiException(code);
      case final _Reserved r:
        reserved = r;
    }
    AiResult? result;
    AiProviderException? failure;
    try {
      result = await _provider.complete(reserved.request);
    } on AiProviderException catch (e) {
      failure = e;
    } catch (e, st) {
      _log.error('ai_provider_failed', error: e, stack: st);
      failure = const AiProviderException('error', billingUnknown: true);
    }
    final outcome = await inTransaction(
      _pool,
      (conn) => _settle(conn, userId, reserved, result, failure),
    );
    return switch (outcome) {
      _Done(:final response) => response,
      _Failed(:final code) => throw ApiException(code),
      _Reserved() => throw StateError('unreachable'),
    };
  }

  /// `GET /v1/ai/menus/{date}`.
  Future<MenuStatusResponse> status(String userId, LocalDate date) =>
      _pool.withConnection(
        (conn) async => MenuStatusResponse(
          date: date,
          menu: await _readMenu(conn, userId, date),
          remaining: MenuRules.remaining(await _count(conn, userId, date)),
        ),
      );

  Future<_Step> _reserve(
    Connection conn,
    String userId,
    GenerateMenuRequest req,
    DateTime now,
  ) async {
    await SyncService.lockUser(conn, userId);

    // Gửi trùng requestId → trả kết quả cũ, không tạo và không tính tiền lại.
    final prior = await conn.execute(
      Sql.named('''
        SELECT status::text, error_code, local_date FROM ai_requests
        WHERE user_id = @u AND request_id = @r::uuid'''),
      parameters: {'u': userId, 'r': req.requestId},
    );
    if (prior.isNotEmpty) {
      final row = prior.single;
      return switch (row[0]) {
        'reserved' => const _Failed(ErrorCode.generationInProgress),
        'succeeded' => _Done(
          await _response(conn, userId, _date(row[2]), warning: false),
        ),
        _ => _Failed(
          ErrorCode.fromWire(
            row[1] as String? ?? ErrorCode.aiProviderError.wire,
          ),
        ),
      };
    }

    final profile = await conn.execute(
      Sql.named(
        '''
        SELECT sex::text, birth_year, timezone FROM profiles
        WHERE user_id = @u AND NOT deleted AND onboarding_completed_at IS NOT NULL''',
      ),
      parameters: {'u': userId},
    );
    if (profile.isEmpty || profile.single[0] == null) {
      return const _Failed(ErrorCode.profileIncomplete);
    }
    final sex = ProfileWire.parse(
      ProfileWire.sex,
      profile.single[0]! as String,
      'sex',
    )!;
    final birthYear = profile.single[1]! as int;

    // Ngày Bạn bấm phải lệch không quá 1 ngày so với ngày hiện tại theo múi
    // giờ của iPhone (05 §6.9.2).
    final today = _date(
      (await conn.execute(
        Sql.named('''
          SELECT (@now::timestamptz AT TIME ZONE
                  CASE WHEN @tz::text IN (SELECT name FROM pg_timezone_names)
                       THEN @tz::text ELSE 'Asia/Ho_Chi_Minh' END)::date'''),
        parameters: {'now': now, 'tz': profile.single[2] ?? ''},
      )).single[0],
    );
    if (req.localDate.isBefore(today.addDays(-1)) ||
        req.localDate.isAfter(today.addDays(1))) {
      throw ApiException(ErrorCode.validationFailed, field: 'localDate');
    }

    // TA-13: mỗi tài khoản chỉ 1 yêu cầu đang chạy.
    final running = await conn.execute(
      Sql.named('''
        SELECT 1 FROM ai_requests
        WHERE user_id = @u AND status = 'reserved' AND created_at > @since
        LIMIT 1'''),
      parameters: {'u': userId, 'since': now.subtract(staleAfter)},
    );
    if (running.isNotEmpty) {
      return const _Failed(ErrorCode.generationInProgress);
    }
    // F08-R2: tối đa 3 lần thành công mỗi ngày.
    if (await _count(conn, userId, req.localDate) >= MenuRules.maxDaily) {
      return const _Failed(ErrorCode.menuQuotaExhausted);
    }

    final target = MenuRules.target(req.targetKcal, sex);
    final previous = await _readMenu(conn, userId, req.localDate);
    final request = PromptBuilder.menu(
      sex: sex,
      age: ProfileRules.age(birthYear, req.localDate.year),
      targetKcal: target.kcal,
      maxTokens: _config.maxTokens,
      previousDishes: previous?.payload?.dishNames ?? const [],
    );

    // F11-R3: chi phí đã dùng + đã đặt trước + ước tính vượt trần → chặn.
    final month = AiBudgetRules.monthOf(now);
    final budget = await BudgetLedger.lock(conn, month, _config.capVnd);
    if (budget.blockedAt != null) {
      return const _Failed(ErrorCode.budgetExhausted);
    }
    final estimate = _cost.estimateCenti(request);
    if (budget.usedCenti + budget.reservedCenti + estimate > budget.capCenti) {
      // Đánh dấu chặn được commit cùng transaction này (F11-R5).
      await BudgetLedger.block(conn, month, now);
      _log.warn('ai_budget_blocked', {'month': month.toKey()});
      return const _Failed(ErrorCode.budgetExhausted);
    }

    final id =
        (await conn.execute(
              Sql.named('''
                INSERT INTO ai_requests (user_id, request_id, feature, local_date, month,
                                         provider, model, status, reserved_vnd, created_at)
                VALUES (@u, @r::uuid, @f, @d::date, @m, @p, @model, 'reserved',
                        @c::numeric / 100, @now)
                RETURNING id::text'''),
              parameters: {
                'u': userId,
                'r': req.requestId,
                'f': _feature,
                'd': req.localDate.toKey(),
                'm': month.toKey(),
                'p': _provider.name,
                'model': _provider.model,
                'c': estimate,
                'now': now,
              },
            )).single[0]!
            as String;
    await BudgetLedger.reserve(conn, month, estimate);
    // Thực đơn đang có giữ nguyên (mức calo của nó cũng vậy) tới khi có thực
    // đơn mới hợp lệ.
    await conn.execute(
      Sql.named('''
        INSERT INTO menus (user_id, date, target_kcal, used_safety_floor,
                           last_attempt_status, attempt_started_at, server_version)
        VALUES (@u, @d::date, @t, @floor, 'generating', @now, nextval('sync_version_seq'))
        ON CONFLICT (user_id, date) DO UPDATE SET
          target_kcal = CASE WHEN menus.payload IS NULL OR menus.deleted
                             THEN EXCLUDED.target_kcal ELSE menus.target_kcal END,
          used_safety_floor = CASE WHEN menus.payload IS NULL OR menus.deleted
                                   THEN EXCLUDED.used_safety_floor ELSE menus.used_safety_floor END,
          last_attempt_status = 'generating',
          last_error_code = NULL,
          attempt_started_at = EXCLUDED.attempt_started_at,
          server_version = EXCLUDED.server_version,
          updated_at = now(),
          deleted = false'''),
      parameters: {
        'u': userId,
        'd': req.localDate.toKey(),
        't': target.kcal,
        'floor': target.usedSafetyFloor,
        'now': now,
      },
    );
    return _Reserved(
      id: id,
      date: req.localDate,
      month: month,
      estimateCenti: estimate,
      target: target,
      request: request,
    );
  }

  Future<_Step> _settle(
    Connection conn,
    String userId,
    _Reserved r,
    AiResult? result,
    AiProviderException? failure,
  ) async {
    await SyncService.lockUser(conn, userId);
    final now = _clock.now().toUtc();
    await BudgetLedger.lock(conn, r.month, _config.capVnd);
    final status = await conn.execute(
      Sql.named(
        'SELECT status::text FROM ai_requests WHERE id = @id::uuid FOR UPDATE',
      ),
      parameters: {'id': r.id},
    );
    if (status.single[0] != 'reserved') {
      // Job đã dọn (quá 10 phút) và đã tính trọn số đặt trước.
      return const _Failed(ErrorCode.aiProviderError);
    }

    final (input, output) = result != null
        ? (result.inputTokens, result.outputTokens)
        : (failure?.inputTokens, failure?.outputTokens);
    // Không biết nhà cung cấp đã tính tiền chưa → tính trọn số đặt trước.
    final actual =
        input == null || output == null || failure?.billingUnknown == true
        ? r.estimateCenti
        : _cost.actualCenti(input, output);
    if (actual > r.estimateCenti) {
      _log.warn('ai_cost_over_estimate', {
        'estimateCenti': r.estimateCenti,
        'actualCenti': actual,
      });
    }
    // F11-E1: lỗi vẫn tính chi phí thực tế.
    await BudgetLedger.settle(
      conn,
      r.month,
      reservedCenti: r.estimateCenti,
      actualCenti: actual,
    );

    Menu? menu;
    var code = ErrorCode.aiProviderError;
    if (result != null) {
      code = ErrorCode.aiInvalidOutput;
      try {
        final parsed = MenuPayloadCodec.decode(jsonDecode(result.text));
        if (MenuValidator.validate(parsed, r.target.kcal) == null) {
          menu = parsed;
        }
      } on FormatException {
        // F08-E4.
      } on ContractFormatException {
        // F08-E4.
      }
    }
    await conn.execute(
      Sql.named('''
        UPDATE ai_requests
        SET status = @s::ai_request_status, actual_vnd = @a::numeric / 100,
            input_tokens = @in, output_tokens = @out, error_code = @e, settled_at = @now
        WHERE id = @id::uuid'''),
      parameters: {
        'id': r.id,
        's': menu == null ? 'failed' : 'succeeded',
        'a': actual,
        'in': input,
        'out': output,
        'e': menu == null ? code.wire : null,
        'now': now,
      },
    );
    _log.info('ai_menu_settled', {
      'ok': menu != null,
      'provider': _provider.name,
      'inputTokens': input,
      'outputTokens': output,
      'actualCenti': actual,
      if (menu == null) 'error': failure?.reason ?? code.wire,
    });

    final date = r.date.toKey();
    if (menu == null) {
      // TAC-13: lỗi giữ thực đơn cũ; F08-R3: không trừ lượt.
      await conn.execute(
        Sql.named('''
          UPDATE menus SET last_attempt_status = 'failed', last_error_code = @e,
                 attempt_started_at = NULL, server_version = nextval('sync_version_seq'),
                 updated_at = now()
          WHERE user_id = @u AND date = @d::date'''),
        parameters: {'u': userId, 'd': date, 'e': code.wire},
      );
      return _Failed(code);
    }

    await conn.execute(
      Sql.named('''
        UPDATE menus SET payload = @p::jsonb, total_kcal = @total, target_kcal = @t,
               used_safety_floor = @floor, last_attempt_status = 'ready',
               last_error_code = NULL, generated_at = @now, attempt_started_at = NULL,
               server_version = nextval('sync_version_seq'), updated_at = now(),
               deleted = false
        WHERE user_id = @u AND date = @d::date'''),
      parameters: {
        'u': userId,
        'd': date,
        'p': jsonEncode(MenuPayloadCodec.encode(menu)),
        'total': menu.totalKcal,
        't': r.target.kcal,
        'floor': r.target.usedSafetyFloor,
        'now': now,
      },
    );
    // F08-R2: chỉ tăng lượt khi thành công.
    await conn.execute(
      Sql.named('''
        INSERT INTO ai_daily_usage (user_id, date, feature, success_count, server_version)
        VALUES (@u, @d::date, @f, 1, nextval('sync_version_seq'))
        ON CONFLICT (user_id, date, feature) DO UPDATE SET
          success_count = ai_daily_usage.success_count + 1,
          server_version = EXCLUDED.server_version,
          updated_at = now()'''),
      parameters: {'u': userId, 'd': date, 'f': _feature},
    );
    // F08-R5: chỉ giữ thực đơn của ngày mới nhất.
    await conn.execute(
      Sql.named('''
        UPDATE menus SET deleted = true, payload = NULL, total_kcal = NULL,
               server_version = nextval('sync_version_seq'), updated_at = now()
        WHERE user_id = @u AND date < @d::date AND NOT deleted'''),
      parameters: {'u': userId, 'd': date},
    );
    // F11-R4: báo 80% đúng một lần trong tháng.
    final after = await BudgetLedger.read(conn, r.month);
    final warning =
        after != null &&
        after.warnedAt == null &&
        AiBudgetRules.reachedWarning(after.usedCenti, after.capCenti) &&
        await BudgetLedger.warn(conn, r.month, now);
    return _Done(await _response(conn, userId, r.date, warning: warning));
  }

  Future<GenerateMenuResponse> _response(
    Session s,
    String userId,
    LocalDate date, {
    required bool warning,
  }) async => GenerateMenuResponse(
    date: date,
    menu: (await _readMenu(s, userId, date))!,
    remaining: MenuRules.remaining(await _count(s, userId, date)),
    budgetWarning80: warning,
  );

  Future<MenuData?> _readMenu(Session s, String userId, LocalDate date) async {
    final rows = await s.execute(
      Sql.named(
        '''
        SELECT data FROM (${MenuQueries.pullSql}) c WHERE key = @key AND NOT deleted''',
      ),
      parameters: {'user': userId, 'cursor': 0, 'key': date.toKey()},
    );
    if (rows.isEmpty) return null;
    return const MenuCodec().decode(
      (rows.single[0]! as Map).cast<String, Object?>(),
    );
  }

  Future<int> _count(Session s, String userId, LocalDate date) async {
    final rows = await s.execute(
      Sql.named('''
        SELECT success_count FROM ai_daily_usage
        WHERE user_id = @u AND date = @d::date AND feature = @f'''),
      parameters: {'u': userId, 'd': date.toKey(), 'f': _feature},
    );
    return rows.isEmpty ? 0 : rows.single[0]! as int;
  }

  static LocalDate _date(Object? v) => v is DateTime
      ? LocalDate(v.year, v.month, v.day)
      : LocalDate.parse(v! as String);
}

/// Truy vấn đọc entity `menu`, `ai_daily_usage` (dùng chung với handler đồng
/// bộ chỉ pull).
abstract final class MenuQueries {
  static String _instant(String column) =>
      '''to_char($column AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"')''';

  static final pullSql =
      '''
    SELECT 'menu'::text AS entity, to_char(date, 'YYYY-MM-DD') AS key, deleted, server_version,
           CASE WHEN deleted THEN NULL ELSE jsonb_build_object(
             'payload', payload,
             'targetKcal', target_kcal,
             'usedSafetyFloor', used_safety_floor,
             'totalKcal', total_kcal,
             'lastAttemptStatus', last_attempt_status::text,
             'lastErrorCode', last_error_code,
             'generatedAt', ${_instant('generated_at')}) END AS data
    FROM menus
    WHERE user_id = @user AND server_version > @cursor''';

  static const usagePullSql = '''
    SELECT 'ai_daily_usage'::text AS entity,
           to_char(date, 'YYYY-MM-DD') || ':' || feature AS key,
           false AS deleted, server_version,
           jsonb_build_object('successCount', success_count) AS data
    FROM ai_daily_usage
    WHERE user_id = @user AND server_version > @cursor''';
}

sealed class _Step {
  const _Step();
}

final class _Done extends _Step {
  const _Done(this.response);
  final GenerateMenuResponse response;
}

final class _Failed extends _Step {
  const _Failed(this.code);
  final ErrorCode code;
}

final class _Reserved extends _Step {
  const _Reserved({
    required this.id,
    required this.date,
    required this.month,
    required this.estimateCenti,
    required this.target,
    required this.request,
  });

  final String id;
  final LocalDate date;
  final YearMonth month;
  final int estimateCenti;
  final ({int kcal, bool usedSafetyFloor}) target;
  final AiRequest request;
}
