// Nạp dữ liệu thử cho database dev (06 Bản 1 VS00-T13, 06 Bản 2 ED2-18,
// §6.5.2). Chạy sau khi tạo lại database bằng migration:
//
//   tool/reset_dev_db.sh            # xóa, tạo lại, rồi chạy file này
//   dart run tool/seed_dev.dart     # chỉ nạp (bỏ qua tài khoản đã có)
//
// Kết nối: DATABASE_URL của tiến trình, rồi apps/server/.env (code không chứa
// tài khoản database). CHỈ dùng cho dev: mật khẩu thử in ra màn hình.
//
// Tài khoản thử (mật khẩu chung: DEV_SEED_PASSWORD của tiến trình, rồi .env ở
// gốc repo; code không chứa mật khẩu, kể cả mật khẩu thử):
// - 0900000001 "Minh": như Bản 1 — đã xếp lịch từ 40 ngày trước (trải qua 2
//   tháng), có buổi đã đánh dấu, buổi chờ đánh dấu, vài số cân; mức tạ kiểu
//   Bản 2 của các buổi trước tuần này, tăng dần theo từng buổi, trên 3 bài
//   giữ (2 bài máy ghi số thanh, 1 bài tạ ghi kg) và 2 bài bỏ (06 Bản 3
//   VS32-T09) để thử `library purge`.
// - 0900000002 "Lan": đã hoàn tất thiết lập nhưng "Để sau" lịch tuần (chưa có
//   lịch, 03 Bản 2 §6.1), công tắc nhắc bật.
//
// Thư viện bài tập: nạp data/v2__exercises.json (29 bài Bản 2, có
// `equipment`) bằng cùng LibraryImporter của `admin library import` như
// production Bản 2 (06 Bản 2 VS21-T08).
import 'dart:io';

import 'package:domain/domain.dart';
import 'package:postgres/postgres.dart';
import 'package:server/server.dart';

final _password = _seedPassword();
const _timezone = 'Asia/Ho_Chi_Minh';
const _vnOffset = Duration(hours: 7);

/// Giờ trên iPhone (giờ Việt Nam, dạng DateTime "trôi nổi" như app dùng) →
/// thời điểm UTC để ghi vào database.
DateTime _utc(DateTime wall) => DateTime.utc(
  wall.year,
  wall.month,
  wall.day,
  wall.hour,
  wall.minute,
  wall.second,
).subtract(_vnOffset);

Future<void> main() async {
  final conn = await Connection.openFromUrl(_withSslMode(_databaseUrl()));
  try {
    // Giờ trên iPhone của Bạn (giờ Việt Nam), không phụ thuộc múi giờ của Mac.
    final now = DateTime.now().toUtc().add(_vnOffset);
    final local = DateTime(now.year, now.month, now.day, now.hour, now.minute);
    final library = await _seedLibrary(conn);
    await _seedScheduled(conn, local, library);
    await _seedNoSchedule(conn, local);
  } finally {
    await conn.close();
  }
}

String _databaseUrl() {
  final fromProcess = Platform.environment['DATABASE_URL'];
  if (fromProcess != null && fromProcess.isNotEmpty) return fromProcess;
  final env = File('apps/server/.env');
  if (env.existsSync()) {
    for (final line in env.readAsLinesSync()) {
      final l = line.trim();
      if (l.startsWith('DATABASE_URL=')) {
        return l.substring('DATABASE_URL='.length).trim();
      }
    }
  }
  throw StateError(
    'Thiếu DATABASE_URL (biến môi trường hoặc apps/server/.env, xem '
    'docs/runbook.md)',
  );
}

String _seedPassword() {
  var value = Platform.environment['DEV_SEED_PASSWORD'];
  final env = File('.env');
  if ((value == null || value.isEmpty) && env.existsSync()) {
    value = ServerConfig.parseDotEnv(
      env.readAsStringSync(),
    )['DEV_SEED_PASSWORD'];
  }
  if (value == null || !AccountValidators.isValidPassword(value)) {
    throw StateError(
      'Thiếu DEV_SEED_PASSWORD (ít nhất ${AccountValidators.passwordMin} ký tự; '
      'biến môi trường hoặc .env ở gốc repo, xem docs/runbook.md)',
    );
  }
  return value;
}

String _withSslMode(String url) {
  final uri = Uri.parse(url);
  return uri.queryParameters.containsKey('sslmode')
      ? url
      : uri
            .replace(
              queryParameters: {...uri.queryParameters, 'sslmode': 'disable'},
            )
            .toString();
}

Future<List<Exercise>> _seedLibrary(Connection c) async {
  final file = LibraryFile.parse(
    File('data/v2__exercises.json').readAsStringSync(),
  );
  final report = await LibraryImporter(c).run(file);
  stdout.writeln('Thư viện: ${report.describe()}');
  if (!report.ok) exitCode = 1;
  return LibraryRules.sorted(file.exercises);
}

