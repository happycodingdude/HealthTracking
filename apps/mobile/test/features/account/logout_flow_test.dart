import 'dart:async';

import 'package:api_contract/api_contract.dart' show SyncOp;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/app/app.dart';
import 'package:mobile/app/providers.dart';
import 'package:mobile/app/shell/app_tab_bar.dart';
import 'package:mobile/app/strings_vi.dart';
import 'package:mobile/app/theme.dart';
import 'package:mobile/data/db/app_database.dart';
import 'package:mobile/data/logout_flag.dart';
import 'package:mobile/data/sync/outbox_writer.dart';
import 'package:mobile/features/me/data/account_repository.dart';

import '../../support/app_harness.dart';
import '../../support/fake_server.dart';

/// 06 Bản 3 VS38-T05 (widget): S-56 nhóm "Thiết bị này", S-73 bốn hộp
/// (F27-AC1, F27-AC2, F27-R3, UX-AC59, UX-AC60 phần app). Phần xóa dữ liệu và
/// dựng lại app ở `app_root_test.dart`.
void main() {
  late FakeServer server;
  late FakeConnectivity net;
  late AppDatabase db;
  late MemoryLogoutFlag flag;
  late ProviderContainer container;
  var finished = 0;

  setUp(() {
    server = FakeServer();
    server.routes['POST /v1/auth/logout'] = (_) => (204, null);
    net = FakeConnectivity();
    db = AppDatabase(NativeDatabase.memory());
    flag = MemoryLogoutFlag();
    finished = 0;
  });

  Future<void> pump(WidgetTester tester) async {
    tester.view
      ..physicalSize = const Size(390 * 3, 844 * 3)
      ..devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await AccountRepository(db).put('Minh');
    container = ProviderContainer(
      retry: (_, _) => null,
      overrides: appOverrides(
        server: server,
        connectivity: net,
        db: db,
        logoutFlag: flag,
        logoutFinisher: () async => finished++,
      ),
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const IronlyApp()),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(of: find.byType(AppTabBar), matching: find.text(S.tabMe)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('row-account-data')));
    await tester.pumpAndSettle();
  }

  Future<void> tapKey(WidgetTester tester, String key) async {
    final f = find.byKey(ValueKey(key));
    await tester.ensureVisible(f);
    await tester.pumpAndSettle();
    await tester.tap(f);
    await tester.pumpAndSettle();
  }

  /// Hai thay đổi chưa đồng bộ (F27-AC3).
  Future<void> twoUnsynced() async {
    final outbox = OutboxWriter(db, container.read(clockProvider));
    for (final key in ['2026-10-06', '2026-10-07']) {
      await outbox.enqueue('weight', key, SyncOp.upsert, {'kgX10': 700});
    }
  }

  Future<int> outboxCount() async => (await db.select(db.outbox).get()).length;

  testWidgets('F27-AC1, UX-AC59: nhóm "THIẾT BỊ NÀY" có "Đăng xuất" (không '
      'đỏ) + dòng giải thích → hộp "Đăng xuất?" câu nguyên văn, nút đỏ; "Hủy" '
      '→ không đổi gì', (tester) async {
    await pump(tester);
    expect(find.text(S.thisDevice.toUpperCase()), findsOneWidget);
    expect(find.text(S.logoutHint), findsOneWidget);
    final context = tester.element(find.byKey(const ValueKey('row-logout')));
    final rowText = tester.widget<Text>(
      find.descendant(
        of: find.byKey(const ValueKey('row-logout')),
        matching: find.text(S.logout),
      ),
    );
    expect(rowText.style?.color, isNot(context.colors.error));

    await tapKey(tester, 'row-logout');
    expect(find.byKey(const ValueKey('logout-dialog')), findsOneWidget);
    expect(find.text(S.logoutConfirmTitle), findsOneWidget);
    expect(
      find.text(
        'Đăng xuất sẽ xóa dữ liệu trên máy này. Dữ liệu của Bạn vẫn được giữ '
        'trên hệ thống và sẽ khôi phục khi đăng nhập lại.',
      ),
      findsOneWidget,
    );
    final confirm = tester.widget<FilledButton>(
      find.byKey(const ValueKey('logout-confirm')),
    );
    expect(confirm.style?.backgroundColor?.resolve({}), context.colors.error);
    await tapKey(tester, 'logout-cancel');
    expect(find.byKey(const ValueKey('logout-dialog')), findsNothing);
    expect(find.byKey(const ValueKey('row-logout')), findsOneWidget);
    expect(finished, 0);
    expect(await flag.isPending(), isFalse);
    expect(server.calls('POST', '/v1/auth/logout'), isEmpty);
  });

  testWidgets('F27-AC2: tắt mạng → "Chưa đăng xuất được" / "Cần kết nối '
      'internet để đăng xuất." · "Đã hiểu", vẫn ở S-56 và vẫn đăng nhập', (
    tester,
  ) async {
    await pump(tester);
    net.setOnline(false);
    await tapKey(tester, 'row-logout');
    await tapKey(tester, 'logout-confirm');
    expect(find.byKey(const ValueKey('logout-syncing')), findsNothing);
    expect(find.byKey(const ValueKey('logout-failed')), findsOneWidget);
    expect(find.text(S.logoutFailedTitle), findsOneWidget);
    expect(find.text('Cần kết nối internet để đăng xuất.'), findsOneWidget);
    await tapKey(tester, 'logout-failed-ok');
    expect(find.byKey(const ValueKey('logout-failed')), findsNothing);
    expect(find.byKey(const ValueKey('row-logout')), findsOneWidget);
    expect(finished, 0);
    expect(server.calls('POST', '/v1/auth/logout'), isEmpty);
    expect(await container.read(sessionStoreProvider).read(), isNotNull);
  });

  testWidgets('F27-R3, UX-AC60: đồng bộ lỗi → "Đang đồng bộ…" rồi hộp lỗi '
      'nguyên văn, ở lại S-56, dữ liệu còn', (tester) async {
    await pump(tester);
    await twoUnsynced();
    final gate = Completer<void>();
    server.routes['POST /v1/sync/push'] = (_) async {
      await gate.future;
      return (
        500,
        {
          'error': {'code': 'internal_error'},
        },
      );
    };
    await tapKey(tester, 'row-logout');
    await tester.tap(find.byKey(const ValueKey('logout-confirm')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byKey(const ValueKey('logout-syncing')), findsOneWidget);
    gate.complete();
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('logout-syncing')), findsNothing);
    expect(
      find.text('Chưa đồng bộ xong, chưa đăng xuất được. Thử lại sau.'),
      findsOneWidget,
    );
    await tapKey(tester, 'logout-failed-ok');
    expect(find.byKey(const ValueKey('row-logout')), findsOneWidget);
    expect(await outboxCount(), 2);
    expect(finished, 0);
    expect(await flag.isPending(), isFalse);
    expect(server.calls('POST', '/v1/auth/logout'), isEmpty);
  });

  testWidgets('UX-AC60: 2 thay đổi chưa đồng bộ → "Đang đồng bộ…" không nút, '
      'chạm ngoài không đóng → đẩy đủ 2 → thu hồi phiên bằng refresh token của '
      'máy → bật cờ, giao gốc app; không thông báo nhanh', (tester) async {
    await pump(tester);
    await twoUnsynced();
    final gate = Completer<void>();
    var pushed = 0;
    server.routes['POST /v1/sync/push'] = (req) async {
      await gate.future;
      final mutations = (req.body! as Map)['mutations']! as List;
      pushed += mutations.length;
      return (
        200,
        {
          'results': [
            for (final m in mutations)
              {'mutationId': (m as Map)['mutationId'], 'status': 'applied'},
          ],
        },
      );
    };
    await tapKey(tester, 'row-logout');
    await tester.tap(find.byKey(const ValueKey('logout-confirm')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byKey(const ValueKey('logout-syncing')), findsOneWidget);
    expect(find.text(S.logoutSyncing), findsOneWidget);
    expect(
      find.text('Đồng bộ xong app mới đăng xuất. Đừng tắt mạng.'),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('logout-syncing')),
        matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
      ),
      findsNothing,
    );
    await tester.tapAt(const Offset(20, 20));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byKey(const ValueKey('logout-syncing')), findsOneWidget);

    gate.complete();
    // Gốc app giả không dựng lại app nên hộp "Đang đồng bộ…" còn quay.
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(pushed, 2);
    expect(await outboxCount(), 0);
    final revoke = server.calls('POST', '/v1/auth/logout').single;
    expect(
      (revoke.body! as Map)['refreshToken'],
      (await container.read(sessionStoreProvider).read())!.refreshToken,
    );
    expect(revoke.authorization, startsWith('Bearer '));
    expect(await flag.isPending(), isTrue);
    expect(finished, 1);
    expect(find.byType(SnackBar), findsNothing);
  });
}
