@Tags(['e2e'])
library;

import 'dart:io';

import 'package:api_contract/api_contract.dart';
import 'package:domain/domain.dart' show MuscleGroup;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/data/sync/outbox_writer.dart';
import 'package:mobile/data/sync/sync_api.dart';
import 'package:mobile/data/sync/sync_engine.dart';
import 'package:postgres/postgres.dart';
import 'package:server/server.dart' show LibraryImporter;
import 'package:server/testing.dart' show libraryMin;

import 'sync_e2e_harness.dart';

void main() {
  late E2eServer server;
  final devices = <E2eDevice>[];

  setUpAll(() {
    // flutter_test chặn HTTP thật; test E2E cần gọi server thật trên máy.
    HttpOverrides.global = null;
  });

  setUp(() async => server = await E2eServer.start());

  tearDown(() async {
    for (final d in devices) {
      await d.close();
    }
    devices.clear();
    await server.stop();
  });

  E2eDevice device({Duration ago = Duration.zero, NativeDatabase? executor}) {
    final d = E2eDevice(
      server,
      now: DateTime.now().subtract(ago),
      executor: executor,
    );
    devices.add(d);
    return d;
  }

  Future<String> serverName() async =>
      (await server.tdb.pool.execute(
            "SELECT display_name FROM users WHERE phone = '0912345678'",
          )).single[0]!
          as String;

  test(
    'TA-11: máy A sửa khi không có mạng (sớm hơn), máy B sửa sau → cả hai giữ bản của B',
    () async {
      final a = device(ago: const Duration(minutes: 3));
      final b = device(ago: const Duration(minutes: 1));
      await a.register();
      await b.login();
      expect(await a.sync(), SyncOutcome.synced);
      expect(await b.sync(), SyncOutcome.synced);

      await a.rename('Tên của A'); // A đang không có mạng
      await b.rename('Tên của B');
      expect(await b.sync(), SyncOutcome.synced);
      expect(await serverName(), 'Tên của B');

      expect(await a.sync(), SyncOutcome.synced); // A có mạng lại
      expect(
        await a.displayName(),
        'Tên của B',
        reason: 'bản server mới hơn được giữ',
      );
      expect(a.reporter.reasons, ['sync_ignored_stale']);
      expect((await a.status()).hasPending, isFalse);
      await b.sync();
      expect(await b.displayName(), 'Tên của B');
    },
  );

  test(
    'TA-11: lần sửa sau cùng theo giờ trên máy thắng, kể cả khi gửi lên sau',
    () async {
      final a = device(ago: const Duration(minutes: 1));
      final b = device(ago: const Duration(minutes: 3));
      await a.register();
      await b.login();
      await b.rename('B sửa trước');
      await b.sync();
      await a.rename('A sửa sau'); // giờ trên máy A muộn hơn
      await a.sync();
      expect(await serverName(), 'A sửa sau');
      await b.sync();
      expect(await b.displayName(), 'A sửa sau', reason: 'B nhận qua pull');
    },
  );

  test(
    'TAC-02 / F09-AC2: tắt app khi còn thay đổi chưa đồng bộ, mở lại khi có mạng → outbox tự rỗng, server có dữ liệu',
    () async {
      final file = File(
        '${Directory.systemTemp.createTempSync('e2e_').path}/ironly.db',
      );
      final a = E2eDevice(
        server,
        now: DateTime.now(),
        executor: NativeDatabase(file),
      );
      await a.register();
      await a.sync();
      await a.rename('Tên khi offline');
      expect((await a.status()).hasPending, isTrue, reason: '"Chưa đồng bộ"');
      await a.close(); // tắt app

      final reopened = device(executor: NativeDatabase(file));
      reopened.store.session = a.store.session;
      expect(
        (await reopened.status()).pending,
        1,
        reason: 'outbox còn sau khi mở lại app',
      );
      expect(await reopened.sync(), SyncOutcome.synced);
      expect(
        (await reopened.status()).hasPending,
        isFalse,
        reason: '"Chưa đồng bộ" biến mất',
      );
      expect(await serverName(), 'Tên khi offline');
    },
  );

  test(
    'TAC-03: phản hồi của lần gửi bị mất → app gửi lại cùng mutation, server chỉ ghi 1 lần',
    () async {
      final a = device();
      await a.register();
      await a.sync();
      await a.rename('Một lần');
      // Gửi nhưng "mất" phản hồi: server đã ghi, outbox trên máy vẫn còn.
      final pending = (await a.db.select(a.db.outbox).get())
          .map((r) => r.toMutation())
          .toList();
      await HttpSyncApi(a.api).push(PushRequest(pending));
      final version = (await server.tdb.pool.execute(
        "SELECT server_version FROM users WHERE phone = '0912345678'",
      )).single[0];

      expect(await a.sync(), SyncOutcome.synced);
      final after = (await server.tdb.pool.execute(
        "SELECT server_version FROM users WHERE phone = '0912345678'",
      )).single[0];
      expect(after, version, reason: 'không ghi lần 2');
      expect((await a.status()).hasPending, isFalse);
      final processed = await server.tdb.pool.execute(
        Sql.named(
          'SELECT count(*) FROM processed_mutations WHERE mutation_id = @id::uuid',
        ),
        parameters: {'id': pending.single.mutationId},
      );
      expect(processed.single[0], 1);
    },
  );

  test(
    'TAC-07: máy của tài khoản khác không nhận dữ liệu của tài khoản này',
    () async {
      final a = device();
      final other = device();
      await a.register();
      await other.register(phone: '0922222222', name: 'Bình');
      await a.rename('Riêng của A');
      await a.sync();
      await other.sync();
      expect(await other.displayName(), 'Bình');
    },
  );

  test('VS21-T07: thư viện nạp trên server (libraryMin) đến máy qua pull, dòng '
      'dùng chung không phụ thuộc tài khoản', () async {
    final report = await LibraryImporter(server.tdb.pool).run(libraryMin());
    expect(report.ok, isTrue);
    final a = device();
    await a.register();
    expect(await a.sync(), SyncOutcome.synced);
    final chest = await a.exercises.watchGroup(MuscleGroup.chest).first;
    expect(chest, hasLength(6));
    expect(chest.first.id, 'chest-upper-machine-a');
    expect(
      (await a.exercises.watchGroup(MuscleGroup.abs).first).map(
        (e) => e.logsWeight,
      ),
      everyElement(isFalse),
    );
  });
}
