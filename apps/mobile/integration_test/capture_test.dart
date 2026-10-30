// Chụp màn hình cho bộ ảnh so sánh (06 Bản 4 ED4-04, VS43-T11). Chạy bằng
// tool/capture_screens.sh <M17…M21> qua `flutter drive` trên simulator; ảnh
// vào build/review/<id>.png. Dữ liệu là fixture trong bộ nhớ (như golden),
// không cần server.
import 'package:api_contract/api_contract.dart';
import 'package:domain/domain.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mobile/app/app.dart';
import 'package:mobile/app/router.dart';
import 'package:mobile/data/db/app_database.dart';
import 'package:mobile/dev/review_matrix.dart';
import 'package:mobile/features/me/data/account_repository.dart';
import 'package:mobile/features/me/data/profile_repository.dart';
import 'package:mobile/features/menu/data/menu_repository.dart';
import 'package:mobile/ui/gallery.dart';
import 'package:mobile/ui/theme.dart';

import '../test/support/app_harness.dart';
import '../test/support/schedule_fixture.dart';
import 'capture_fixtures.dart';

const _milestone = String.fromEnvironment(
  'CAPTURE_MILESTONE',
  defaultValue: 'M17',
);

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  final milestone = Milestone.values.firstWhere(
    (m) => m.name.toUpperCase() == _milestone.toUpperCase(),
  );

  Future<void> shot(WidgetTester tester, String id) async {
    // Vòng xoay vô hạn (nút loading) → không pumpAndSettle.
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await binding.takeScreenshot(id);
  }

  Future<void> pumpApp(WidgetTester tester, Widget child) async {
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: IronlyTheme.dark(),
        darkTheme: IronlyTheme.dark(),
        themeMode: ThemeMode.dark,
        home: child,
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));
  }

  group(_milestone, () {
    if (milestone == Milestone.m17) {
      testWidgets('M17: trang thành phần', (tester) async {
        await pumpApp(tester, const ComponentGallery(showBack: false));
        await tester.pump(const Duration(seconds: 1));
        await shot(tester, 'm17_components_1');
        await tester.drag(
          find.byKey(const ValueKey('gallery-list')),
          const Offset(0, -700),
        );
        await shot(tester, 'm17_components_2');
        await tester.drag(
          find.byKey(const ValueKey('gallery-list')),
          const Offset(0, -700),
        );
        await shot(tester, 'm17_glyphs');
        await tester.scrollUntilVisible(
          find.text('Open dialog'),
          300,
          scrollable: find.descendant(
            of: find.byKey(const ValueKey('gallery-list')),
            matching: find.byType(Scrollable),
          ),
        );
        await tester.pump(const Duration(milliseconds: 300));
        await tester.tap(find.text('Open dialog'));
        await shot(tester, 'm17_dialog');
        await tester.tapAt(const Offset(10, 10));
        await tester.pump(const Duration(milliseconds: 500));
        await tester.tap(find.text('Open sheet'));
        await shot(tester, 'm17_sheet');
      });
    }
    if (milestone == Milestone.m18) {
      Future<ProviderContainer> pump(
        WidgetTester tester,
        AppDatabase db,
        DateTime now,
      ) async {
        final container = ProviderContainer(
          retry: (_, _) => null,
          overrides: appOverrides(db: db, clock: FixedClock(now)),
        );
        addTearDown(container.dispose);
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const IronlyApp(),
          ),
        );
        await tester.pumpAndSettle();
        return container;
      }

      Future<void> go(
        WidgetTester tester,
        ProviderContainer c,
        String path,
      ) async {
        c.read(routerProvider).go(path);
        await tester.pumpAndSettle();
      }

      Future<void> tapKey(WidgetTester tester, String key) async {
        final f = find.byKey(ValueKey(key), skipOffstage: false);
        if (f.evaluate().isEmpty ||
            find.byKey(ValueKey(key)).evaluate().isEmpty) {
          await tester.scrollUntilVisible(
            find.byKey(ValueKey(key), skipOffstage: false),
            -300,
            scrollable: find.byType(Scrollable).first,
          );
        }
        await tester.ensureVisible(
          find.byKey(ValueKey(key), skipOffstage: false),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(ValueKey(key)));
        await tester.pumpAndSettle();
      }

      Future<void> toTop(WidgetTester tester) async {
        await tester.drag(find.byType(Scrollable).first, const Offset(0, 3000));
        await tester.pumpAndSettle();
      }

      testWidgets('M18: Hôm nay H4, S-64, S-65, S-23', (tester) async {
        final db = AppDatabase(NativeDatabase.memory());
        addTearDown(db.close);
        await seedCapture(db);
        final c = await pump(tester, db, DateTime(2026, 10, 26, 18, 5));
        await shot(tester, 'm18_s10_logging');
        await tapKey(tester, 'lift-row-chest-3');
        await tapKey(tester, 'lift-end-plus');
        FocusManager.instance.primaryFocus?.unfocus();
        await tester.pumpAndSettle();
        await shot(tester, 'm18_s64_prefill');
        await tester.tapAt(const Offset(20, 20));
        await tester.pumpAndSettle();
        if (find
            .byKey(const ValueKey('discard-confirm'))
            .evaluate()
            .isNotEmpty) {
          await tapKey(tester, 'discard-confirm');
        }
        await tapKey(tester, 'lift-row-chest-4');
        await tapKey(tester, 'lift-unit-kg');
        await shot(tester, 'm18_s64_first');
        await tester.tapAt(const Offset(20, 20));
        await tester.pumpAndSettle();
        if (find
            .byKey(const ValueKey('discard-confirm'))
            .evaluate()
            .isNotEmpty) {
          await tapKey(tester, 'discard-confirm');
        }
        await toTop(tester);
        await tapKey(tester, 'today-mark-done');
        await shot(tester, 'm18_s65');
        await tapKey(tester, 'lock-confirm-save');
        await tester.pump(const Duration(seconds: 4));
        await tester.pumpAndSettle();
        await tapKey(tester, 'today-status');
        await shot(tester, 'm18_s23');
        await tester.tapAt(const Offset(20, 20));
        await tester.pumpAndSettle();
        // S-63 buổi đã qua (thứ 2 19/10) và buổi ngày mai (thứ 3 27/10).
        await go(tester, c, '/today/session/2026-10-19');
        await shot(tester, 'm18_s63_past');
        await go(tester, c, '/today/session/2026-10-27');
        await shot(tester, 'm18_s63_future');
      });

      testWidgets('M18: Hôm nay H3 chưa đến giờ', (tester) async {
        final db = AppDatabase(NativeDatabase.memory());
        addTearDown(db.close);
        await seedCapture(db, todayLogs: false);
        await pump(tester, db, DateTime(2026, 10, 26, 17, 0));
        await shot(tester, 'm18_s10_not_started');
      });

      testWidgets('M18: Hôm nay H5 đã tập, nhiều nhóm cơ (thứ 3 27/10)', (
        tester,
      ) async {
        final db = AppDatabase(NativeDatabase.memory());
        addTearDown(db.close);
        final tue = LocalDate(2026, 10, 27);
        await seedCapture(db, today: tue);
        await seedMark(db, tue, DayMark.done);
        await pump(tester, db, DateTime(2026, 10, 27, 19, 30));
        await shot(tester, 'm18_s10_done');
      });

      testWidgets('M18: Hôm nay H6 không tập', (tester) async {
        final db = AppDatabase(NativeDatabase.memory());
        addTearDown(db.close);
        await seedCapture(db, todayLogs: false);
        await seedMark(db, captureMonday, DayMark.skipped);
        await pump(tester, db, DateTime(2026, 10, 26, 19, 30));
        await shot(tester, 'm18_s10_skipped');
      });

      testWidgets('M18: Hôm nay H2 nghỉ (thứ 4 28/10)', (tester) async {
        final db = AppDatabase(NativeDatabase.memory());
        addTearDown(db.close);
        await seedCapture(db, today: LocalDate(2026, 10, 28), todayLogs: false);
        await seedMark(db, captureMonday, DayMark.done);
        await seedMark(db, LocalDate(2026, 10, 27), DayMark.done);
        await pump(tester, db, DateTime(2026, 10, 28, 9));
        await shot(tester, 'm18_s10_rest');
      });

      testWidgets('M18: Hôm nay H1 chưa có lịch', (tester) async {
        final db = AppDatabase(NativeDatabase.memory());
        addTearDown(db.close);
        await AccountRepository(db).put('Minh');
        await ProfileRepository(db).put(completedProfile());
        await pump(tester, db, DateTime(2026, 10, 26, 9));
        await shot(tester, 'm18_s10_no_schedule');
      });

      // VS-45: Thực đơn (S-30) và Cân nặng (S-40, S-41).
      testWidgets('M18: S-30 có thực đơn', (tester) async {
        final db = AppDatabase(NativeDatabase.memory());
        addTearDown(db.close);
        await seedCapture(db);
        await MenuRepository(
          db,
        ).putUsage(AiDailyUsageCodec.key(captureMonday), 1);
        await pump(tester, db, DateTime(2026, 10, 26, 9));
        await tapKey(tester, 'tab-menu');
        await shot(tester, 'm18_s30');
      });

      testWidgets('M18: S-30 trống và đang tạo', (tester) async {
        final db = AppDatabase(NativeDatabase.memory());
        addTearDown(db.close);
        await seedCapture(db, withMenu: false);
        await pump(tester, db, DateTime(2026, 10, 26, 9));
        await tapKey(tester, 'tab-menu');
        await shot(tester, 'm18_s30_empty');
        await MenuRepository(db).put(
          captureMonday,
          const MenuData(
            payload: null,
            targetKcal: 1850,
            usedSafetyFloor: false,
            totalKcal: null,
            lastAttemptStatus: MenuAttemptStatus.generating,
          ),
        );
        await tester.pump(const Duration(milliseconds: 500));
        await shot(tester, 'm18_s30_generating');
      });

      testWidgets('M18: S-40, S-41 sửa, hộp chênh 5 kg', (tester) async {
        final db = AppDatabase(NativeDatabase.memory());
        addTearDown(db.close);
        await seedCapture(db);
        await seedWeights(db);
        await pump(tester, db, DateTime(2026, 10, 26, 9));
        await tapKey(tester, 'tab-weight');
        await shot(tester, 'm18_s40');
        await tapKey(tester, 'weight-week-2026-10-19');
        await shot(tester, 'm18_s41');
        await tester.enterText(
          find.byKey(const ValueKey('field-weight')),
          '66,8',
        );
        await tapKey(tester, 'weight-save');
        await shot(tester, 'm18_s41_big');
      });
    }
  });
}
