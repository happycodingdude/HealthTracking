@Tags(['golden'])
library;

import 'package:api_contract/api_contract.dart';
import 'package:domain/domain.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/app/app.dart';
import 'package:mobile/app/router.dart';
import 'package:mobile/data/db/app_database.dart';
import 'package:mobile/data/sync/outbox_writer.dart';
import 'package:mobile/features/me/data/account_repository.dart';

import '../../support/app_harness.dart';
import '../../support/fake_server.dart';
import '../../support/golden.dart';

void main() {
  Future<void> pump(
    WidgetTester tester,
    GoldenVariant variant,
    String location, {
    required bool pending,
  }) async {
    setPhoneSurface(tester);
    tester.platformDispatcher
      ..platformBrightnessTestValue = variant.brightness
      ..textScaleFactorTestValue = variant.textScale;
    addTearDown(tester.platformDispatcher.clearAllTestValues);
    final db = AppDatabase(NativeDatabase.memory());
    await AccountRepository(db).put('Minh');
    final server = FakeServer();
    if (pending) {
      // Không có mạng: thay đổi nằm lại trong outbox.
      server.offline = true;
      await OutboxWriter(db, FixedClock(DateTime(2026, 10, 7, 18, 42))).enqueue(
        SyncEntities.account,
        'me',
        SyncOp.upsert,
        {'displayName': 'Minh'},
      );
    }
    final container = ProviderContainer(
      retry: (_, _) => null,
      overrides: appOverrides(server: server, db: db),
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const IronlyApp()),
    );
    await tester.pumpAndSettle();
    container.read(routerProvider).go(location);
    await tester.pumpAndSettle();
  }

  Future<void> snap(String name) => expectLater(
    find.byType(MaterialApp),
    matchesGoldenFile('goldens/$name.png'),
  );

  for (final v in GoldenVariant.all) {
    testWidgets('S-56 đã đồng bộ ${v.name}', (tester) async {
      await pump(tester, v, '/me/account', pending: false);
      await snap('s56_synced_${v.name}');
    });

    testWidgets('S-56 chưa đồng bộ (F09-E1) ${v.name}', (tester) async {
      await pump(tester, v, '/me/account', pending: true);
      await snap('s56_pending_${v.name}');
    });

    testWidgets('S-50 (dòng Tài khoản và dữ liệu) ${v.name}', (tester) async {
      await pump(tester, v, '/me', pending: true);
      await snap('s50_${v.name}');
    });

    testWidgets(
      'S-10 đầu trang: lời chào + Chưa đồng bộ (UX-AC16, UX-AC22) ${v.name}',
      (tester) async {
        await pump(tester, v, '/today', pending: true);
        await snap('s10_header_pending_${v.name}');
      },
    );
  }
}
