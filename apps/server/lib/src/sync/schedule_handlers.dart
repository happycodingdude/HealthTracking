import 'package:api_contract/api_contract.dart';
import 'package:domain/domain.dart';
import 'package:postgres/postgres.dart';

import 'sync_entity_handler.dart';

ApiError _invalid(String field) =>
    ApiError(ErrorCode.validationFailed, field: field);

String _field(ContractFormatException e) => e.field.replaceFirst('data.', '');

RowState? _rowState(Result rows) => rows.isEmpty
    ? null
    : RowState(
        clientUpdatedAt: rows.first[0]! as DateTime,
        deleted: rows.first[1]! as bool,
      );

/// Giờ trên iPhone (theo múi giờ IANA trong hồ sơ, VS-05) ở thời điểm [at].
/// null khi hồ sơ chưa có múi giờ hoặc PostgreSQL không biết múi giờ đó.
Future<DateTime?> deviceNow(Session s, String userId, DateTime at) async {
  final rows = await s.execute(
    Sql.named('''
      SELECT to_char(@at::timestamptz AT TIME ZONE p.timezone, 'YYYY-MM-DD HH24:MI:SS.MS')
      FROM profiles p
      WHERE p.user_id = @user AND NOT p.deleted
        AND p.timezone IN (SELECT name FROM pg_timezone_names)'''),
    parameters: {'user': userId, 'at': at},
  );
  return rows.isEmpty ? null : DateTime.parse(rows.first[0]! as String);
}

/// Thời điểm ISO 8601 UTC, độ chính xác mili giây (05 §6.8.1).
String _instant(String column) =>
    '''to_char($column AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"')''';

/// Entity `weekly_template` (key `me`) = bảng `weekly_templates` (VS04-T06).
/// Kiểm tra lại bằng domain: F03-V1 → V3, không có chủ nhật, `contentHash`.
///
/// Bản 2 (05 Bản 2 §6.6.5, VS20-T07): lần lưu lịch tuần đầu tiên của tài khoản
/// đã hoàn tất thiết lập ("Để sau" lịch tuần) mà hồ sơ chưa có
/// `schedule_started_on` → server tự ghi ngày lưu theo múi giờ trong hồ sơ.
/// Dự phòng cho máy không gửi trường này (app Bản 1 theo TD2-04).
final class WeeklyTemplateHandler implements SyncEntityHandler {
  const WeeklyTemplateHandler();

  static const _codec = WeeklyTemplateCodec();

  @override
  String get entity => SyncEntities.weeklyTemplate;

  @override
  Set<SyncOp> get ops => const {SyncOp.upsert};

  @override
  ApiError? validate(SyncMutation m, SyncContext ctx) {
    if (m.key != WeeklyTemplateCodec.key) return _invalid('key');
    final data = m.data;
    if (data == null) return _invalid('data');
    final WeeklyTemplate template;
    try {
      template = _codec.decode(data);
    } on ContractFormatException catch (e) {
      return _invalid(_field(e));
    }
    return template.validate().isEmpty ? null : _invalid('days');
  }

  @override
  Future<RowState?> lock(
    Session s,
    String userId,
    String key,
  ) async => _rowState(
    await s.execute(
      Sql.named(
        'SELECT client_updated_at, deleted FROM weekly_templates WHERE user_id = @user FOR UPDATE',
      ),
      parameters: {'user': userId},
    ),
  );

  @override
  Future<void> apply(
    Session s,
    SyncContext ctx,
    SyncMutation m,
    int serverVersion,
  ) async {
    final userId = ctx.userId;
    final t = _codec.decode(m.data!);
    final rows = await s.execute(
      Sql.named('''
        INSERT INTO weekly_templates (user_id, days, content_hash, server_version, client_updated_at)
        VALUES (@user, @days:jsonb, @hash, @version, @clientUpdatedAt)
        ON CONFLICT (user_id) DO UPDATE SET
          days = EXCLUDED.days,
          content_hash = EXCLUDED.content_hash,
          server_version = EXCLUDED.server_version,
          client_updated_at = EXCLUDED.client_updated_at,
          updated_at = now(),
          deleted = false
        RETURNING (xmax = 0) AS inserted'''),
      parameters: {
        'user': userId,
        'days': t.toJson(),
        'hash': t.contentHash,
        'version': serverVersion,
        'clientUpdatedAt': m.clientUpdatedAt,
      },
    );
    if (rows.single[0] == true) {
      await s.execute(
        Sql.named('''
          UPDATE profiles p SET
            schedule_started_on = (@at::timestamptz AT TIME ZONE
              CASE WHEN p.timezone IN (SELECT name FROM pg_timezone_names)
                   THEN p.timezone ELSE 'Asia/Ho_Chi_Minh' END)::date,
            server_version = nextval('sync_version_seq'),
            updated_at = now()
          WHERE p.user_id = @user AND NOT p.deleted
            AND p.onboarding_completed_at IS NOT NULL
            AND p.schedule_started_on IS NULL'''),
        parameters: {'user': userId, 'at': m.clientUpdatedAt},
      );
    }
  }

