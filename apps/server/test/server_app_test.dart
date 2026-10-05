import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:server/server.dart';
import 'package:test/test.dart';

import 'support/test_database.dart';

void main() {
  test(
    'khởi động (chạy migration) → /healthz qua HTTP thật → tắt an toàn',
    () async {
      final tdb = await TestDatabase.create(migrate: false);
      addTearDown(tdb.dispose);
      final log = CapturingLogger();
      final app = await ServerApp.start(
        ServerConfig(databaseUrl: tdb.url, port: 0),
        logger: log.logger,
      );
      final res = await http.get(
        Uri.parse('http://127.0.0.1:${app.port}/healthz'),
      );
      expect(res.statusCode, 200);
      expect(res.headers['x-request-id'], isNotNull);
      await app.stop();
      final events = log.lines
          .map((l) => (jsonDecode(l) as Map)['event'])
          .toList();
      expect(
        events,
        containsAllInOrder([
          'server_started',
          'request',
          'server_stopping',
          'server_stopped',
        ]),
      );
      await expectLater(
        http.get(Uri.parse('http://127.0.0.1:${app.port}/healthz')),
        throwsA(anything),
      );
    },
  );
}
