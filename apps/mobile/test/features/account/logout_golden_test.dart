@Tags(['golden'])
library;

import 'dart:async';

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

/// 06 Bản 3 VS38-T05 (golden): S-73 ba hộp theo mock S-73-1 → 3 (xác nhận,
/// không có mạng, đang đồng bộ) — sáng/tối × cỡ chữ lớn nhất. S-56 có nhóm
/// "Thiết bị này" ở `test/features/me/sync_golden_test.dart`.
void main() {
  late FakeServer server;
  late FakeConnectivity net;

  Future<void> pump(
    WidgetTester tester,
    GoldenVariant variant, {
    bool pending = false,
    FakeHandler? push,
  }) async {
    setPhoneSurface(tester);
    tester.platformDispatcher
      ..platformBrightnessTestValue = variant.brightness
      ..textScaleFactorTestValue = variant.textScale;
    addTearDown(tester.platformDispatcher.clearAllTestValues);
    final db = AppDatabase(NativeDatabase.memory());
    await AccountRepository(db).put('Minh');
    if (pending) {
      await OutboxWriter(db, FixedClock(DateTime(2026, 10, 7, 18, 42))).enqueue(
        SyncEntities.account,
        'me',
        SyncOp.upsert,
        {'displayName': 'Minh'},
      );
    }
    server = FakeServer();
    if (push != null) server.routes['POST /v1/sync/push'] = push;
    net = FakeConnectivity();
    final container = ProviderContainer(
      retry: (_, _) => null,
      overrides: appOverrides(
        server: server,
        db: db,
        connectivity: net,
        logoutFinisher: () async {},
      ),
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const IronlyApp()),
    );
    await tester.pumpAndSettle();
    container.read(routerProvider).go('/me/account');
    await tester.pumpAndSettle();
    final row = find.byKey(const ValueKey('row-logout'));
    await tester.scrollUntilVisible(
      row,
      200,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pumpAndSettle();
    await tester.tap(row);
    await tester.pumpAndSettle();
  }

  Future<void> snap(String name) => expectLater(
    find.byType(MaterialApp),
    matchesGoldenFile('goldens/$name.png'),
  );

  for (final v in GoldenVariant.all) {
    testWidgets('S-73-1 hộp xác nhận đăng xuất ${v.name}', (tester) async {
      await pump(tester, v);
      await snap('s73_confirm_${v.name}');
    });

    testWidgets('S-73-2 đăng xuất khi không có mạng ${v.name}', (tester) async {
      await pump(tester, v);
      net.setOnline(false);
      await tester.tap(find.byKey(const ValueKey('logout-confirm')));
      await tester.pumpAndSettle();
      await snap('s73_offline_${v.name}');
    });

    testWidgets('S-73-3 đang đồng bộ trước khi đăng xuất ${v.name}', (
      tester,
    ) async {
      // Lần đồng bộ lúc mở app còn chờ server: đăng xuất chờ nó rồi mới đẩy.
      final gate = Completer<void>();
      await pump(
        tester,
        v,
        pending: true,
        push: (_) async {
          await gate.future;
          return (
            500,
            {
              'error': {'code': 'internal_error'},
            },
          );
        },
      );
      await tester.tap(find.byKey(const ValueKey('logout-confirm')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await snap('s73_syncing_${v.name}');
      gate.complete();
      await tester.pumpAndSettle();
    });
  }
}