/// Tạo tài khoản; null khi số đã có (bỏ qua, giữ dữ liệu cũ).
Future<String?> _user(Connection c, String phone, String name) async {
  final rows = await c.execute(
    Sql.named('''
      INSERT INTO users (phone, password_hash, display_name)
      VALUES (@phone, crypt(@password, gen_salt('bf', 10)), @name)
      ON CONFLICT (phone) DO NOTHING
      RETURNING id'''),
    parameters: {'phone': phone, 'password': _password, 'name': name},
  );
  if (rows.isEmpty) {
    stdout.writeln('Bỏ qua $phone: đã có tài khoản.');
    return null;
  }
  return rows.single[0]! as String;
}

Future<void> _profile(
  Connection c,
  String user, {
  required LocalDate setupDate,
  required DateTime completedAt,
  required bool reminders,
}) => c.execute(
  Sql.named('''
    INSERT INTO profiles (user_id, height_cm, birth_year, sex, activity_level, setup_date,
                          onboarding_step, disclaimer_accepted_at, onboarding_completed_at,
                          calorie_mode, calorie_kcal, reminders_enabled, timezone,
                          server_version, client_updated_at)
    VALUES (@user, 172, 1994, 'male', 'moderate', @setup::date, 5, @at, @at, 'auto', 2210,
            @reminders, @tz, nextval('sync_version_seq'), @at)'''),
  parameters: {
    'user': user,
    'setup': setupDate.toKey(),
    'at': _utc(completedAt),
    'reminders': reminders,
    'tz': _timezone,
  },
);

Future<void> _seedScheduled(
  Connection c,
  DateTime now,
  List<Exercise> library,
) async {
  final user = await _user(c, '0900000001', 'Minh');
  if (user == null) return;
  final setupAt = now.subtract(const Duration(days: 40));
  final template = WeeklyTemplate({
    1: TemplateDay(
      enabled: true,
      time: LocalTime(18, 0),
      muscles: const [MuscleGroup.chest, MuscleGroup.triceps],
    ),
    3: TemplateDay(
      enabled: true,
      time: LocalTime(18, 0),
      muscles: const [MuscleGroup.back, MuscleGroup.biceps],
    ),
    5: TemplateDay(
      enabled: true,
      time: LocalTime(18, 0),
      muscles: const [MuscleGroup.shoulders, MuscleGroup.abs],
    ),
  });
  await _profile(
    c,
    user,
    setupDate: LocalDate.fromDateTime(setupAt),
    completedAt: setupAt,
    reminders: true,
  );
  await c.execute(
    Sql.named('''
      INSERT INTO weekly_templates (user_id, days, content_hash, server_version, client_updated_at)
      VALUES (@user, @days:jsonb, @hash, nextval('sync_version_seq'), @at)'''),
    parameters: {
      'user': user,
      'days': template.toJson(),
      'hash': template.contentHash,
      'at': _utc(setupAt),
    },
  );

  final today = LocalDate.fromDateTime(now);
  final months = <GeneratedMonth>[MonthGenerator.first(template, setupAt)];
  for (
    var m = months.first.plan.month.next;
    m.compareTo(today.yearMonth) <= 0;
    m = m.next
  ) {
    months.add(MonthGenerator.month(template, m, m.firstDay.startOfDay));
  }
  var workouts = 0;
  final lifted = <PlanDay>[];
  for (final month in months) {
    final p = month.plan;
    await c.execute(
      Sql.named(
        '''
        INSERT INTO month_plans (user_id, month, start_date, template_hash, generated_at,
                                 server_version, client_updated_at)
        VALUES (@user, @month, @start::date, @hash, @at, nextval('sync_version_seq'), @at)''',
      ),
      parameters: {
        'user': user,
        'month': p.month.toKey(),
        'start': p.startDate.toKey(),
        'hash': p.templateHash,
        'at': _utc(p.generatedAt),
      },
    );
    for (final d in month.days) {
      var day = d;
      // Buổi trước tuần này: phần lớn "Đã tập", cứ 4 buổi có 1 "Không tập".
      // Buổi trong tuần này đã qua giờ tập: để "Chờ đánh dấu".
      if (d.isWorkout &&
          d.date.isBefore(today) &&
          d.date.isBefore(today.weekStart)) {
        workouts++;
        final at = d.date.atTime(d.time!).add(const Duration(hours: 1));
        day = workouts % 4 == 0
            ? d.withMark(DayMark.skipped, markedAt: at)
            : d.withMark(DayMark.done, actual: d.muscles, markedAt: at);
        lifted.add(day);
      }
      await _day(c, user, day);
    }
  }

  for (var w = 1; w <= 3; w++) {
    final week = today.weekStart.addDays(-7 * w);
    if (week.isBefore(LocalDate.fromDateTime(setupAt).weekStart)) continue;
    await c.execute(
      Sql.named('''
        INSERT INTO weights (user_id, week_start, weight_kg_x10, server_version, client_updated_at)
        VALUES (@user, @week::date, @kg, nextval('sync_version_seq'), @at)'''),
      parameters: {
        'user': user,
        'week': week.toKey(),
        'kg': 735 - 5 * (3 - w),
        'at': _utc(week.atTime(LocalTime(7, 0))),
      },
    );
  }
  final logs = await _liftLogs(c, user, lifted, library);
  stdout.writeln(
    'Đã nạp 0900000001 "Minh" (có lịch từ ${LocalDate.fromDateTime(setupAt)}, '
    '$logs bản ghi mức tạ), mật khẩu $_password',
  );
}

