@Tags(['golden'])
library;

import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/app/app.dart';
import 'package:mobile/data/auth/session_store.dart';
import 'package:mobile/data/db/app_database.dart';
import 'package:mobile/features/auth/application/auth_controller.dart';

import '../../support/app_harness.dart';
import '../../support/fake_server.dart';
import '../../support/fake_sync.dart';
import '../../support/golden.dart';

void main() {
  late Completer<void> hold;

  /// Mock S-07-1: đã nhận 3/5 bản ghi, trang sau đang về.
  Future<void> pump(
    WidgetTester tester,
    GoldenVariant variant, {
    required bool offline,
  }) async {
    setPhoneSurface(tester);
    tester.platformDispatcher
      ..platformBrightnessTestValue = variant.brightness
      ..textScaleFactorTestValue = variant.textScale;
    addTearDown(tester.platformDispatcher.clearAllTestValues);
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    hold = Completer<void>();
    final server = FakeServer()
      ..on('GET', '/v1/sync/pull', (req) async {
        if (req.query['cursor'] == '0') {
          return (
            200,
            {
              'changes': [
                for (var i = 1; i <= 3; i++)
                  {
                    'entity': 'weight',
                    'key': '2026-09-${(i * 7).toString().padLeft(2, '0')}',
                    'deleted': false,
                    'serverVersion': i,
                    'data': {'weightKgX10': 800},
                  },
              ],
              'nextCursor': 3,
              'hasMore': true,
              'remaining': 2,
              'meta': {'serverTime': '2026-10-07T11:42:00.000Z'},
            },
          );
        }
        if (offline) throw FakeOffline();
        await hold.future;
        return (500, null);
      });
    final container = ProviderContainer(
      retry: (_, _) => null,
      overrides: [
        ...appOverrides(
          db: db,
          server: server,
          session: const StoredSession(
            userId: 'u1',
            phone: '0912345678',
            refreshToken: '***REMOVED***',
          ),
          onboarded: false,
          scheduler: FakeScheduler(),
        ),
        initialRestoreProvider.overrideWithValue(true),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const HealthApp()),
    );
    await tester.pumpAndSettle();
  }

  Future<void> snap(String name) => expectLater(
    find.byType(MaterialApp),
    matchesGoldenFile('goldens/$name.png'),
  );

  for (final v in GoldenVariant.all) {
    testWidgets('S-07 đang khôi phục (mock S-07-1) ${v.name}', (tester) async {
      await pump(tester, v, offline: false);
      await snap('s07_${v.name}');
      // Cho request đang chờ kết thúc (không để hẹn giờ của dio treo lại).
      hold.complete();
      await tester.pumpAndSettle();
    });

    testWidgets('S-07 mất kết nối giữa chừng ${v.name}', (tester) async {
      await pump(tester, v, offline: true);
      await snap('s07_failed_${v.name}');
    });
  }
}