  @override
  Future<SyncChange?> read(Session s, String userId, String key) async {
    final rows = await s.execute(
      Sql.named('SELECT * FROM ($pullSql) c'),
      parameters: {'user': userId, 'cursor': 0},
    );
    return rows.isEmpty ? null : changeFromRow(rows.first);
  }

  @override
  String get pullSql => '''
    SELECT 'weekly_template'::text AS entity, 'me'::text AS key, deleted, server_version,
           jsonb_build_object('days', days, 'contentHash', content_hash) AS data
    FROM weekly_templates
    WHERE user_id = @user AND server_version > @cursor''';
}

/// Entity `month_plan` (key `YYYY-MM`) = bảng `month_plans`. `ensure` khi
/// chia tháng; `upsert` khi lưu lại lịch tuần lúc đang thiết lập (VS-04) và
/// khi chia lại (VS-09).
final class MonthPlanHandler implements SyncEntityHandler {
  const MonthPlanHandler();

  static const _codec = MonthPlanCodec();
  static final _hash = RegExp(r'^[0-9a-f]{64}$');

  @override
  String get entity => SyncEntities.monthPlan;

  @override
  Set<SyncOp> get ops => const {SyncOp.ensure, SyncOp.upsert};

  @override
  ApiError? validate(SyncMutation m, SyncContext ctx) {
    final data = m.data;
    if (data == null) return _invalid('data');
    final MonthPlan plan;
    try {
      plan = _codec.decode(m.key, data);
    } on ContractFormatException catch (e) {
      return _invalid(_field(e));
    }
    if (!plan.month.contains(plan.startDate)) return _invalid('startDate');
    if (!_hash.hasMatch(plan.templateHash)) return _invalid('templateHash');
    return null;
  }

  @override
  Future<RowState?> lock(
    Session s,
    String userId,
    String key,
  ) async => _rowState(
    await s.execute(
      Sql.named(
        'SELECT client_updated_at, deleted FROM month_plans WHERE user_id = @user AND month = @month FOR UPDATE',
      ),
      parameters: {'user': userId, 'month': key},
    ),
  );

  @override
  Future<void> apply(
    Session s,
    SyncContext ctx,
    SyncMutation m,
    int serverVersion,
  ) async {
    final userId = ctx.userId;
    final p = _codec.decode(m.key, m.data!);
    await s.execute(
      Sql.named('''
        INSERT INTO month_plans (user_id, month, start_date, template_hash, generated_at,
                                 redistributed_at, server_version, client_updated_at)
        VALUES (@user, @month, @start::date, @hash, @generatedAt, @redistributedAt,
                @version, @clientUpdatedAt)
        ON CONFLICT (user_id, month) DO UPDATE SET
          start_date = EXCLUDED.start_date,
          template_hash = EXCLUDED.template_hash,
          generated_at = EXCLUDED.generated_at,
          redistributed_at = EXCLUDED.redistributed_at,
          server_version = EXCLUDED.server_version,
          client_updated_at = EXCLUDED.client_updated_at,
          updated_at = now(),
          deleted = false'''),
      parameters: {
        'user': userId,
        'month': m.key,
        'start': p.startDate.toKey(),
        'hash': p.templateHash,
        'generatedAt': p.generatedAt,
        'redistributedAt': p.redistributedAt,
        'version': serverVersion,
        'clientUpdatedAt': m.clientUpdatedAt,
      },
    );
  }

  @override
  Future<SyncChange?> read(Session s, String userId, String key) async {
    final rows = await s.execute(
      Sql.named('SELECT * FROM ($pullSql) c WHERE c.key = @key'),
      parameters: {'user': userId, 'cursor': 0, 'key': key},
    );
    return rows.isEmpty ? null : changeFromRow(rows.first);
  }

  @override
  String get pullSql =>
      '''
    SELECT 'month_plan'::text AS entity, month::text AS key, deleted, server_version,
           jsonb_build_object(
             'startDate', to_char(start_date, 'YYYY-MM-DD'),
             'templateHash', template_hash,
             'generatedAt', ${_instant('generated_at')},
             'redistributedAt', ${_instant('redistributed_at')}) AS data
    FROM month_plans
    WHERE user_id = @user AND server_version > @cursor''';
}

/// Entity `day` (key `YYYY-MM-DD`) = bảng `days`: kiểm tra cấu trúc, không có
/// chủ nhật, phải thuộc tháng đã có `month_plan`, quy tắc theo thời gian của
/// [DayChangeRules]. `ensure` khi chia tháng; `upsert` cho mọi thay đổi sau đó
/// (06 §6.5.1).
final class DayHandler implements SyncEntityHandler {
  const DayHandler();

  static const _codec = DayCodec();

  @override
  String get entity => SyncEntities.day;

  @override
  Set<SyncOp> get ops => const {SyncOp.ensure, SyncOp.upsert};

