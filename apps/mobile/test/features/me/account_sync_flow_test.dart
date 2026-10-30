import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/app/app.dart';
import 'package:mobile/app/strings_vi.dart';
import 'package:mobile/core/widgets/labeled_field.dart';
import 'package:mobile/data/db/app_database.dart';
import 'package:mobile/features/me/data/account_repository.dart';
import 'package:mobile/ui/components/ironly_tab_bar.dart';

import '../../support/app_harness.dart';
import '../../support/fake_server.dart';

void main() {
  late FakeServer server;
  late FakeConnectivity net;
  late AppDatabase db;

  setUp(() {
    server = FakeServer();
    net = FakeConnectivity();
    db = AppDatabase(NativeDatabase.memory());
  });

  Future<void> pump(WidgetTester tester) async {
    tester.view
      ..physicalSize = const Size(390 * 3, 844 * 3)
      ..devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await AccountRepository(db).put('Minh');
    final container = ProviderContainer(
      retry: (_, _) => null,
      overrides: appOverrides(server: server, connectivity: net, db: db),
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const IronlyApp()),
    );
    await tester.pumpAndSettle();
  }

  Future<void> openAccount(WidgetTester tester) async {
    await tester.tap(
      find.descendant(
        of: find.byType(IronlyTabBar),
        matching: find.text(S.tabMe),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('row-account-data')));
    await tester.pumpAndSettle();
  }

  Future<void> rename(WidgetTester tester, String name) async {
    await tester.tap(find.byKey(const ValueKey('row-display-name')));
    await tester.pumpAndSettle();
    final field = find.descendant(
      of: find.byWidgetPredicate(
        (w) => w is LabeledField && w.label == S.fieldDisplayName,
      ),
      matching: find.byType(TextField),
    );
    await tester.enterText(field, name);
    await tester.tap(find.widgetWithText(FilledButton, S.save));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'UX-AC22: Hôm nay hiện "Chào {tên hiển thị} · Thứ 4, 07/10"; đã đồng bộ thì không có chỉ báo',
    (tester) async {
      await pump(tester);
      expect(find.text('Chào Minh · Thứ 4, 07/10'), findsOneWidget);
      expect(find.byKey(const ValueKey('sync-indicator')), findsNothing);
    },
  );

  testWidgets(
    'S-56: tên, số điện thoại, "Đã đồng bộ lúc 18:42"; tab Tôi "Đã đồng bộ"',
    (tester) async {
      await pump(tester);
      await tester.tap(
        find.descendant(
          of: find.byType(IronlyTabBar),
          matching: find.text(S.tabMe),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text(S.syncDone), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('row-account-data')));
      await tester.pumpAndSettle();
      expect(find.text('Minh'), findsOneWidget);
      expect(find.text('0912 345 678'), findsOneWidget);
      expect(find.text(S.syncedAt('18:42')), findsOneWidget);
      expect(find.text(S.syncLossWarning), findsNothing);
      expect(
        find.byType(IronlyTabBar),
        findsOneWidget,
        reason: 'S-56 nằm trong tab Tôi',
      );
    },
  );

  testWidgets(
    'Q-2: sửa tên chưa lưu → chạm vùng mờ hỏi "Bỏ các thay đổi chưa lưu?"; '
    'chưa sửa gì thì đóng ngay',
    (tester) async {
      await pump(tester);
      await openAccount(tester);
      await tester.tap(find.byKey(const ValueKey('row-display-name')));
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(195, 60));
      await tester.pumpAndSettle();
      expect(find.text(S.discardChangesTitle), findsNothing);
      expect(find.widgetWithText(FilledButton, S.save), findsNothing);

      await tester.tap(find.byKey(const ValueKey('row-display-name')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.descendant(
          of: find.byWidgetPredicate(
            (w) => w is LabeledField && w.label == S.fieldDisplayName,
          ),
          matching: find.byType(TextField),
        ),
        'Minh Anh',
      );
      await tester.pump();
      await tester.tapAt(const Offset(195, 60));
      await tester.pumpAndSettle();
      expect(find.text(S.discardChangesTitle), findsOneWidget);
      await tester.tap(find.text(S.discard));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(FilledButton, S.save), findsNothing);
      expect(await db.select(db.outbox).get(), isEmpty);
      expect(find.text('Minh'), findsOneWidget);
    },
  );

  testWidgets('UA-21: tên sai → báo lỗi dưới ô, không lưu', (tester) async {
    await pump(tester);
    await openAccount(tester);
    await rename(tester, '   ');
    expect(find.text(S.invalidDisplayName), findsOneWidget);
    expect(await db.select(db.outbox).get(), isEmpty);
  });

  testWidgets(
    'Demo VS-02 / TAC-01 / UX-AC16 / F09-AC2: đổi tên khi không có mạng → hiện ngay, "Chưa đồng bộ"; có mạng lại → đồng bộ, chỉ báo biến mất',
    (tester) async {
      await pump(tester);
      await openAccount(tester);
      server.offline = true;
      net.setOnline(false);
      final before = server.requests.length;

      await rename(tester, 'Minh Anh');

      // Cập nhật ngay, không có lời gọi mạng nào trước khi giao diện đổi (TAC-01).
      expect(find.text('Minh Anh'), findsOneWidget);
      expect(server.requests.length, before);
      expect(find.text(S.syncPendingDetail), findsOneWidget);
      expect(find.text(S.syncLossWarning), findsOneWidget);

      await tester.tap(find.byIcon(Icons.chevron_left));
      await tester.pumpAndSettle();
      expect(find.text(S.syncPending), findsOneWidget, reason: 'dòng S-50');

      await tester.tap(find.byKey(const ValueKey('tab-today-button')));
      await tester.pumpAndSettle();
      expect(find.text('Chào Minh Anh · Thứ 4, 07/10'), findsOneWidget);
      expect(find.byKey(const ValueKey('sync-indicator')), findsOneWidget);

      // Có mạng trở lại.
      server.offline = false;
      net.setOnline(true);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('sync-indicator')), findsNothing);
      final pushed = server.calls('POST', '/v1/sync/push').last.body! as Map;
      expect(((pushed['mutations']! as List).single as Map)['data'], {
        'displayName': 'Minh Anh',
      });
      expect(await db.select(db.outbox).get(), isEmpty);
    },
  );
}
