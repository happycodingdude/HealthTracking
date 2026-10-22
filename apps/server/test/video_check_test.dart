import 'dart:async';

import 'package:api_contract/api_contract.dart';
import 'package:postgres/postgres.dart';
import 'package:server/server.dart';
import 'package:server/src/sync/sync_service.dart';
import 'package:server/testing.dart';
import 'package:test/test.dart';

import 'support/test_app.dart';

final class RecordingAlerts implements Alerts {
  final warnings = <(String, Map<String, String>)>[];

  @override
  Future<void> warning(String message, Map<String, String> tags) async =>
      warnings.add((message, tags));
}

void main() {
  late TestApp app;
  late FakeYouTubeApi youtube;
  late RecordingAlerts alerts;
  late VideoCheckJob job;

  setUp(() async {
    app = await TestApp.create(now: DateTime.utc(2026, 11, 12, 11));
    await LibraryImporter(app.tdb.pool).run(library28());
    youtube = FakeYouTubeApi();
    for (final r in await app.tdb.pool.execute(
      'SELECT youtube_video_id FROM exercises',
    )) {
      youtube.put(r[0]! as String);
    }
    alerts = RecordingAlerts();
    job = VideoCheckJob(
      db: app.tdb.pool,
      api: youtube,
      alerts: alerts,
      logger: app.log.logger,
    );
  });
  tearDown(() => app.dispose());

  /// Mã video của bài [id] theo fixture `library28`.
  String videoOf(String id) => fixtureVideoId(id);

  Future<List<Object?>> row(String id) async => (await app.tdb.pool.execute(
    Sql.named(
      'SELECT video_available, video_unavailable_reason, server_version FROM exercises WHERE id = @id',
    ),
    parameters: {'id': id},
  )).single.toList();

  const target = 'chest-mid-free-weight-flat-barbell-bench-press';

  test(
    'mọi video đạt → không ghi gì, không cảnh báo; 28 video = 1 lần gọi',
    () async {
      final before = await row(target);
      final r = await job.run();
      expect((r.checked, r.failed), (28, false));
      expect(r.changes, isEmpty);
      expect(youtube.calls, 1);
      expect(await row(target), before);
      expect(alerts.warnings, isEmpty);
    },
  );

  for (final (name, setup, reason) in [
    (
      'bị gỡ',
      (FakeYouTubeApi y, String v) => y.videosById.remove(v),
      'removed',
    ),
    (
      'riêng tư',
      (FakeYouTubeApi y, String v) => y.put(v, privacy: 'private'),
      'private',
    ),
    (
      'tắt nhúng',
      (FakeYouTubeApi y, String v) => y.put(v, embeddable: false),
      'not_embeddable',
    ),
    (
      'dài hơn 60 giây',
      (FakeYouTubeApi y, String v) => y.put(v, seconds: 75),
      'too_long',
    ),
  ]) {
    test(
      'F18-E1, TAC2-11 (phần server): video $name → không khả dụng '
      '($reason), cấp server_version mới, cảnh báo Sentry, app nhận qua pull',
      () async {
        final token = (await app.register()).accessToken;
        final cursor = (await app.pull(token)).nextCursor;
        final before = await row(target);
        setup(youtube, videoOf(target));
        final r = await job.run();
        expect(r.changes.single.exerciseId, target);
        final after = await row(target);
        expect((after[0], after[1]), (false, reason));
        expect(after[2] as int, greaterThan(before[2]! as int));
        expect(alerts.warnings.single.$2, {
          'exerciseId': target,
          'youtubeId': videoOf(target),
          'reason': reason,
        });
        final changes = (await app.pull(token, cursor: cursor)).changes;
        final e = const ExerciseCodec().decode(
          target,
          changes.singleWhere((c) => c.key == target).data!,
        );
        expect(e.videoAvailable, isFalse);
        expect(e.videoUnavailableReason?.wire, reason);
      },
    );
  }

  test('video khả dụng trở lại → tự chuyển khả dụng, có cảnh báo', () async {
    youtube.put(videoOf(target), privacy: 'private');
    await job.run();
    youtube.put(videoOf(target));
    final r = await job.run();
    expect(r.changes.single.available, isTrue);
    expect((await row(target)).take(2), [true, null]);
    expect(alerts.warnings.last.$2['reason'], 'available');
  });

  test(
    'trạng thái không đổi giữa hai lần → lần sau không cấp server_version',
    () async {
      youtube.put(videoOf(target), privacy: 'private');
      await job.run();
      final first = await row(target);
      final r = await job.run();
      expect(r.changes, isEmpty);
      expect(await row(target), first);
    },
  );

  test(
    'lỗi gọi API (hết hạn mức, mất mạng) → không đổi gì, thử lại lần sau',
    () async {
      youtube
        ..videosById.clear()
        ..failing = true;
      final before = await row(target);
      final r = await job.run();
      expect(r.failed, isTrue);
      expect(r.describe(), contains('thử lại'));
      expect(await row(target), before);
      expect(alerts.warnings, isEmpty);
    },
  );

  test('bài đã rời thư viện (gỡ sau ra mắt, bài bỏ) không được kiểm', () async {
    await app.tdb.pool.execute(
      "UPDATE exercises SET active = false WHERE id = 'lats-machine-lat-pulldown'",
    );
    await app.tdb.pool.execute(
      "UPDATE exercises SET active = false, deleted = true WHERE id = 'legs-quads-leg-press'",
    );
    final r = await job.run();
    expect(r.checked, 26);
  });

  group('lịch job (TD2-17): hằng ngày 03:30 giờ Việt Nam', () {
    test('VIDEO_CHECK_CRON chỉ nhận dạng "phút giờ * * *"', () {
      expect(ServerConfig.parseDailyCron('30 3 * * *'), (hour: 3, minute: 30));
      expect(ServerConfig.parseDailyCron('0 23 * * *'), (hour: 23, minute: 0));
      for (final bad in ['30 3 * * 1', '*/5 * * * *', '61 3 * * *', 'abc']) {
        expect(
          () => ServerConfig.parseDailyCron(bad),
          throwsA(isA<ConfigException>()),
          reason: bad,
        );
      }
    });

    test('thời gian tới lần chạy kế tiếp', () {
      const at = (hour: 3, minute: 30);
      // 20:00 UTC = 03:00 giờ Việt Nam → còn 30 phút.
      expect(
        JobScheduler.untilNext(
          DateTime.utc(2026, 10, 12, 20),
          at,
          JobScheduler.vietnamOffset,
        ),
        const Duration(minutes: 30),
      );
      // Đúng 03:30 → lần sau là ngày mai.
      expect(
        JobScheduler.untilNext(
          DateTime.utc(2026, 10, 12, 20, 30),
          at,
          JobScheduler.vietnamOffset,
        ),
        const Duration(days: 1),
      );
      // 05:00 giờ Việt Nam → 22 giờ 30 phút nữa.
      expect(
        JobScheduler.untilNext(
          DateTime.utc(2026, 10, 12, 22),
          at,
          JobScheduler.vietnamOffset,
        ),
        const Duration(hours: 22, minutes: 30),
      );
    });
  });

  test('05 Bản 2 §6.6.1: dòng dùng chung ghi xen giữa lúc pull không bị cursor '
      'bỏ sót (khóa dòng dùng chung)', () async {
    final token = (await app.register()).accessToken;
    final cursor = (await app.pull(token)).nextCursor;
    // Một transaction ghi thư viện đang dở: đã giữ khóa, đã lấy version.
    final writer = Database.open(app.tdb.url, maxConnections: 1);
    addTearDown(writer.close);
    final release = Completer<void>();
    final writing = writer.pool.runTx((tx) async {
      await SyncService.lockSharedRowsForWrite(tx);
      await tx.execute(
        Sql.named('''
          UPDATE exercises SET video_available = false, video_unavailable_reason = 'private',
            server_version = nextval('sync_version_seq') WHERE id = @id'''),
        parameters: {'id': target},
      );
      await release.future;
    });
    await Future<void>.delayed(const Duration(milliseconds: 100));
    // Trong lúc đó tài khoản ghi một thay đổi khác (version lớn hơn), commit
    // trước dòng thư viện.
    await app.push(token, [
      mutation(
        'account',
        'me',
        SyncOp.upsert,
        at: DateTime.utc(2026, 11, 12, 10, 59),
        data: {'displayName': 'Minh mới'},
      ),
    ]);
    final pulling = app.pull(token, cursor: cursor);
    await Future<void>.delayed(const Duration(milliseconds: 200));
    release.complete();
    await writing;
    final page = await pulling;
    expect(
      page.changes.map((c) => c.entity),
      containsAll(['exercise', 'account']),
      reason: 'pull chờ transaction ghi dòng dùng chung xong',
    );
  });
}
