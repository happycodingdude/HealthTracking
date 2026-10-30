import 'package:api_contract/api_contract.dart';
import 'package:domain/domain.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/app/app.dart';
import 'package:mobile/app/strings_vi.dart';
import 'package:mobile/core/widgets/reference_tag.dart';
import 'package:mobile/data/db/app_database.dart';
import 'package:mobile/features/me/presentation/about_reference_screen.dart';
import 'package:mobile/features/me/presentation/calorie_screen.dart';
import 'package:mobile/features/menu/data/menu_repository.dart';
import 'package:mobile/ui/components/ironly_tab_bar.dart';

import '../support/app_harness.dart';
import '../support/fake_server.dart';
import '../support/fake_sync.dart';
import '../support/menu_fixture.dart';
import '../support/schedule_fixture.dart';

/// Rà soát Bản 1 (06 VS15-T01, T02, T04): nhãn "tham khảo" (F10-R2,
/// F10-AC2, UX-AC15), xem lại thông báo tham khảo (F10-R4), "Giảm chuyển
/// động" (04 §6.16).
void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));

  Future<void> pump(WidgetTester tester) async {
    tester.view
      ..physicalSize = const Size(390 * 3, 844 * 3)
      ..devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final container = ProviderContainer(
      retry: (_, _) => null,
      overrides: appOverrides(
        db: db,
        server: FakeServer(),
        scheduler: FakeScheduler(),
      ),
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const IronlyApp()),
    );
    await tester.pumpAndSettle();
  }

  Future<void> tab(WidgetTester tester, String label) async {
    await tester.tap(
      find.descendant(
        of: find.byType(IronlyTabBar),
        matching: find.text(label),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> reveal(WidgetTester tester, Finder f) async {
    if (f.evaluate().isEmpty) {
      await tester.scrollUntilVisible(
        f,
        200,
        scrollable: find.byType(Scrollable).first,
      );
    }
    await tester.ensureVisible(f);
    await tester.pumpAndSettle();
  }

  Finder tagIn(Finder parent) =>
      find.descendant(of: parent, matching: find.text(S.referenceTag));

  testWidgets('F10-R2, F10-AC2: nhãn "tham khảo" ở mức calo (S-52), thực đơn '
      '(S-30 đầu trang, tổng; thẻ ở Hôm nay), calo từng món có ghi chú "Calo '
      'món ăn là ước lượng."', (tester) async {
    await seedSetUp(db);
    await MenuRepository(db).put(LocalDate(2026, 10, 7), readyMenu());
    await MenuRepository(
      db,
    ).putUsage(AiDailyUsageCodec.key(LocalDate(2026, 10, 7)), 1);
    await pump(tester);

    // Bản 4 (BR4-15): thẻ thực đơn ở Hôm nay không còn nhãn "tham khảo".
    final card = find.byKey(const ValueKey('menu-line'));
    await reveal(tester, card);
    expect(tagIn(card), findsNothing);

    // Bản 4 (FR4-05): S-30 không còn nhãn "tham khảo" và câu ước lượng.
    await tab(tester, S.tabMenu);
    expect(find.text(S.referenceTag), findsNothing, reason: 'S-30');
    await reveal(tester, find.byKey(const ValueKey('menu-total')));
    expect(find.text(S.menuEstimateNote), findsNothing);

    await tab(tester, S.tabMe);
    await tester.tap(find.byKey(const ValueKey('row-calorie')));
    await tester.pumpAndSettle();
    // Bản 4 (FR4-05): S-52 không còn nhãn.
    expect(find.text(S.referenceTag), findsNothing, reason: 'S-52');
  });

  testWidgets('UX-AC15 (Bản 4, FR4-05): không còn nhãn "tham khảo" ở S-52; '
      '4 ý chính chỉ còn ở S-55', (tester) async {
    await seedSetUp(db);
    await pump(tester);
    await tab(tester, S.tabMe);
    await tester.tap(find.byKey(const ValueKey('row-calorie')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('reference-tag')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('page-back')));
    await tester.pumpAndSettle();
    final row = find.byKey(const ValueKey('row-about-reference'));
    await reveal(tester, row);
    await tester.tap(row);
    await tester.pumpAndSettle();
    expect(find.byType(AboutReferenceScreen), findsOneWidget);
    for (final point in DisclaimerPoints.points) {
      expect(find.text(point), findsOneWidget);
    }
  });

  testWidgets('F10-R4: tab Tôi có "Về gợi ý tham khảo" → S-55 (không có nút '
      '"Tôi đã hiểu"); quay lại về tab Tôi', (tester) async {
    await seedSetUp(db);
    await pump(tester);
    await tab(tester, S.tabMe);
    final row = find.byKey(const ValueKey('row-about-reference'));
    await reveal(tester, row);
    await tester.tap(row);
    await tester.pumpAndSettle();
    expect(find.byType(AboutReferenceScreen), findsOneWidget);
    expect(find.text(S.iUnderstand), findsNothing);
    await tester.tap(find.byIcon(Icons.chevron_left));
    await tester.pumpAndSettle();
    expect(row, findsOneWidget);
  });

  testWidgets('04 §6.16: bật "Giảm chuyển động" → mở trang con không có hiệu '
      'ứng trượt', (tester) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await seedSetUp(db);
    await pump(tester);
    await tab(tester, S.tabMe);
    await tester.tap(find.byKey(const ValueKey('row-calorie')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));
    expect(tester.getTopLeft(find.byType(CalorieScreen)).dx, 0);
  });

  testWidgets(
    'đối chứng: không bật "Giảm chuyển động" → sau 1 khung hình trang '
    'con còn đang trượt vào',
    (tester) async {
      await seedSetUp(db);
      await pump(tester);
      await tab(tester, S.tabMe);
      await tester.tap(find.byKey(const ValueKey('row-calorie')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));
      expect(tester.getTopLeft(find.byType(CalorieScreen)).dx, greaterThan(0));
      await tester.pumpAndSettle();
    },
  );
}
