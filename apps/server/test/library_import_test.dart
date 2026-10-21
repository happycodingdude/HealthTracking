import 'dart:convert';

import 'package:api_contract/api_contract.dart';
import 'package:domain/domain.dart';
import 'package:postgres/postgres.dart';
import 'package:server/server.dart';
import 'package:server/testing.dart';
import 'package:test/test.dart';

import 'support/test_app.dart';

void main() {
  late TestApp app;
  late LibraryImporter importer;

  setUp(() async {
    app = await TestApp.create(now: DateTime.utc(2026, 11, 12, 11));
    importer = LibraryImporter(app.tdb.pool);
  });
  tearDown(() => app.dispose());

  Future<int> count([String where = 'true']) async =>
      (await app.tdb.pool.execute(
            'SELECT count(*) FROM exercises WHERE $where',
          )).single[0]!
          as int;

  LibraryFile fileOf(Map<String, Object?> json) =>
      LibraryFile.parse(jsonEncode(json));

  group('TAC2-12 (phần nạp), 05 Bản 2 §6.10.2', () {
    LibraryFile duplicateName() {
      final json = libraryMinJson();
      final list = json['exercises']! as List;
      (list[1] as Map)['nameVi'] = (list[0] as Map)['nameVi'];
      return fileOf(json);
    }

    test(
      'file sai (trùng tên, LIB-R1) → từ chối toàn bộ, database không đổi',
      () async {
        final r = await importer.run(duplicateName());
        expect(r.ok, isFalse);
        expect(r.issues.single, contains('nameVi trùng'));
        expect(await count(), 0);

        await importer.run(libraryMin());
        final before = await app.tdb.pool.execute(
          'SELECT id, server_version FROM exercises ORDER BY id',
        );
        expect((await importer.run(duplicateName())).ok, isFalse);
        final after = await app.tdb.pool.execute(
          'SELECT id, server_version FROM exercises ORDER BY id',
        );
        expect(
          [for (final r in after) r.toList()],
          [for (final r in before) r.toList()],
        );
      },
    );

    test(
      'file hợp lệ → 29 bài, thứ tự TD3-07; mọi tài khoản nhận qua pull',
      () async {
        final r = await importer.run(libraryMin());
        expect((r.ok, r.added, r.updated, r.deactivated), (true, 29, 0, 0));
        expect(r.describe(), contains('thêm 29'));
        final order = await app.tdb.pool.execute(
          'SELECT id FROM exercises ORDER BY sort_order',
        );
        expect(order.first[0], 'chest-upper-machine-a');
        expect(order[1][0], 'chest-upper-free-weight-a');
        expect(order[6][0], 'lats-machine-a', reason: 'Lưng ngay sau Ngực');
        expect(order.last[0], 'obliques-bodyweight-a');

        final token = (await app.register()).accessToken;
        final pulled = [
          for (final c in (await app.pull(token)).changes)
            if (c.entity == 'exercise')
              const ExerciseCodec().decode(c.key, c.data!),
        ];
        expect(pulled, hasLength(29));
        expect(pulled.every((e) => e.active && e.videoAvailable), isTrue);
        expect(
          pulled.firstWhere((e) => e.group == MuscleGroup.abs).logsWeight,
          isFalse,
        );
      },
    );

    test('nạp lại file không đổi → không cấp server_version mới', () async {
      await importer.run(libraryMin());
      final v1 =
          (await app.tdb.pool.execute(
                'SELECT max(server_version) FROM exercises',
              )).single[0]!
              as int;
      final r = await importer.run(libraryMin());
      expect((r.added, r.updated, r.deactivated), (0, 0, 0));
      final v2 =
          (await app.tdb.pool.execute(
                'SELECT max(server_version) FROM exercises',
              )).single[0]!
              as int;
      expect(v2, v1);
    });

    test('bỏ một bài khỏi file → active = false, không xóa dòng (TA2-10); '
        'đưa lại thì active = true', () async {
      final withExtra = libraryMinJson();
      (withExtra['exercises']! as List).add(
        fixtureEntry(MuscleRegion.lats, LegacyEquipment.machine, suffix: 'b'),
      );
      await importer.run(fileOf(withExtra));
      expect(await count('active'), 30);

      final r = await importer.run(libraryMin());
      expect(r.deactivated, 1);
      expect(await count(), 30);
      expect(
        (await app.tdb.pool.execute(
          "SELECT active FROM exercises WHERE id = 'lats-machine-b'",
        )).single[0],
        isFalse,
      );
      await importer.run(fileOf(withExtra));
      expect(await count('active'), 30);
    });

    test('LIB-AC5, FA2-14: thay video giữ id → lịch sử mức tạ còn nguyên; '
        'trạng thái video làm lại từ đầu', () async {
      await importer.run(libraryMin());
      const id = 'chest-upper-free-weight-a';
      final user = (await app.register()).accessToken;
      final userId =
          (await app.tdb.pool.execute(
                "SELECT id FROM users WHERE phone = '0912345678'",
              )).single[0]!
              as String;
      expect(user, isNotEmpty);
      await app.tdb.pool.execute(
        Sql.named('''
          INSERT INTO month_plans (user_id, month, start_date, template_hash, generated_at,
                                   server_version, client_updated_at)
          VALUES (@u, '2026-11', '2026-11-02', @h, now(), 1, now());
        '''),
        parameters: {'u': userId, 'h': 'a' * 64},
      );
      await app.tdb.pool.execute(
        Sql.named(
          '''
          INSERT INTO days (user_id, date, kind, time, muscles, server_version, client_updated_at)
          VALUES (@u, '2026-11-12', 'workout', '18:00', ARRAY['chest']::muscle_group[], 1, now())''',
        ),
        parameters: {'u': userId},
      );
      await app.tdb.pool.execute(
        Sql.named('''
          INSERT INTO lift_logs (user_id, date, exercise_id, start_kg_x10, end_kg_x10, logged_at,
                                 server_version, client_updated_at)
          VALUES (@u, '2026-11-12', @id, 120, 140, now(), 1, now())'''),
        parameters: {'u': userId, 'id': id},
      );
      await app.tdb.pool.execute(
        Sql.named('''
          UPDATE exercises SET video_available = false, video_unavailable_reason = 'private',
                               video_checked_at = now()
          WHERE id = @id'''),
        parameters: {'id': id},
      );

      final newVideo = libraryMinJson();
      final entry =
          (newVideo['exercises']! as List).firstWhere(
                (e) => (e as Map)['id'] == id,
              )
              as Map;
      (entry['video'] as Map)['youtubeId'] = 'newVideo001';
      final r = await importer.run(fileOf(newVideo));
      expect(r.updated, 1);
      final row = (await app.tdb.pool.execute(
        Sql.named('''
          SELECT youtube_video_id, video_available, video_unavailable_reason, video_checked_at
          FROM exercises WHERE id = @id'''),
        parameters: {'id': id},
      )).single;
      expect(row.toList(), ['newVideo001', true, null, null]);
      expect(
        (await app.tdb.pool.execute(
          'SELECT start_kg_x10, end_kg_x10 FROM lift_logs',
        )).single.toList(),
        [120, 140],
      );
    });
  });

  group('cổng phát hành `--check-only` (IR2-06, LIB-AC1 → AC3)', () {
    test('file đạt → không ghi gì vào database', () async {
      final r = await importer.run(libraryMin(), checkOnly: true);
      expect(r.ok, isTrue);
      expect(r.describe(), contains('Đạt: 29 bài'));
      expect(await count(), 0);
    });

    test('thiếu độ dài video, video > 60 giây, hướng dẫn có "12 lần" → '
        'không đạt', () async {
      final json = libraryMinJson();
      final list = json['exercises']! as List;
      ((list[0] as Map)['video'] as Map)['durationSeconds'] = null;
      ((list[1] as Map)['video'] as Map)['durationSeconds'] = 61;
      ((list[2] as Map)['guide'] as Map)['steps'] = [
        'Bước một',
        'Bước hai',
        'Lặp lại 12 lần',
      ];
      final r = await importer.run(fileOf(json), checkOnly: true);
      expect(r.ok, isFalse);
      expect(r.issues, [
        'chest-upper-machine-a: video.durationSeconds',
        'chest-upper-free-weight-a: video.durationSeconds',
        'chest-mid-machine-a: guide',
      ]);
      // Không phải cổng phát hành: thiếu độ dài vẫn nạp được trong lúc dev;
      // quá 60 giây thì không.
      ((list[1] as Map)['video'] as Map)['durationSeconds'] = 50;
      expect((await importer.run(fileOf(json))).ok, isTrue);
    });

    test('trường ngoài lược đồ (guideDraft, video.title, videoBackup) hoặc '
        'thiếu ngày duyệt → file bị từ chối', () {
      final json = libraryMinJson();
      final list = json['exercises']! as List;
      (list[0] as Map)['guideDraft'] = {'steps': <String>[]};
      ((list[1] as Map)['video'] as Map)['title'] = 'Tiêu đề';
      (list[2] as Map)['videoBackup'] = {'youtubeId': 'x'};
      (list[3] as Map).remove('approvedAt');
      expect(
        () => fileOf(json),
        throwsA(
          isA<LibraryFileException>().having((e) => e.issues, 'issues', [
            'chest-upper-machine-a: guideDraft: trường ngoài lược đồ',
            'chest-upper-free-weight-a: video.title: trường ngoài lược đồ',
            'chest-mid-machine-a: videoBackup: trường ngoài lược đồ',
            'chest-mid-free-weight-a: approvedAt',
          ]),
        ),
      );
    });
  });

  group('YouTube Data API (VS21-T04)', () {
    // `youtubeResponses` (06 Bản 2 §6.9.2): phản hồi `videos.list` ghi sẵn.
    final youtubeResponses = {
      'items': [
        {
          'id': 'publicVid01',
          'status': {
            'uploadStatus': 'processed',
            'privacyStatus': 'public',
            'embeddable': true,
          },
          'contentDetails': {'duration': 'PT48S'},
        },
        {
          'id': 'longVideo01',
          'status': {
            'uploadStatus': 'processed',
            'privacyStatus': 'public',
            'embeddable': true,
          },
          'contentDetails': {'duration': 'PT1M2S'},
        },
        {
          'id': 'privateVid1',
          'status': {
            'uploadStatus': 'processed',
            'privacyStatus': 'private',
            'embeddable': true,
          },
          'contentDetails': {'duration': 'PT30S'},
        },
        {
          'id': 'noEmbed0001',
          'status': {
            'uploadStatus': 'processed',
            'privacyStatus': 'public',
            'embeddable': false,
          },
          'contentDetails': {'duration': 'PT30S'},
        },
        {
          'id': 'processing1',
          'status': {
            'uploadStatus': 'uploaded',
            'privacyStatus': 'public',
            'embeddable': true,
          },
          'contentDetails': {'duration': 'P0D'},
        },
      ],
    };

    test('đọc phản hồi ghi sẵn: độ dài PT48S, PT1M2S đúng giây; mã không tồn '
        'tại thì không có trong kết quả', () {
      final info = YouTubeDataApiClient.parseResponse(youtubeResponses);
      expect(info.keys, isNot(contains('khongTonTai')));
      expect(info['publicVid01']!.durationSeconds, 48);
      expect(info['longVideo01']!.durationSeconds, 62);
      expect(info['publicVid01']!.problem, isNull);
      expect(info['longVideo01']!.problem, VideoUnavailableReason.tooLong);
      expect(info['privateVid1']!.problem, VideoUnavailableReason.private);
      expect(
        info['noEmbed0001']!.problem,
        VideoUnavailableReason.notEmbeddable,
      );
      expect(info['processing1']!.problem, VideoUnavailableReason.removed);
    });

    test('ISO 8601 duration', () {
      for (final (v, s) in [
        ('PT48S', 48),
        ('PT1M2S', 62),
        ('PT1M', 60),
        ('PT1H2M3S', 3723),
        ('P0D', 0),
        ('P1DT1S', 86401),
      ]) {
        expect(YouTubeDataApiClient.parseIsoDuration(v), s, reason: v);
      }
      for (final bad in ['', 'P', 'PT', '48', 'PT1.5S']) {
        expect(YouTubeDataApiClient.parseIsoDuration(bad), isNull, reason: bad);
      }
    });

    test('TA2-09: 55 video → 2 lần gọi (lô 50)', () async {
      final api = FakeYouTubeApi();
      await api.videos([
        for (var i = 0; i < 55; i++) 'video${i.toString().padLeft(6, '0')}',
      ]);
      expect(api.calls, 2);
    });
  });
}