/// Mức tạ kiểu Bản 2 (06 Bản 3 VS32-T09, D3-04) trên 3 bài giữ — 2 bài máy
/// ghi số thanh (× 10), 1 bài tạ ghi kg (× 10) — và 2 bài bỏ, kể cả buổi
/// "Không tập" (AP-9): mỗi buổi tăng một bước, kết thúc cao hơn bắt đầu một
/// bước; buổi thứ 4 của mỗi bài giảm 3 bước để có cảnh báo. Ghi lúc 1 giờ sau
/// giờ tập, trong cửa sổ ghi tạ. Bài không có trong thư viện thì bỏ qua.
Future<int> _liftLogs(
  Connection c,
  String user,
  List<PlanDay> days,
  List<Exercise> library,
) async {
  // (bài, mức bắt đầu buổi đầu × 10, bước × 10).
  const plan = {
    MuscleGroup.chest: [
      ('chest-mid-machine-pec-deck', 40, 10), // máy, số thanh
      ('chest-upper-free-weight-incline-dumbbell-press', 100, 25), // bỏ
    ],
    MuscleGroup.back: [
      ('lats-machine-lat-pulldown', 60, 10), // máy, số thanh
    ],
    MuscleGroup.biceps: [
      ('biceps-free-weight-dumbbell-biceps-curl', 80, 25), // bỏ
    ],
    MuscleGroup.shoulders: [
      ('delt-front-free-weight-seated-dumbbell-shoulder-press', 120, 25),
    ],
  };
  final ids = {for (final e in library) e.id};
  final sessions = <String, int>{};
  var count = 0;
  for (final d in days) {
    for (final g in d.sessionMuscles) {
      for (final (id, base, step) in plan[g] ?? const <(String, int, int)>[]) {
        if (!ids.contains(id)) continue;
        final n = sessions.update(id, (n) => n + 1, ifAbsent: () => 0);
        final start = base + step * n - (n % 4 == 3 ? 3 * step : 0);
        final at = _utc(d.date.atTime(d.time!).add(const Duration(hours: 1)));
        await c.execute(
          Sql.named('''
            INSERT INTO lift_logs (user_id, date, exercise_id, start_kg_x10, end_kg_x10,
                                   logged_at, server_version, client_updated_at)
            VALUES (@user, @date::date, @exercise, @start, @end, @at,
                    nextval('sync_version_seq'), @at)'''),
          parameters: {
            'user': user,
            'date': d.date.toKey(),
            'exercise': id,
            'start': start,
            'end': start + step,
            'at': at,
          },
        );
        count++;
      }
    }
  }
  return count;
}

Future<void> _day(Connection c, String user, PlanDay d) {
  List<String>? names(List<MuscleGroup>? g) =>
      g == null ? null : [for (final m in MuscleGroup.ordered(g)) m.name];
  return c.execute(
    Sql.named('''
      INSERT INTO days (user_id, date, kind, time, muscles, source, mark, actual_muscles,
                        marked_at, server_version, client_updated_at)
      VALUES (@user, @date::date, @kind::day_kind, @time::time, @muscles::muscle_group[],
              'template', @mark::day_mark, @actual::muscle_group[], @markedAt,
              nextval('sync_version_seq'), @at)'''),
    parameters: {
      'user': user,
      'date': d.date.toKey(),
      'kind': d.kind.name,
      'time': d.time?.toKey(),
      'muscles': d.isWorkout ? names(d.muscles) : null,
      'mark': d.mark?.name,
      'actual': names(d.actualMuscles),
      'markedAt': d.markedAt == null ? null : _utc(d.markedAt!),
      'at': _utc(d.markedAt ?? d.date.startOfDay),
    },
  );
}

Future<void> _seedNoSchedule(Connection c, DateTime now) async {
  final user = await _user(c, '0900000002', 'Lan');
  if (user == null) return;
  final setupAt = now.subtract(const Duration(days: 2));
  await _profile(
    c,
    user,
    setupDate: LocalDate.fromDateTime(setupAt),
    completedAt: setupAt,
    reminders: true,
  );
  stdout.writeln(
    'Đã nạp 0900000002 "Lan" (chưa có lịch tuần), mật khẩu $_password',
  );
}
