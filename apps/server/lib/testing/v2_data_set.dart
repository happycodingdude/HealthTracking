import 'dart:io';

import 'package:domain/domain.dart';
import 'package:postgres/postgres.dart';

import '../src/library/library_file.dart';

/// File trong repo tìm từ thư mục chạy test (`apps/server`, `apps/mobile`)
/// hoặc gốc repo (công cụ trong `tool/`).
File repoFile(String path) {
  for (final prefix in ['', '../../', '../']) {
    final file = File('$prefix$path');
    if (file.existsSync()) return file;
  }
  throw StateError('Không tìm thấy $path từ ${Directory.current.path}');
}

/// Thư viện Bản 2 (29 bài Bạn duyệt, `data/v2__exercises.json`) đọc từ file.
LibraryFile v2Library() => LibraryFile.parse(
  repoFile('data/v2__exercises.json').readAsStringSync(),
  allowEquipment: true,
);

/// Nạp thư viện Bản 2 như server Bản 2 đã nạp trên production: chỉ các cột
/// của `0001_baseline` (kèm `equipment`), nên chạy được cả trên database chỉ
/// có `0001` (06 Bản 3 ED3-02) lẫn database đủ migration. Trả số bài.
Future<int> insertV2Library(Session s) async {
  final file = v2Library();
  final sorted = LibraryRules.sorted(file.exercises);
  for (final e in sorted) {
    await s.execute(
      Sql.named('''
        INSERT INTO exercises (id, muscle_group, muscle_region, equipment, logs_weight, name_vi,
                               name_en, youtube_video_id, video_channel, video_duration_s,
                               guide_steps, guide_safety, approved_at, sort_order, active,
                               library_version, server_version)
        VALUES (@id, @group::muscle_group, @region, @equipment::equipment, @logsWeight,
                @nameVi, @nameEn, @youtubeId, @channel, @duration, @steps::text[],
                @safety::text[], @approvedAt::date, @sortOrder, true, @version,
                nextval('sync_version_seq'))'''),
      parameters: {
        'id': e.id,
        'group': e.group.name,
        'region': e.region.id,
        'equipment': file.equipment[e.id],
        'logsWeight': e.logsWeight,
        'nameVi': e.nameVi,
        'nameEn': e.nameEn,
        'youtubeId': e.youtubeVideoId,
        'channel': e.videoChannel,
        'duration': e.videoDurationS,
        'steps': e.guideSteps,
        'safety': e.guideSafety,
        'approvedAt': e.approvedAt.toKey(),
        'sortOrder': e.sortOrder,
        'version': file.libraryVersion,
      },
    );
  }
  return sorted.length;
}

/// Một bản ghi mức tạ của [V2DataSet].
typedef V2Lift = ({String date, String exerciseId, int start, int end});

/// `v2DataSet` (06 Bản 3 §6.11.2): database kiểu Bản 2 — một tài khoản có
/// lịch Ngực + Tay sau / Lưng + Tay trước / Vai + Bụng, mức tạ ở 3 bài giữ (2
/// bài máy ghi số thanh: "Máy ép ngực" 7 → 8 thanh ngày 05/11, lưu 70 → 80;
/// 1 bài tạ ghi kg: 40 → 45 kg, lưu 400 → 450; FX2-03) và 2 bài bỏ (4 bản
/// ghi), thư viện 29 bài có `equipment`. Chỉ dùng cột của `0001_baseline`.
/// Sau purge: 2 bài máy `steps`, bài tạ `kg` (TA3-04).
abstract final class V2DataSet {
  static const phone = '0911000001';

  /// Bài giữ: máy (số thanh × 10) và tạ (kg × 10).
  static const keptLifts = <V2Lift>[
    (
      date: '2026-11-05',
      exerciseId: 'chest-mid-machine-pec-deck',
      start: 70,
      end: 80,
    ),
    (
      date: '2026-11-02',
      exerciseId: 'chest-mid-free-weight-flat-barbell-bench-press',
      start: 400,
      end: 450,
    ),
    (
      date: '2026-11-04',
      exerciseId: 'lats-machine-lat-pulldown',
      start: 60,
      end: 70,
    ),
  ];

  /// 2 bài bỏ, mỗi bài 2 bản ghi.
  static const removedLifts = <V2Lift>[
    (
      date: '2026-11-02',
      exerciseId: 'chest-upper-free-weight-incline-dumbbell-press',
      start: 125,
      end: 150,
    ),
    (
      date: '2026-11-09',
      exerciseId: 'chest-upper-free-weight-incline-dumbbell-press',
      start: 125,
      end: 150,
    ),
    (
      date: '2026-11-04',
      exerciseId: 'biceps-free-weight-dumbbell-biceps-curl',
      start: 100,
      end: 120,
    ),
    (
      date: '2026-11-11',
      exerciseId: 'biceps-free-weight-dumbbell-biceps-curl',
      start: 100,
      end: 120,
    ),
  ];

  static const _days = {
    '2026-11-02': ['chest', 'triceps'],
    '2026-11-04': ['back', 'biceps'],
    '2026-11-05': ['chest', 'triceps'],
    '2026-11-06': ['shoulders', 'abs'],
    '2026-11-09': ['chest', 'triceps'],
    '2026-11-11': ['back', 'biceps'],
  };

  /// Nạp vào database (chỉ có `0001` hoặc đủ migration). Trả `user_id`.
  static Future<String> load(Session s) async {
    await insertV2Library(s);
    final user =
        (await s.execute(
              Sql.named('''
                INSERT INTO users (phone, password_hash, display_name)
                VALUES (@phone, crypt('x', gen_salt('bf', 4)), 'Minh')
                RETURNING id'''),
              parameters: {'phone': phone},
            )).single[0]!
            as String;
    await s.execute(
      Sql.named(
        '''
        INSERT INTO profiles (user_id, height_cm, birth_year, sex, activity_level, setup_date,
                              onboarding_step, disclaimer_accepted_at, onboarding_completed_at,
                              calorie_mode, calorie_kcal, timezone, server_version,
                              client_updated_at)
        VALUES (@user, 172, 1994, 'male', 'moderate', '2026-10-20', 5, now(), now(), 'auto',
                2210, 'Asia/Ho_Chi_Minh', nextval('sync_version_seq'), now())''',
      ),
      parameters: {'user': user},
    );
    for (final MapEntry(key: date, value: muscles) in _days.entries) {
      await s.execute(
        Sql.named(
          '''
          INSERT INTO days (user_id, date, kind, time, muscles, mark, actual_muscles,
                            marked_at, server_version, client_updated_at)
          VALUES (@user, @date::date, 'workout', '18:00', @m::muscle_group[], 'done',
                  @m::muscle_group[], now(), nextval('sync_version_seq'), now())''',
        ),
        parameters: {'user': user, 'date': date, 'm': muscles},
      );
    }
    for (final l in [...keptLifts, ...removedLifts]) {
      await s.execute(
        Sql.named('''
          INSERT INTO lift_logs (user_id, date, exercise_id, start_kg_x10, end_kg_x10,
                                 logged_at, server_version, client_updated_at)
          VALUES (@user, @date::date, @exercise, @start, @end, now(),
                  nextval('sync_version_seq'), now())'''),
        parameters: {
          'user': user,
          'date': l.date,
          'exercise': l.exerciseId,
          'start': l.start,
          'end': l.end,
        },
      );
    }
    return user;
  }
}