  @override
  ApiError? validate(SyncMutation m, SyncContext ctx) {
    final data = m.data;
    if (data == null) return _invalid('data');
    final PlanDay day;
    try {
      day = _codec.decode(m.key, data);
    } on ContractFormatException catch (e) {
      return _invalid(_field(e));
    } on FormatException {
      return _invalid('data');
    }
    final field = day.invalidField;
    return field == null ? null : _invalid(field);
  }

  @override
  Future<RowState?> lock(
    Session s,
    String userId,
    String key,
  ) async => _rowState(
    await s.execute(
      Sql.named(
        'SELECT client_updated_at, deleted FROM days WHERE user_id = @user AND date = @date::date FOR UPDATE',
      ),
      parameters: {'user': userId, 'date': key},
    ),
  );

  @override
  Future<void> apply(
    Session s,
    SyncContext ctx,
    SyncMutation m,
    int serverVersion,
  ) async {
    final userId = ctx.userId;
    final d = _codec.decode(m.key, m.data!);
    final plan = await s.execute(
      Sql.named(
        'SELECT 1 FROM month_plans WHERE user_id = @user AND month = @month AND NOT deleted',
      ),
      parameters: {'user': userId, 'month': m.key.substring(0, 7)},
    );
    if (plan.isEmpty) throw const SyncRejection('key');
    // Buổi đã chốt và quy tắc theo thời gian (đánh dấu, ...) so với bản đang
    // có, theo giờ trên iPhone lúc ghi (05 §6.6.2, 05 Bản 2 §6.6.3).
    final current = await read(s, userId, m.key);
    final before = current == null || current.deleted
        ? null
        : _codec.decode(m.key, current.data!);
    final violation = DayChangeRules.check(
      before,
      d,
      await deviceNow(s, userId, m.clientUpdatedAt),
      fromV2App: ctx.appVersion != null,
    );
    if (violation != null) {
      throw SyncRejection(
        violation.field,
        code: switch (violation.lock) {
          DayLock.session => ErrorCode.sessionLocked,
          DayLock.extra => ErrorCode.extraSessionLocked,
          null => ErrorCode.validationFailed,
        },
      );
    }
    List<String>? names(List<MuscleGroup>? g) =>
        g == null ? null : [for (final m in g) m.name];
    await s.execute(
      Sql.named('''
        INSERT INTO days (user_id, date, kind, time, muscles, source, mark, actual_muscles,
                          marked_at, extra_muscles, extra_logged_at, server_version, client_updated_at)
        VALUES (@user, @date::date, @kind::day_kind, @time::time, @muscles::muscle_group[],
                @source::day_source, @mark::day_mark, @actual::muscle_group[], @markedAt,
                @extra::muscle_group[], @extraAt, @version, @clientUpdatedAt)
        ON CONFLICT (user_id, date) DO UPDATE SET
          kind = EXCLUDED.kind,
          time = EXCLUDED.time,
          muscles = EXCLUDED.muscles,
          source = EXCLUDED.source,
          mark = EXCLUDED.mark,
          actual_muscles = EXCLUDED.actual_muscles,
          marked_at = EXCLUDED.marked_at,
          extra_muscles = EXCLUDED.extra_muscles,
          extra_logged_at = EXCLUDED.extra_logged_at,
          server_version = EXCLUDED.server_version,
          client_updated_at = EXCLUDED.client_updated_at,
          updated_at = now(),
          deleted = false'''),
      parameters: {
        'user': userId,
        'date': m.key,
        'kind': d.kind.name,
        'time': d.time?.toKey(),
        'muscles': d.isWorkout ? names(d.muscles) : null,
        'source': d.source.name,
        'mark': d.mark?.name,
        'actual': names(d.actualMuscles),
        'markedAt': d.markedAt,
        'extra': names(d.extraMuscles),
        'extraAt': d.extraLoggedAt,
        'version': serverVersion,
        'clientUpdatedAt': m.clientUpdatedAt,
      },
    );
  }

  @override
  Future<SyncChange?> read(Session s, String userId, String key) async {
    final rows = await s.execute(
      Sql.named('SELECT * FROM ($pullSql) c WHERE c.key = @key'),
      parameters: {'user': userId, 'cursor': 0, 'key': key},
    );
    return rows.isEmpty ? null : changeFromRow(rows.first);
  }

  @override
  String get pullSql =>
      '''
    SELECT 'day'::text AS entity, to_char(date, 'YYYY-MM-DD') AS key, deleted, server_version,
           jsonb_build_object(
             'kind', kind::text,
             'time', to_char(time, 'HH24:MI'),
             'muscles', to_jsonb(muscles::text[]),
             'source', source::text,
             'mark', mark::text,
             'actualMuscles', to_jsonb(actual_muscles::text[]),
             'markedAt', ${_instant('marked_at')},
             'extraMuscles', to_jsonb(extra_muscles::text[]),
             'extraLoggedAt', ${_instant('extra_logged_at')}) AS data
    FROM days
    WHERE user_id = @user AND server_version > @cursor''';
}
