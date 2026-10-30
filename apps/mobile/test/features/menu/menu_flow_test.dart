import 'dart:async';
import 'dart:convert';

import 'package:api_contract/api_contract.dart';
import 'package:domain/domain.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/app/app.dart';
import 'package:mobile/app/strings_vi.dart';
import 'package:mobile/data/db/app_database.dart';
import 'package:mobile/features/me/data/profile_repository.dart';
import 'package:mobile/features/menu/data/menu_repository.dart';
import 'package:mobile/ui/components/ironly_button.dart';
import 'package:mobile/ui/components/ironly_tab_bar.dart';

import '../../support/app_harness.dart';
import '../../support/fake_server.dart';
import '../../support/fake_sync.dart';
import '../../support/menu_fixture.dart';
import '../../support/schedule_fixture.dart';

void main() {
  late AppDatabase db;
  late FakeServer server;
  late FakeMenuServer menus;
  late FakeConnectivity connectivity;
  late FakeScheduler scheduler;
  final today = LocalDate(2026, 10, 7);

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    server = FakeServer();
    menus = FakeMenuServer(server);
    connectivity = FakeConnectivity();
    scheduler = FakeScheduler();
  });

  /// Kcal ngày ở góc phải tiêu đề S-30 (Bản 4: không còn "Theo mức").
  Finder dateLine(String kcal) => find.byWidgetPredicate(
    (w) =>
        w is Text &&
        w.key == const ValueKey('menu-date-line') &&
        w.data == kcal,
  );

  Future<void> pump(WidgetTester tester, {bool openMenu = true}) async {
    tester.view
      ..physicalSize = const Size(390 * 3, 844 * 3)
      ..devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final container = ProviderContainer(
      retry: (_, _) => null,
      overrides: appOverrides(
        db: db,
        server: server,
        connectivity: connectivity,
        scheduler: scheduler,
      ),
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const IronlyApp()),
    );
    await tester.pumpAndSettle();
    if (openMenu) await tapTab(tester, S.tabMenu);
  }

  /// S-30 dựng lười: cuộn tới [f] khi nó chưa được dựng.
  Future<void> reveal(WidgetTester tester, Finder f) async {
    if (f.evaluate().isEmpty) {
      // Về đầu trang rồi cuộn xuống tới khi thấy.
      final scrollable = find.byType(Scrollable).first;
      tester.state<ScrollableState>(scrollable).position.jumpTo(0);
      await tester.pump();
      if (f.evaluate().isEmpty) {
        await tester.scrollUntilVisible(f, 200, scrollable: scrollable);
      }
    }
    await tester.ensureVisible(f);
    await tester.pumpAndSettle();
  }

  Future<void> tapFinder(WidgetTester tester, Finder f) async {
    await reveal(tester, f);
    await tester.pumpAndSettle();
    await tester.tap(f);
    await tester.pumpAndSettle();
  }

  Future<void> tapKey(WidgetTester tester, String key) =>
      tapFinder(tester, find.byKey(ValueKey(key)));

  Future<void> tapText(WidgetTester tester, String text) =>
      tapFinder(tester, find.text(text).last);

  Future<void> putMenu(MenuData m, {int used = 1}) async {
    final repo = MenuRepository(db);
    await repo.put(today, m);
    await repo.putUsage(AiDailyUsageCodec.key(today), used);
  }

  testWidgets('F08-AC1, 04 Bản 4 S-30 Trống: chưa bấm thì không tạo; chỉ icon '
      'bát + nút "Gợi ý thực đơn" + "Còn 3 lượt"; trên: "THỨ 4, 07/10" · '
      '"Thực đơn" · "2.210 kcal"; không câu, không nhãn (FR4-04, FR4-05)', (
    tester,
  ) async {
    await seedSetUp(db);
    await pump(tester);
    expect(find.text(S.menuEmptyTitle), findsNothing);
    expect(find.text(S.menuEmptyBody), findsNothing);
    expect(find.text(S.generateMenuShort), findsOneWidget);
    expect(find.text(S.remainingShort(3)), findsOneWidget);
    expect(find.text('THỨ 4, 07/10'), findsOneWidget);
    expect(dateLine('2.210 kcal'), findsOneWidget);
    expect(find.text(S.referenceTag), findsNothing);
    expect(menus.calls, isEmpty);
  });

  testWidgets('F08-AC4, F08-AC7: bấm "Gợi ý thực đơn" → đang tạo → các bữa '
      'theo thứ tự, mỗi món tên, khẩu phần, số kcal; tổng chỉ đọc bằng '
      'VoiceOver; "Gợi ý lại · 2"; Bản 4: không nhãn, không câu ước lượng', (
    tester,
  ) async {
    await seedSetUp(db);
    final gate = menus.gate = Completer<void>();
    await pump(tester);
    await tester.tap(find.byKey(const ValueKey('generate-menu')));
    await tester.pump();
    expect(find.text(S.menuGenerating), findsOneWidget);
    expect(find.byKey(const ValueKey('menu-generating')), findsOneWidget);
    expect(find.byKey(const ValueKey('generate-menu')), findsNothing);
    gate.complete();
    await tester.pumpAndSettle();

    final body = menus.calls.single.body! as Map;
    expect(body['localDate'], '2026-10-07');
    expect(body['targetKcal'], 2210);
    expect(body['requestId'], matches(RegExp(r'^[0-9a-f-]{36}$')));

    final labels = [
      S.mealBreakfast,
      S.mealMorningSnack,
      S.mealLunch,
      S.mealAfternoonSnack,
      S.mealDinner,
    ];
    // Bản 4: tiêu đề bữa in hoa.
    final ys = [
      for (final l in labels) tester.getTopLeft(find.text(l.toUpperCase())).dy,
    ];
    expect(ys, [...ys]..sort(), reason: 'thứ tự bữa trong ngày (mock S-30-3)');
    expect(find.text('Phở gà'), findsOneWidget);
    expect(find.text('1 tô'), findsWidgets);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('dish-Phở gà')),
        matching: find.text('480'),
      ),
      findsOneWidget,
    );
    expect(find.text('560 kcal'), findsOneWidget, reason: 'calo bữa sáng');
    await reveal(tester, find.byKey(const ValueKey('regenerate')));
    expect(find.bySemanticsLabel(RegExp('^Tổng: 2.020 kcal')), findsOneWidget);
    expect(find.text(S.referenceTag), findsNothing);
    expect(find.text(S.menuEstimateNote), findsNothing);
    expect(find.text(S.regenerateShort(2)), findsOneWidget);
    expect(
      (await MenuRepository(db).get(today))!.payload,
      mockMenu,
      reason: 'ghi vào máy',
    );
  });

  testWidgets('UA-10: "Gợi ý lại" → hộp "Gợi ý thực đơn mới?" "… Còn 2 lượt '
      'hôm nay."; Hủy → không tạo; Gợi ý lại → tạo, còn 1 lượt', (
    tester,
  ) async {
    await seedSetUp(db);
    await putMenu(readyMenu());
    menus.successes = 1;
    await pump(tester);
    await tapKey(tester, 'regenerate');
    expect(find.text(S.regenerateTitle), findsOneWidget);
    expect(
      find.text(
        'Thực đơn hiện tại sẽ được thay bằng thực đơn mới. Còn 2 lượt hôm nay.',
      ),
      findsOneWidget,
    );
    await tapText(tester, S.cancel);
    expect(menus.calls, isEmpty);
    await tapKey(tester, 'regenerate');
    await tapKey(tester, 'confirm-regenerate');
    expect(menus.calls, hasLength(1));
    await reveal(tester, find.text(S.regenerateShort(1)));
  });

  testWidgets('F08-AC2, F08-E3: hết 3 lượt → nút gợi ý lại thay bằng "Bạn đã '
      'dùng hết 3 lượt hôm nay.", thực đơn vẫn xem được', (tester) async {
    await seedSetUp(db);
    await putMenu(readyMenu(), used: 3);
    await pump(tester);
    expect(find.text('Phở gà'), findsOneWidget);
    await reveal(tester, find.byKey(const ValueKey('menu-exhausted')));
    expect(find.text(S.menuQuotaExhausted), findsOneWidget);
    expect(find.byKey(const ValueKey('regenerate')), findsNothing);
  });

  testWidgets('F08-AC3, F08-R11: mở lại tab thực đơn → thấy thực đơn cũ, không '
      'gọi server', (tester) async {
    await seedSetUp(db);
    await putMenu(readyMenu());
    await pump(tester);
    expect(find.text('Phở gà'), findsOneWidget);
    expect(menus.calls, isEmpty);
    expect(server.calls('GET', '/v1/ai/menus/2026-10-07'), isEmpty);
  });

  testWidgets('F08-AC6, F08-E1: không có mạng → "Cần kết nối internet để gợi ý '
      'thực đơn.", nút "Thử lại", lượt không đổi, không gọi server; có mạng → '
      '"Thử lại" tạo được', (tester) async {
    await seedSetUp(db);
    connectivity.online = false;
    await pump(tester);
    await tapKey(tester, 'generate-menu');
    expect(find.text(S.offlineMenu), findsOneWidget);
    expect(find.text(S.retry), findsOneWidget);
    expect(find.text(S.remainingShort(3)), findsOneWidget);
    expect(menus.calls, isEmpty);

    // Mạng chập chờn: kết nối báo có nhưng không tới được server.
    connectivity.online = true;
    server.offline = true;
    await tapKey(tester, 'generate-menu');
    expect(find.text(S.offlineMenu), findsOneWidget);

    server.offline = false;
    await tapKey(tester, 'generate-menu');
    expect(find.text(S.offlineMenu), findsNothing);
    expect(find.text('Phở gà'), findsOneWidget);
  });

  testWidgets('F08-E2, F11-R5: chạm trần → "Gợi ý AI tạm dừng đến ngày 1/11 vì '
      'đã dùng hết ngân sách tháng này.", không bấm tạo được nữa', (
    tester,
  ) async {
    await seedSetUp(db);
    menus.results.add((429, errorBody(ErrorCode.budgetExhausted)));
    await pump(tester);
    await tapKey(tester, 'generate-menu');
    expect(
      find.text(
        'Gợi ý AI tạm dừng đến ngày 1/11 vì đã dùng hết ngân sách tháng này.',
      ),
      findsOneWidget,
    );
    // Nút mờ, không bấm được (F4-R6).
    expect(find.text(S.generateMenuShort), findsOneWidget);
    expect(
      tester
          .widget<IronlyButton>(
            find.ancestor(
              of: find.text(S.generateMenuShort),
              matching: find.byType(IronlyButton),
            ),
          )
          .enabled,
      isFalse,
    );
  });

  testWidgets('ED-04: pull báo tháng đã bị chặn → banner F08-E2 ngay khi mở '
      'tab, tháng cũ bị chặn thì không', (tester) async {
    await seedSetUp(db);
    Future<void> budget(String month) =>
        (db.update(db.syncState)..where((s) => s.id.equals(1))).write(
          SyncStateCompanion(
            aiBudget: Value(
              jsonEncode(
                AiBudgetMeta(
                  month: YearMonth.parse(month),
                  usedVnd: 49800,
                  capVnd: 50000,
                  blocked: true,
                ).toJson(),
              ),
            ),
          ),
        );
    await budget('2026-09');
    await pump(tester);
    expect(find.byKey(const ValueKey('menu-banner-budget')), findsNothing);
    await budget('2026-10');
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('menu-banner-budget')), findsOneWidget);
  });

  testWidgets('F08-E4, TAC-13: thực đơn vừa tạo không hợp lệ → "Thực đơn vừa '
      'tạo chưa đạt yêu cầu. Thử lại." kèm "Thử lại", thực đơn cũ vẫn hiện, '
      'lượt không đổi', (tester) async {
    await seedSetUp(db);
    await putMenu(readyMenu());
    menus.successes = 1;
    menus.results.add((502, errorBody(ErrorCode.aiInvalidOutput)));
    await pump(tester);
    await tapKey(tester, 'regenerate');
    await tapKey(tester, 'confirm-regenerate');
    await reveal(tester, find.text(S.menuInvalidOutput));
    expect(find.text('Phở gà'), findsOneWidget);
    await reveal(tester, find.text(S.regenerateShort(2)));
    await tapKey(tester, 'banner-retry');
    expect(menus.calls, hasLength(2));
    expect(find.text(S.menuInvalidOutput), findsNothing);
    await reveal(tester, find.text(S.regenerateShort(1)));
  });

  testWidgets('04 S-30 lỗi khác: "Chưa tạo được thực đơn. Thử lại." và nút '
      '"Thử lại"', (tester) async {
    await seedSetUp(db);
    menus.results.add((502, errorBody(ErrorCode.aiProviderError)));
    await pump(tester);
    await tapKey(tester, 'generate-menu');
    expect(find.text(S.menuProviderError), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('generate-menu')),
        matching: find.text(S.retry),
      ),
      findsOneWidget,
    );
  });

  testWidgets(
    'F08-AC5, F08-R9: Bạn tự đặt 1.300 (nam) → "Theo mức 1.500 kcal", '
    '"Thực đơn dùng mức an toàn tối thiểu 1.500 kcal."',
    (tester) async {
      await seedSetUp(
        db,
        profile: completedProfile(mode: CalorieMode.manual, kcal: 1300),
      );
      await pump(tester);
      expect(dateLine('1.500 kcal'), findsOneWidget);
      expect(
        find.text('Thực đơn dùng mức an toàn tối thiểu 1.500 kcal.'),
        findsOneWidget,
      );
      await tapKey(tester, 'generate-menu');
      expect((menus.calls.single.body! as Map)['targetKcal'], 1300);
      expect(
        find.text('Thực đơn dùng mức an toàn tối thiểu 1.500 kcal.'),
        findsOneWidget,
      );
    },
  );

  testWidgets('F08-R10: mức calo đổi sau khi đã có thực đơn → thực đơn giữ '
      'nguyên, banner "Mức calo đã thay đổi. Bạn có thể gợi ý lại."', (
    tester,
  ) async {
    await seedSetUp(db);
    await putMenu(readyMenu());
    await pump(tester);
    expect(find.text(S.calorieChangedRegenerate), findsNothing);
    await ProfileRepository(
      db,
    ).put(completedProfile(mode: CalorieMode.manual, kcal: 2000));
    await tester.pumpAndSettle();
    expect(find.text(S.calorieChangedRegenerate), findsOneWidget);
    expect(dateLine('2.210 kcal'), findsOneWidget);
    expect(find.text('Phở gà'), findsOneWidget);
  });

  testWidgets(
    'F08-E5: rời app khi đang tạo, mở lại → "Đang lên thực đơn…", hỏi '
    'trạng thái mỗi 3 giây đến khi có kết quả',
    (tester) async {
      await seedSetUp(db);
      await MenuRepository(db).put(
        today,
        const MenuData(
          payload: null,
          targetKcal: 2210,
          usedSafetyFloor: false,
          totalKcal: null,
          lastAttemptStatus: MenuAttemptStatus.generating,
        ),
      );
      var ready = false;
      server.on(
        'GET',
        '/v1/ai/menus/2026-10-07',
        (_) => (
          200,
          MenuStatusResponse(
            date: today,
            menu: ready
                ? readyMenu()
                : const MenuData(
                    payload: null,
                    targetKcal: 2210,
                    usedSafetyFloor: false,
                    totalKcal: null,
                    lastAttemptStatus: MenuAttemptStatus.generating,
                  ),
            remaining: ready ? 2 : 3,
          ).toJson(),
        ),
      );
      await pump(tester);
      expect(find.text(S.menuGenerating), findsOneWidget);
      expect(scheduler.pendingDelays, contains(const Duration(seconds: 3)));
      scheduler.fireSync(delay: const Duration(seconds: 3));
      await tester.pumpAndSettle();
      expect(find.text(S.menuGenerating), findsOneWidget);
      ready = true;
      scheduler.fireSync(delay: const Duration(seconds: 3));
      await tester.pumpAndSettle();
      expect(find.text('Phở gà'), findsOneWidget);
      expect(server.calls('GET', '/v1/ai/menus/2026-10-07'), hasLength(2));
      expect(
        scheduler.pendingDelays,
        isNot(contains(const Duration(seconds: 3))),
      );
    },
  );

  // Bản 4 (04 S-10 H2): thẻ thực đơn đầy đủ chỉ ở ngày không có buổi → thứ 4
  // 07/10 là ngày nghỉ.
  group('04 §6.7.4: thẻ thực đơn ở Hôm nay', () {
    Finder card() => find.byKey(const ValueKey('menu-card'));

    Future<void> scrollToCard(WidgetTester tester) async {
      await tester.scrollUntilVisible(
        card(),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
    }

    testWidgets('chưa có thực đơn: "Theo mức 2.210 kcal" + nhãn + "Gợi ý thực '
        'đơn hôm nay" → tạo và chuyển sang tab Thực đơn', (tester) async {
      await seedSetUp(db, template: templateRestWed);
      await pump(tester, openMenu: false);
      await scrollToCard(tester);
      // FR4-05: không nhãn "tham khảo"; thẻ chỉ còn nút "Gợi ý thực đơn".
      expect(
        find.descendant(of: card(), matching: find.text(S.referenceTag)),
        findsNothing,
      );
      expect(
        find.descendant(of: card(), matching: find.text(S.generateMenuShort)),
        findsOneWidget,
      );
      await tapKey(tester, 'menu-card-generate');
      expect(menus.calls, hasLength(1));
      expect(find.text(S.menuEmptyTitle), findsNothing);
      expect(find.text('Phở gà'), findsOneWidget, reason: 'đang ở S-30');
      await reveal(tester, find.byKey(const ValueKey('regenerate')));
    });

    testWidgets('UR-15: có thực đơn → mỗi bữa một dòng (tên bữa · các món), '
        'tổng kcal + nhãn; chạm → tab Thực đơn', (tester) async {
      await seedSetUp(db, template: templateRestWed);
      await putMenu(readyMenu());
      await pump(tester, openMenu: false);
      await scrollToCard(tester);
      expect(
        find.descendant(
          of: card(),
          matching: find.text('Cơm gạo lứt, Cá basa kho tộ, Canh rau muống'),
        ),
        findsOneWidget,
      );
      // Bản 4: chỉ ba dòng Sáng / Trưa / Tối, bữa phụ xem ở S-30.
      expect(
        find.descendant(of: card(), matching: find.text(S.mealMorningSnack)),
        findsNothing,
      );
      expect(find.byKey(const ValueKey('menu-card-total')), findsOneWidget);
      await tapFinder(tester, card());
      await reveal(tester, find.byKey(const ValueKey('regenerate')));
    });

    testWidgets('không có mạng sau lần bấm, hết lượt, chạm trần → một dòng lý '
        'do', (tester) async {
      await seedSetUp(db, template: templateRestWed);
      connectivity.online = false;
      await pump(tester, openMenu: false);
      await scrollToCard(tester);
      await tapKey(tester, 'menu-card-generate');
      await tapTab(tester, S.tabToday);
      await scrollToCard(tester);
      expect(
        find.descendant(of: card(), matching: find.text(S.offlineMenu)),
        findsOneWidget,
      );
    });
  });
}

Future<void> tapTab(WidgetTester tester, String label) async {
  await tester.tap(
    find.descendant(of: find.byType(IronlyTabBar), matching: find.text(label)),
  );
  await tester.pumpAndSettle();
}
