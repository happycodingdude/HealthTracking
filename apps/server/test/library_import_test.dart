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

  Future<List<List<Object?>>> snapshot() async => [
    for (final r in await app.tdb.pool.execute(
      'SELECT id, server_version, active FROM exercises ORDER BY id',
    ))
      r.toList(),
  ];

  group('TAC3-04, 05 Bản 3 §6.10.2: nạp thư viện Bản 3', () {
    test('thiếu bài giữ, 27 bài, có bài bỏ → từ chối toàn bộ, database không '
        'đổi', () async {
      await importer.run(library28());
      final before = await snapshot();
      for (final (json, issue) in [
        (
          library28MissingKeptJson(),
          'chest-mid-machine-pec-deck: thiếu bài giữ của Bản 2',
        ),
        (library27Json(), 'cần đúng 28 bài, đang có 27'),
        (
          library28WithRemovedJson(),
          'chest-lower-free-weight-decline-barbell-bench-press: bài đã bỏ ở '
              'Bản 3',
        ),
      ]) {
        final r = await importer.run(fileOf(json));
        expect(r.ok, isFalse);
        expect(r.issues, contains(issue));
        expect(r.describe(), contains('database không đổi'));
        expect(await snapshot(), before);
      }
      final r27 = await importer.run(fileOf(library27Json()));
      expect(r27.issues, contains('legs: cần 5 bài, đang có 4'));
    });

    test('ED3-05: còn trường equipment → file bị từ chối', () {
      expect(
        () => fileOf(library28WithEquipmentJson()),
        throwsA(
          isA<LibraryFileException>().having((e) => e.issues, 'issues', [
            'chest-mid-machine-pec-deck: equipment: trường ngoài lược đồ',
          ]),
        ),
      );
      expect(
        LibraryFile.parse(
          jsonEncode(library28WithEquipmentJson()),
          allowEquipment: true,
        ).equipment,
        {'chest-mid-machine-pec-deck': 'machine'},
        reason: 'chỉ dữ liệu Bản 2 của test, dev được đọc equipment',
      );
    });

    test('file đúng → 28 bài, sort_in_group và sort_order theo F18-R43, '
        'equipment NULL; mọi tài khoản nhận qua pull', () async {
      final r = await importer.run(library28());
      expect((r.ok, r.added, r.updated, r.deactivated), (true, 28, 0, 0));
      expect(r.describe(), contains('thêm 28'));
      final rows = await app.tdb.pool.execute(
        'SELECT id, sort_in_group, sort_order, equipment FROM exercises '
        'ORDER BY sort_order',
      );
      expect(
        [for (final r in rows) r[0]],
        [for (final (id, _) in library28Ids) id],
      );
      expect(rows.first.toList(), ['chest-mid-machine-pec-deck', 1, 101, null]);
      expect(rows[4].toList().take(3), [
        'back-back-mid-standing-cable-row-bar',
        1,
        201,
      ]);
      expect(rows.last.toList().take(3), [
        'legs-calves-standing-calf-raise-machine',
        5,
        705,
      ]);

      final token = (await app.register()).accessToken;
      final pulled = [
        for (final c in (await app.pull(token)).changes)
          if (c.entity == 'exercise')
            const ExerciseCodec().decode(c.key, c.data!),
      ];
      expect(pulled, hasLength(28));
      expect(pulled.where((e) => e.group == MuscleGroup.legs), hasLength(5));
      expect(
        pulled.firstWhere((e) => e.group == MuscleGroup.abs).logsWeight,
        isFalse,
      );
    });

    test('nạp lại file không đổi → không cấp server_version mới', () async {
      await importer.run(library28());
      final before = await snapshot();
      final r = await importer.run(library28());
      expect((r.added, r.updated, r.deactivated), (0, 0, 0));
      expect(await snapshot(), before);
    });

    test('nạp đè database Bản 2: bài giữ dùng lại id (tên Bản 3, equipment '
        'NULL), bài khác không có trong file → active = false (F18-R46), 14 '
        'bài bỏ không bị đụng tới (để library purge xử lý)', () async {
      await insertV2Library(app.tdb.pool);
      await app.tdb.pool.execute(
        'INSERT INTO exercises (id, muscle_group, muscle_region, logs_weight, '
        'name_vi, youtube_video_id, video_channel, guide_steps, guide_safety, '
        'approved_at, sort_order, library_version, server_version) VALUES '
        "('lats-extra-a', 'back', 'lats', true, 'Bài thêm', 'abcdefghijk', "
        "'Kênh', ARRAY['a','b','c'], ARRAY['a','b'], '2026-10-11', 999, 1, "
        "nextval('sync_version_seq'))",
      );
      Future<List<List<Object?>>> removed() async => [
        for (final r in await app.tdb.pool.execute(
          Sql.named(
            'SELECT id, server_version, active, equipment::text FROM exercises '
            'WHERE id = ANY(@ids) ORDER BY id',
          ),
          parameters: {'ids': LibraryV3.removedV2Ids.toList()},
        ))
          r.toList(),
      ];
      final removedBefore = await removed();
      expect(removedBefore, hasLength(14));
      final r = await importer.run(library28());
      expect(r.ok, isTrue);
      expect((r.added, r.updated, r.deactivated), (13, 15, 1));
      final kept = (await app.tdb.pool.execute(
        'SELECT name_vi, equipment, active FROM exercises '
        "WHERE id = 'chest-mid-machine-pec-deck'",
      )).single;
      expect(kept.toList(), ['Bài chest-mid-machine-pec-deck', null, true]);
      expect(
        (await app.tdb.pool.execute(
          "SELECT active FROM exercises WHERE id = 'lats-extra-a'",
        )).single[0],
        isFalse,
      );
      expect(await removed(), removedBefore);
    });

    test('LIB-AC5, FA2-14: thay video giữ id → lịch sử mức tạ còn nguyên; '
        'trạng thái video làm lại từ đầu', () async {
      await importer.run(library28());
      const id = 'chest-mid-free-weight-flat-barbell-bench-press';
      final user = (await app.register()).accessToken;
      final userId =
          (await app.tdb.pool.execute(
                "SELECT id FROM users WHERE phone = '0912345678'",
              )).single[0]!
              as String;
      expect(user, isNotEmpty);
      await app.tdb.pool.execute(
        Sql.named(
          'INSERT INTO days (user_id, date, kind, time, muscles, server_version, '
          "client_updated_at) VALUES (@u, '2026-11-12', 'workout', '18:00', "
          "ARRAY['chest']::muscle_group[], 1, now())",
        ),
        parameters: {'u': userId},
      );
      await app.tdb.pool.execute(
        Sql.named(
          'INSERT INTO lift_logs (user_id, date, exercise_id, start_kg_x10, '
          'end_kg_x10, logged_at, server_version, client_updated_at) VALUES '
          "(@u, '2026-11-12', @id, 120, 140, now(), 1, now())",
        ),
        parameters: {'u': userId, 'id': id},
      );
      await app.tdb.pool.execute(
        Sql.named(
          "UPDATE exercises SET video_available = false, video_unavailable_reason = 'private', "
          'video_checked_at = now() WHERE id = @id',
        ),
        parameters: {'id': id},
      );

      final newVideo = library28Json();
      final entry =
          (newVideo['exercises']! as List).firstWhere(
                (e) => (e as Map)['id'] == id,
              )
              as Map;
      (entry['video'] as Map)['youtubeId'] = 'newVideo001';
      final r = await importer.run(fileOf(newVideo));
      expect(r.updated, 1);
      final row = (await app.tdb.pool.execute(
        Sql.named(
          'SELECT youtube_video_id, video_available, video_unavailable_reason, '
          'video_checked_at FROM exercises WHERE id = @id',
        ),
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

  group('cổng phát hành `--check-only` (IR3-06, LIB-AC21 → AC23)', () {
    test('file đạt → không ghi gì vào database', () async {
      final r = await importer.run(library28(), checkOnly: true);
      expect(r.ok, isTrue);
      expect(r.describe(), contains('Đạt: 28 bài'));
      expect(await count(), 0);
    });

    test('thiếu độ dài video, video > 60 giây, hướng dẫn có "12 lần" → '
        'không đạt', () async {
      final json = library28Json();
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
        'chest-mid-machine-pec-deck: video.durationSeconds',
        'chest-mid-free-weight-flat-barbell-bench-press: video.durationSeconds',
        'chest-upper-machine-incline-machine-chest-press: guide',
      ]);
      // Không phải cổng phát hành: thiếu độ dài vẫn nạp được trong lúc dev;
      // quá 60 giây thì không.
      ((list[1] as Map)['video'] as Map)['durationSeconds'] = 50;
      expect((await importer.run(fileOf(json))).ok, isTrue);
    });

    test('trường ngoài lược đồ (guideDraft, video.title, videoBackup) hoặc '
        'thiếu ngày duyệt → file bị từ chối', () {
      final json = library28Json();
      final list = json['exercises']! as List;
      (list[0] as Map)['guideDraft'] = {'steps': <String>[]};
      ((list[1] as Map)['video'] as Map)['title'] = 'Tiêu đề';
      (list[2] as Map)['videoBackup'] = {'youtubeId': 'x'};
      (list[3] as Map).remove('approvedAt');
      expect(
        () => fileOf(json),
        throwsA(
          isA<LibraryFileException>().having((e) => e.issues, 'issues', [
            'chest-mid-machine-pec-deck: guideDraft: trường ngoài lược đồ',
            'chest-mid-free-weight-flat-barbell-bench-press: video.title: '
                'trường ngoài lược đồ',
            'chest-upper-machine-incline-machine-chest-press: videoBackup: '
                'trường ngoài lược đồ',
            'chest-chest-lower-decline-plate-loaded-press: approvedAt',
          ]),
        ),
      );
    });

    test('LIB-AC21 → AC23 trên file thật data/v3__exercises.json', () async {
      final file = LibraryFile.parse(
        repoFile('data/v3__exercises.json').readAsStringSync(),
      );
      expect((await importer.run(file, checkOnly: true)).ok, isTrue);
      expect(file.libraryVersion, 2);
      // LIB-AC21: 28 bài khớp 03 §6.12 về nhóm, vùng, thứ tự.
      expect([for (final e in file.exercises) (e.id, e.region)], library28Ids);
      // LIB-AC22: 13 bài làm mới có ngày duyệt, kênh, độ dài ≤ 60 giây.
      final fresh = [
        for (final e in file.exercises)
          if (!LibraryV3.keptV2Ids.contains(e.id)) e,
      ];
      expect(fresh, hasLength(13));
      for (final e in fresh) {
        expect(e.approvedAt, LocalDate(2026, 10, 21), reason: e.id);
        expect(e.videoChannel, isNotEmpty);
        expect(e.videoDurationS, inInclusiveRange(1, 60), reason: e.id);
      }
      // LIB-AC23: 15 bài giữ có đúng video và hướng dẫn đã duyệt ở Bản 2.
      final v2 = {for (final e in v2Library().exercises) e.id: e};
      for (final e in file.exercises) {
        final old = v2[e.id];
        if (old == null) continue;
        expect(e.youtubeVideoId, old.youtubeVideoId, reason: e.id);
        expect(e.videoChannel, old.videoChannel, reason: e.id);
        expect(e.guideSteps, old.guideSteps, reason: e.id);
        expect(e.guideSafety, old.guideSafety, reason: e.id);
        expect(e.approvedAt, old.approvedAt, reason: e.id);
      }
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
