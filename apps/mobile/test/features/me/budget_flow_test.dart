import 'dart:convert';

import 'package:api_contract/api_contract.dart';
import 'package:domain/domain.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/app/app.dart';
import 'package:mobile/app/shell/app_tab_bar.dart';
import 'package:mobile/app/strings_vi.dart';
import 'package:mobile/app/theme.dart';
import 'package:mobile/data/db/app_database.dart';

import '../../support/app_harness.dart';
import '../../support/fake_server.dart';
import '../../support/fake_sync.dart';
import '../../support/menu_fixture.dart';
import '../../support/schedule_fixture.dart';

void main() {
  late AppDatabase db;
  late FakeServer server;
  late FakeMenuServer menus;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    server = FakeServer();
    menus = FakeMenuServer(server);
  });

  Future<void> pump(WidgetTester tester) async {
    tester.view
      ..physicalSize = const Size(390 * 3, 844 * 3)
      ..devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final container = ProviderContainer(
      retry: (_, _) => null,
      overrides: appOverrides(
        db: db,
        server: server,
        scheduler: FakeScheduler(),
      ),
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const IronlyApp()),
    );
    await tester.pumpAndSettle();
  }

  Future<void> tapTab(WidgetTester tester, String label) async {
    await tester.tap(
      find.descendant(of: find.byType(AppTabBar), matching: find.text(label)),
    );
    await tester.pumpAndSettle();
  }

  Future<void> tapKey(WidgetTester tester, String key) async {
    final f = find.byKey(ValueKey(key));
    await tester.ensureVisible(f);
    await tester.pumpAndSettle();
    await tester.tap(f);
    await tester.pumpAndSettle();
  }

  Future<void> budget(
    num used, {
    String month = '2026-10',
    bool blocked = false,
  }) => (db.update(db.syncState)..where((s) => s.id.equals(1))).write(
    SyncStateCompanion(
      aiBudget: Value(
        jsonEncode(
          AiBudgetMeta(
            month: YearMonth.parse(month),
            usedVnd: used,
            capVnd: 50000,
            blocked: blocked,
          ).toJson(),
        ),
      ),
    ),
  );

  testWidgets('04 S-50: "Ngân sách AI" "12.500đ / 50.000đ" kèm thanh nhỏ; chạm '
      '→ S-54 "12.500đ", "trên 50.000đ của tháng 10", "25%", "Đặt lại vào '
      '01/11", giải thích; không có ô sửa mức trần (F11-R7)', (tester) async {
    await seedSetUp(db);
    await budget(12500);
    await pump(tester);
    await tapTab(tester, S.tabMe);
    expect(find.text('12.500đ / 50.000đ'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('row-budget')),
        matching: find.byType(LinearProgressIndicator),
      ),
      findsOneWidget,
    );
    await tapKey(tester, 'row-budget');
    expect(find.text(S.aiBudget), findsOneWidget);
    expect(find.text('12.500đ'), findsOneWidget);
    expect(find.text('trên 50.000đ của tháng 10'), findsOneWidget);
    expect(find.text('25%'), findsOneWidget);
    expect(find.text('Đặt lại vào 01/11'), findsOneWidget);
    expect(find.text(S.budgetExplain), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
    final bar = tester.widget<LinearProgressIndicator>(
      find.byType(LinearProgressIndicator),
    );
    expect(bar.value, 0.25);
    expect(
      bar.color,
      Theme.of(tester.element(find.text('25%'))).colorScheme.primary,
    );
  });

  testWidgets(
    '04 S-54: từ 80% đổi màu cảnh báo; đã chạm trần thêm câu F08-E2',
    (tester) async {
      await seedSetUp(db);
      await budget(40000);
      await pump(tester);
      await tapTab(tester, S.tabMe);
      await tapKey(tester, 'row-budget');
      final context = tester.element(find.text('80%'));
      expect(
        tester
            .widget<LinearProgressIndicator>(
              find.byType(LinearProgressIndicator),
            )
            .color,
        context.palette.attention,
      );
      expect(find.byKey(const ValueKey('budget-blocked')), findsNothing);
      await budget(49700, blocked: true);
      await tester.pumpAndSettle();
      expect(find.text('99%'), findsOneWidget);
      expect(
        find.text(
          'Gợi ý AI tạm dừng đến ngày 1/11 vì đã dùng hết ngân sách tháng này.',
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets('F11-E2: số liệu của tháng trước (chưa đồng bộ tháng mới) → '
      'tháng này 0đ, không bị chặn', (tester) async {
    await seedSetUp(db);
    await budget(49700, month: '2026-09', blocked: true);
    await pump(tester);
    await tapTab(tester, S.tabMe);
    expect(find.text('0đ / 50.000đ'), findsOneWidget);
    await tapKey(tester, 'row-budget');
    expect(find.text('0%'), findsOneWidget);
    expect(find.byKey(const ValueKey('budget-blocked')), findsNothing);
  });

  testWidgets('F11-R4, F11-AC2: lần tạo làm chi phí đạt 80% → hộp "Bạn đã dùng '
      '80% ngân sách AI tháng này." một lần; "Đã hiểu" đóng; lần sau không hiện '
      'lại; "Xem chi tiết" → S-54', (tester) async {
    await seedSetUp(db);
    menus.warn80 = true;
    await pump(tester);
    await tapTab(tester, S.tabMenu);
    await tapKey(tester, 'generate-menu');
    expect(find.text(S.budgetWarning80), findsOneWidget);
    expect(find.text(S.understood), findsOneWidget);
    expect(find.text(S.seeDetails), findsOneWidget);
    await tapKey(tester, 'budget-warning-ok');
    expect(find.text(S.budgetWarning80), findsNothing);

    // Server chỉ gửi cờ một lần trong tháng.
    menus.warn80 = false;
    final regenerate = find.byKey(const ValueKey('regenerate'));
    await tester.scrollUntilVisible(
      regenerate,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tapKey(tester, 'regenerate');
    await tapKey(tester, 'confirm-regenerate');
    expect(find.text(S.budgetWarning80), findsNothing);
  });

  testWidgets('hộp báo 80%: "Xem chi tiết" → S-54', (tester) async {
    await seedSetUp(db);
    menus.warn80 = true;
    await budget(40100);
    await pump(tester);
    await tapTab(tester, S.tabMenu);
    await tapKey(tester, 'generate-menu');
    await tapKey(tester, 'budget-warning-details');
    expect(find.text(S.budgetWarning80), findsNothing);
    expect(find.text('trên 50.000đ của tháng 10'), findsOneWidget);
  });
}
