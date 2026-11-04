import 'dart:async';

// Chụp màn hình cho bộ ảnh so sánh (06 Bản 4 ED4-04, VS43-T11). Chạy bằng
// tool/capture_screens.sh <M17…M21> qua `flutter drive` trên simulator; ảnh
// vào build/review/<id>.png. Dữ liệu là fixture trong bộ nhớ (như golden),
// không cần server.
import 'package:api_contract/api_contract.dart';
import 'package:domain/domain.dart';
import 'package:domain/testing.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mobile/app/app.dart';
import 'package:mobile/app/router.dart';
import 'package:mobile/app/shell/app_tab.dart';
import 'package:mobile/app/strings_vi.dart';
import 'package:mobile/data/db/app_database.dart';
import 'package:mobile/dev/review_matrix.dart';
import 'package:mobile/features/auth/application/auth_controller.dart';
import 'package:mobile/features/me/data/account_repository.dart';
import 'package:mobile/features/me/data/gym_location_repository.dart';
import 'package:mobile/features/me/data/profile_repository.dart';
import 'package:mobile/features/me/presentation/calorie_proposal_sheet.dart';
import 'package:mobile/features/me/presentation/gym_location_screen.dart';
import 'package:mobile/features/me/presentation/me_screen.dart';
import 'package:mobile/features/menu/data/menu_repository.dart';
import 'package:mobile/features/native/gym_region_bridge.dart';
import 'package:mobile/features/onboarding/application/setup_state.dart';
import 'package:mobile/features/onboarding/data/onboarding_draft_repository.dart';
import 'package:mobile/features/schedule/presentation/pause_sheet.dart';
import 'package:mobile/features/schedule/presentation/schedule_screen.dart';
import 'package:mobile/features/today/presentation/week_progress_screen.dart';
import 'package:mobile/features/weight/data/weight_repository.dart';
import 'package:mobile/features/workout/data/exercise_feel_repository.dart';
import 'package:mobile/features/workout/data/exercise_note_repository.dart';
import 'package:mobile/features/workout/data/exercise_unit_repository.dart';
import 'package:mobile/features/workout/data/lift_log_repository.dart';
import 'package:mobile/features/workout/data/session_exercise_repository.dart';
import 'package:mobile/features/workout/presentation/pick_exercise_screen.dart';
import 'package:mobile/features/workout/presentation/session_screen.dart';
import 'package:mobile/ui/components/ironly_sheet.dart';
import 'package:mobile/ui/components/ironly_tab_bar.dart';
import 'package:mobile/ui/gallery.dart';
import 'package:mobile/ui/keys.dart';
import 'package:mobile/ui/theme.dart';

import '../test/support/app_harness.dart';
import '../test/support/fake_native.dart';
import '../test/support/fake_server.dart';
import '../test/support/fake_sync.dart';
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
    if (milestone == Milestone.m19) {
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

      Future<void> tapKey(WidgetTester tester, String key) async {
        // Mục giữ sống (IndexedStack, tab) cũng có key: ưu tiên phần tử đang
        // hiện; chưa dựng (danh sách lười) thì cuộn tới.
        var f = find.byKey(ValueKey(key));
        if (f.evaluate().isEmpty) {
          f = find.byKey(ValueKey(key), skipOffstage: false);
          if (f.evaluate().isEmpty) {
            await tester.scrollUntilVisible(
              f,
              300,
              scrollable: find.byType(Scrollable).first,
            );
          }
          f = f.first;
        }
        await tester.ensureVisible(f);
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(ValueKey(key)).first);
        await tester.pumpAndSettle();
      }

      Future<void> dismiss(WidgetTester tester) async {
        await tester.tapAt(const Offset(20, 20));
        await tester.pumpAndSettle();
      }

      // Tháng 10 của mock: T2 Ngực, T3 Lưng + Bụng, T5 Vai, T7 Tay trước, lịch
      // từ 07/10; hôm nay thứ 2 26/10 18:05 (đã tập 8, 10, 12, 13, 17, 19,
      // 20, 24; không tập 15, 22; buổi thêm Tay sau thứ 6 23/10).
      Future<AppDatabase> seedMonth() async {
        final db = AppDatabase(NativeDatabase.memory());
        addTearDown(db.close);
        await seedCapture(db, todayLogs: false);
        for (final d in [8, 10, 12, 13, 17, 19, 20, 24]) {
          await seedMark(db, LocalDate(2026, 10, d), DayMark.done);
        }
        for (final d in [15, 22]) {
          await seedMark(db, LocalDate(2026, 10, d), DayMark.skipped);
        }
        await seedExtra(db, LocalDate(2026, 10, 23), const [
          MuscleGroup.triceps,
        ]);
        return db;
      }

      testWidgets('M19: S-20, S-21, S-22, S-24, S-25', (tester) async {
        final db = await seedMonth();
        final c = await pump(tester, db, DateTime(2026, 10, 26, 18, 5));
        await tapKey(tester, 'tab-schedule');
        await shot(tester, 'm19_s20');
        // S-21 ngày tập chưa đến: thứ 5 29/10 (Vai).
        await tapKey(tester, 'month-cell-2026-10-29');
        await shot(tester, 'm19_s21');
        await dismiss(tester);
        // S-21 quá 7 ngày: thứ 2 12/10 (đã tập, khóa).
        await tapKey(tester, 'month-cell-2026-10-12');
        await shot(tester, 'm19_s21_locked');
        await dismiss(tester);
        // S-24 buổi thêm: thứ 4 21/10 nghỉ, đã qua trong 7 ngày → từ S-21.
        await tapKey(tester, 'month-cell-2026-10-21');
        await tapKey(tester, 'day-log-extra');
        await tapKey(tester, 'muscle-abs');
        await shot(tester, 'm19_s24');
        await dismiss(tester);
        if (find
            .byKey(const ValueKey('discard-confirm'))
            .evaluate()
            .isNotEmpty) {
          await tapKey(tester, 'discard-confirm');
        }
        // S-25 của tuần 19/10 (đang chọn sau khi chạm ô 21/10): 3/4 +1.
        await tapKey(tester, 'week-header-2026-10-19');
        await shot(tester, 'm19_s25');
        c.read(routerProvider).go('/schedule');
        await tester.pumpAndSettle();
        // Về đầu trang (danh sách dựng lười) rồi mở S-22, đang sửa thứ 4.
        await tester.drag(find.byType(Scrollable).first, const Offset(0, 3000));
        await tester.pumpAndSettle();
        await tapKey(tester, 'open-weekly');
        // Thứ 3 đang bật (mock sửa thứ 4; lịch chụp thứ 4 nghỉ).
        await tapKey(tester, 'day-row-2');
        await shot(tester, 'm19_s22');
      });

      // VS-47: Thư viện (S-66), Chi tiết bài (S-67), Tiến bộ (S-68), Biểu
      // đồ (S-69), Đổi đơn vị (S-72).
      testWidgets('M19: S-66, S-67, S-72, S-68, S-69', (tester) async {
        final db = AppDatabase(NativeDatabase.memory());
        addTearDown(db.close);
        await seedCapture(db);
        final c = await pump(tester, db, DateTime(2026, 10, 26, 18, 5));
        await tapKey(tester, 'tab-schedule');
        await tapKey(tester, 'section-library');
        await shot(tester, 'm19_s66');
        // S-67 từ buổi hôm nay: bài nấc máy có mức buổi này + ghi chú.
        c.read(routerProvider).go(todayExercisePath('chest-2', captureMonday));
        await tester.pumpAndSettle();
        await shot(tester, 'm19_s67');
        await tapKey(tester, 'exercise-change-unit');
        await shot(tester, 'm19_s72');
        await tapKey(tester, 'change-unit-cancel');
        c.read(routerProvider).go('/schedule');
        await tester.pumpAndSettle();
        await tapKey(tester, 'section-progress');
        await shot(tester, 'm19_s68');
        await tapKey(tester, 'progress-chest-1');
        await shot(tester, 'm19_s69');
      });
    }
    if (milestone == Milestone.m20) {
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

      Future<void> tapKey(WidgetTester tester, String key) async {
        var f = find.byKey(ValueKey(key));
        if (f.evaluate().isEmpty) {
          f = find.byKey(ValueKey(key), skipOffstage: false);
          if (f.evaluate().isEmpty) {
            await tester.scrollUntilVisible(
              f,
              300,
              scrollable: find.byType(Scrollable).first,
            );
          }
          f = f.first;
        }
        await tester.ensureVisible(f);
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(ValueKey(key)).first);
        await tester.pumpAndSettle();
      }

      Future<void> dismiss(WidgetTester tester) async {
        await tester.tapAt(const Offset(20, 20));
        await tester.pumpAndSettle();
      }

      testWidgets('M20: S-50, S-51, S-52, S-53, S-54, S-56, S-73', (
        tester,
      ) async {
        final db = AppDatabase(NativeDatabase.memory());
        addTearDown(db.close);
        await seedCapture(db);
        final now = DateTime(2026, 10, 26, 18, 5);
        await seedMeCapture(db, FixedClock(now));
        final c = await pump(tester, db, now);
        await tapKey(tester, 'tab-me');
        await shot(tester, 'm20_s50');
        await tapKey(tester, 'row-profile');
        await shot(tester, 'm20_s51');
        await tapKey(tester, 'profile-back');
        await tapKey(tester, 'row-calorie');
        await shot(tester, 'm20_s52');
        await tapKey(tester, 'page-back');
        unawaited(
          showCalorieProposalSheet(tester.element(find.byType(MeScreen))),
        );
        await tester.pumpAndSettle();
        await shot(tester, 'm20_s53');
        await dismiss(tester);
        await tapKey(tester, 'row-budget');
        await shot(tester, 'm20_s54');
        c.read(routerProvider).go('/me/account');
        await tester.pumpAndSettle();
        await shot(tester, 'm20_s56');
        await tapKey(tester, 'row-logout');
        await shot(tester, 'm20_s73');
        await tapKey(tester, 'logout-cancel');
      });

      // VS-49: đăng nhập và thiết lập lần đầu. Mỗi trạng thái là một app
      // mới (phiên / hồ sơ khác nhau), như golden của từng màn.
      Future<ProviderContainer> pumpFresh(
        WidgetTester tester, {
        required List<Override> overrides,
      }) async {
        final container = ProviderContainer(
          retry: (_, _) => null,
          overrides: overrides,
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

      Future<ProviderContainer> pumpSetup(
        WidgetTester tester,
        DateTime now,
        Future<void> Function(AppDatabase db) seed,
      ) async {
        final db = AppDatabase(NativeDatabase.memory());
        addTearDown(db.close);
        await seed(db);
        return pumpFresh(
          tester,
          overrides: appOverrides(
            db: db,
            clock: FixedClock(now),
            onboarded: false,
            scheduler: FakeScheduler(),
            initialSetup: SetupState.of(await ProfileRepository(db).get()),
          ),
        );
      }

      testWidgets('M20: S-01, S-01a, S-01b, S-01c, S-02 → S-07', (
        tester,
      ) async {
        final accepted = DateTime(2026, 10, 26, 11, 50);
        final noon = DateTime(2026, 10, 26, 12);
        // S-01 → S-01c: chưa có phiên.
        final c = await pumpFresh(
          tester,
          overrides: appOverrides(session: null),
        );
        await shot(tester, 'm20_s01');
        c.read(routerProvider).go('/welcome/register');
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byKey(const ValueKey('field-display-name')),
          'Anton',
        );
        await tester.enterText(
          find.byKey(const ValueKey('field-phone')),
          '0912345',
        );
        final pw = randomTestPassword();
        await tester.enterText(
          find.byKey(const ValueKey('field-password')),
          pw,
        );
        await tester.enterText(
          find.byKey(const ValueKey('field-password-confirm')),
          pw,
        );
        await tester.tap(find.byKey(const ValueKey('register-submit')));
        await tester.pumpAndSettle();
        await shot(tester, 'm20_s01a');
        c.read(routerProvider).go('/welcome/login');
        await tester.pumpAndSettle();
        await shot(tester, 'm20_s01b');
        await tapKey(tester, 'forgot-password');
        await shot(tester, 'm20_s01c');
        await dismiss(tester);

        // S-02: chưa bấm "Tôi đã hiểu".
        await pumpSetup(tester, noon, (_) async {});
        await shot(tester, 'm20_s02');

        // S-03: bản nháp hồ sơ như mock (bước 2/5).
        await pumpSetup(tester, noon, (db) async {
          await ProfileRepository(
            db,
          ).put(Profile(onboardingStep: 2, disclaimerAcceptedAt: accepted));
          await OnboardingDraftRepository(db).save(
            const ProfileDraft(
              height: '175',
              birthYear: 1996,
              sex: Sex.male,
              activityLevel: ActivityLevel.light,
              weight: '74,9',
            ),
          );
        });
        await shot(tester, 'm20_s03');

        // S-04: hồ sơ đã lưu, mức ước tính (bước 3/5).
        final body = Profile(
          onboardingStep: 3,
          disclaimerAcceptedAt: accepted,
          heightCm: 175,
          birthYear: 1996,
          sex: Sex.male,
          activityLevel: ActivityLevel.light,
        );
        await pumpSetup(tester, noon, (db) async {
          await ProfileRepository(db).put(body);
          await WeightRepository(db).put(LocalDate(2026, 10, 26), 749);
        });
        await shot(tester, 'm20_s04');

        // S-05: lịch tuần trống (bước 4/5).
        await pumpSetup(tester, noon, (db) async {
          await ProfileRepository(db).put(
            body.copyWith(
              onboardingStep: 4,
              calorieMode: CalorieMode.auto,
              calorieKcal: 2210,
              setupDate: LocalDate(2026, 10, 26),
            ),
          );
          await WeightRepository(db).put(LocalDate(2026, 10, 26), 749);
        });
        await shot(tester, 'm20_s05');

        // S-06: lịch đã xếp (thứ 2 18:00 ngực) → ví dụ thật (bước 5/5).
        await pumpSetup(tester, noon, (db) async {
          await seedSetUp(
            db,
            profile: Profile(
              onboardingStep: 5,
              disclaimerAcceptedAt: accepted,
              heightCm: 175,
              birthYear: 1996,
              sex: Sex.male,
              activityLevel: ActivityLevel.light,
              calorieMode: CalorieMode.auto,
              calorieKcal: 2210,
              setupDate: LocalDate(2026, 10, 26),
              timezone: 'Asia/Ho_Chi_Minh',
            ),
          );
        });
        await shot(tester, 'm20_s06');

        // S-07: có phiên, máy chưa có dữ liệu; trang 2 không về → 50 %.
        final server = FakeServer()
          ..on(
            'GET',
            '/v1/me',
            (_) => (
              200,
              {
                'userId': 'u1',
                'phone': '0912345678',
                'displayName': 'Anton',
                'onboardingState': 'completed',
              },
            ),
          )
          ..on('GET', '/v1/sync/pull', (req) async {
            final cursor = req.query['cursor'] as String? ?? '0';
            if (cursor != '0') await Completer<void>().future;
            return (
              200,
              {
                'changes': [
                  {
                    'entity': 'profile',
                    'key': 'me',
                    'deleted': false,
                    'serverVersion': 1,
                    'data': const ProfileCodec().encode(completedProfile()),
                  },
                  {
                    'entity': 'weight',
                    'key': '2026-10-26',
                    'deleted': false,
                    'serverVersion': 2,
                    'data': {'weightKgX10': 749},
                  },
                ],
                'nextCursor': 2,
                'hasMore': true,
                'remaining': 2,
                'meta': {'serverTime': '2026-10-26T05:00:00.000Z'},
              },
            );
          });
        final db = AppDatabase(NativeDatabase.memory());
        addTearDown(db.close);
        await pumpFresh(
          tester,
          overrides: [
            ...appOverrides(
              db: db,
              server: server,
              onboarded: false,
              scheduler: FakeScheduler(),
              initialSetup: SetupState.notStarted,
            ),
            initialRestoreProvider.overrideWithValue(true),
          ],
        );
        await shot(tester, 'm20_s07');
      });
    }
    if (milestone == Milestone.m23) {
      // 06 Bản 5 VS-52: lịch templateAc2 (T2 Ngực + Tay sau, T4 Lưng, T6 Vai
      // 18:00, thiết lập 07/10/2026).
      Future<void> pumpAt(
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
      }

      Future<void> tapKey(WidgetTester tester, String key) async {
        final f = find.byKey(ValueKey(key));
        await tester.ensureVisible(f);
        await tester.pumpAndSettle();
        await tester.tap(f);
        await tester.pumpAndSettle();
      }

      Future<void> training(WidgetTester tester) async {
        await tester.tap(
          find.descendant(
            of: find.byType(IronlyTabBar),
            matching: find.text(S.tabTraining),
          ),
        );
        await tester.pumpAndSettle();
      }

      Future<AppDatabase> seeded() async {
        final db = AppDatabase(NativeDatabase.memory());
        addTearDown(db.close);
        await seedSetUp(db);
        return db;
      }

      final wed = LocalDate(2026, 10, 7);

      testWidgets('M23: S-65 câu mới, S-10 H5, S-23 ba mục', (tester) async {
        final db = await seeded();
        await pumpAt(tester, db, DateTime(2026, 10, 7, 18, 5));
        await tapKey(tester, 'today-mark-done');
        await shot(tester, 'm23_s65');
        await tapKey(tester, 'lock-confirm-save');
        await tester.pump(const Duration(seconds: 4));
        await tester.pumpAndSettle();
        await shot(tester, 'm23_s10_done');
        await tapKey(tester, 'today-status');
        await shot(tester, 'm23_s23');
      });

      testWidgets('M23: S-10 H6, S-21 hôm nay đã Không tập', (tester) async {
        final db = await seeded();
        await seedMark(db, wed, DayMark.skipped);
        await pumpAt(tester, db, DateTime(2026, 10, 7, 19));
        await shot(tester, 'm23_s10_skipped');
        await training(tester);
        await tapKey(tester, 'month-cell-2026-10-07');
        await shot(tester, 'm23_s21_today');
      });

      testWidgets('M23: S-20, S-21 ngày đã qua', (tester) async {
        final db = await seeded();
        await seedMark(db, wed, DayMark.done);
        await pumpAt(tester, db, DateTime(2026, 10, 13, 10));
        await training(tester);
        await shot(tester, 'm23_s20');
        await tapKey(tester, 'month-cell-2026-10-07');
        await shot(tester, 'm23_s21_past');
      });

      testWidgets('M23: S-24 sửa buổi tập thêm hôm nay', (tester) async {
        final db = await seeded();
        await seedExtra(db, LocalDate(2026, 10, 8), const [MuscleGroup.abs]);
        await pumpAt(tester, db, DateTime(2026, 10, 8, 21));
        await training(tester);
        await tapKey(tester, 'month-cell-2026-10-08');
        await tapKey(tester, 'day-edit-extra');
        await shot(tester, 'm23_s24_edit');
      });
    }
    if (milestone == Milestone.m24) {
      // 06 Bản 5 VS-53 → VS-55: buổi Ngực thứ 2 26/10/2026 18:00 theo mock
      // s10-h4 (seedCaptureV5), 18:12.
      final mon = captureMonday;
      final at1812 = DateTime(2026, 10, 26, 18, 12);

      Future<ProviderContainer> pumpAt(
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

      Future<void> tapKey(WidgetTester tester, String key) async {
        final f = find.byKey(ValueKey(key));
        await tester.ensureVisible(f);
        await tester.pumpAndSettle();
        await tester.tap(f);
        await tester.pumpAndSettle();
      }

      Future<AppDatabase> seeded({bool rows = true}) async {
        final db = AppDatabase(NativeDatabase.memory());
        addTearDown(db.close);
        await seedCaptureV5(db, rows: rows);
        return db;
      }

      testWidgets('M24: S-10 H4 đủ 5 loại dòng, S-74 × 3', (tester) async {
        final db = await seeded();
        await pumpAt(tester, db, at1812);
        await shot(tester, 'm24_s10_h4');
        await tapKey(tester, 'exercise-chest-4');
        await shot(tester, 'm24_s74_original');
        await tester.tapAt(const Offset(195, 120));
        await tester.pumpAndSettle();
        await tapKey(tester, 'exercise-back-3');
        await shot(tester, 'm24_s74_replacement');
        await tester.tapAt(const Offset(195, 120));
        await tester.pumpAndSettle();
        await tapKey(tester, 'exercise-abs-1');
        await shot(tester, 'm24_s74_extra');
      });

      testWidgets('M24: S-75 "Đổi bài", "Thêm bài"', (tester) async {
        final db = await seeded(rows: false);
        final c = await pumpAt(tester, db, at1812);
        c.read(routerProvider).go(pickExercisePath(mon, slot: 'chest-2'));
        await tester.pumpAndSettle();
        await shot(tester, 'm24_s75_replace');
        c.read(routerProvider).go(pickExercisePath(mon));
        await tester.pumpAndSettle();
        await shot(tester, 'm24_s75_add');
      });

      testWidgets('M24: S-64 kg (mock s64), nấc máy, bài bụng', (tester) async {
        final db = await seeded();
        await pumpAt(tester, db, at1812);
        await tapKey(tester, 'lift-row-chest-4');
        await tapKey(tester, 'lift-end-plus');
        await tapKey(tester, 'lift-feel-medium');
        await shot(tester, 'm24_s64_kg');
        await tester.tapAt(const Offset(20, 20));
        await tester.pumpAndSettle();
        await tapKey(tester, 'discard-confirm');
        await tapKey(tester, 'lift-row-back-3');
        await tapKey(tester, 'lift-unit-steps');
        await tapKey(tester, 'lift-end-plus');
        await tapKey(tester, 'lift-feel-hard');
        await shot(tester, 'm24_s64_steps');
        await tester.tapAt(const Offset(20, 20));
        await tester.pumpAndSettle();
        await tapKey(tester, 'discard-confirm');
        await tapKey(tester, 'note-line-abs-1');
        await tapKey(tester, 'lift-feel-hard');
        await shot(tester, 'm24_s64_abs');
      });

      testWidgets('M24: S-78 × 4', (tester) async {
        final db = await seeded();
        await LiftLogRepository(db).put(
          LiftLog(
            date: mon,
            exerciseId: 'back-3',
            startKgX10: 200,
            endKgX10: 250,
          ),
        );
        await ExerciseNoteRepository(
          db,
        ).put(ExerciseNote(date: mon, exerciseId: 'abs-1', text: '60 giây'));
        await pumpAt(tester, db, at1812);
        Future<void> close() async {
          await tester.tap(find.byKey(K.dialogSecondary));
          await tester.pumpAndSettle();
        }

        await tapKey(tester, 'exercise-chest-1');
        await tapKey(tester, 'action-replace');
        await shot(tester, 'm24_s78_replace');
        await close();
        await tapKey(tester, 'exercise-back-3');
        await tapKey(tester, 'action-restore');
        await shot(tester, 'm24_s78_restore');
        await close();
        await tapKey(tester, 'exercise-chest-1');
        await tapKey(tester, 'action-skip');
        await shot(tester, 'm24_s78_skip');
        await close();
        await tapKey(tester, 'exercise-abs-1');
        await tapKey(tester, 'action-remove-extra');
        await shot(tester, 'm24_s78_remove_extra');
      });

      testWidgets('M24: S-79 mọi bài đã bỏ qua', (tester) async {
        final db = await seeded(rows: false);
        final session = SessionExerciseRepository(db);
        for (final (i, id) in const [
          'chest-1',
          'chest-2',
          'chest-3',
          'chest-4',
        ].indexed) {
          await session.put(
            SessionExerciseRow(
              date: mon,
              exerciseId: id,
              role: SessionExerciseRole.original,
              position: i,
              skipped: true,
            ),
          );
        }
        await pumpAt(tester, db, at1812);
        await tapKey(tester, 'today-mark-done');
        await shot(tester, 'm24_s79');
      });

      testWidgets('M24: S-63 buổi đã qua (mock s63), buổi chưa đến', (
        tester,
      ) async {
        final db = await seeded();
        final logs = LiftLogRepository(db);
        await logs.put(
          LiftLog(
            date: mon,
            exerciseId: 'back-3',
            startKgX10: 200,
            endKgX10: 250,
          ),
        );
        await logs.put(
          LiftLog(
            date: mon,
            exerciseId: 'chest-4',
            startKgX10: 225,
            endKgX10: 275,
          ),
        );
        final feels = ExerciseFeelRepository(db);
        for (final (id, f) in [
          ('back-3', Feel.medium),
          ('chest-4', Feel.medium),
          ('abs-1', Feel.hard),
        ]) {
          await feels.put(ExerciseFeel(date: mon, exerciseId: id, feel: f));
        }
        await ExerciseNoteRepository(
          db,
        ).put(ExerciseNote(date: mon, exerciseId: 'abs-1', text: '60 giây'));
        await seedMark(db, mon, DayMark.done);
        // Buổi chưa đến thứ 5 29/10 (Vai): GẦN NHẤT 22/10 · Mệt (dấu xám).
        final thu = LocalDate(2026, 10, 22);
        await ExerciseUnitRepository(db).put(
          ExerciseUnit(
            exerciseId: 'shoulders-1',
            unit: LiftUnit.kg,
            changedOn: thu,
          ),
        );
        await logs.put(
          LiftLog(
            date: thu,
            exerciseId: 'shoulders-1',
            startKgX10: 100,
            endKgX10: 125,
          ),
        );
        await feels.put(
          ExerciseFeel(date: thu, exerciseId: 'shoulders-1', feel: Feel.hard),
        );
        final c = await pumpAt(tester, db, DateTime(2026, 10, 27, 9, 40));
        c.read(routerProvider).go(sessionPath(AppTab.today, mon));
        await tester.pumpAndSettle();
        await shot(tester, 'm24_s63_past');
        c
            .read(routerProvider)
            .go(sessionPath(AppTab.today, LocalDate(2026, 10, 29)));
        await tester.pumpAndSettle();
        await shot(tester, 'm24_s63_upcoming');
      });
    }
    if (milestone == Milestone.m25) {
      // 06 Bản 5 VS-56, VS-57: lịch mock M25 (T2 Ngực + Tay sau, T3 Ngực, T4
      // Lưng, T6 Vai 18:00), T2 02/11 và T3 03/11 đã tập, tạm dừng T4 04/11 →
      // CN 08/11 (seedCaptureM25). S-70 tạm dừng là snapshot XCTest (chép ở
      // tool/capture_screens.sh).
      Future<ProviderContainer> pumpAt(
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

      Future<void> tapKey(WidgetTester tester, String key) async {
        final f = find.byKey(ValueKey(key));
        await tester.ensureVisible(f);
        await tester.pumpAndSettle();
        await tester.tap(f);
        await tester.pumpAndSettle();
      }

      Future<void> training(WidgetTester tester) async {
        await tester.tap(
          find.descendant(
            of: find.byType(IronlyTabBar),
            matching: find.text(S.tabTraining),
          ),
        );
        await tester.pumpAndSettle();
      }

      Future<AppDatabase> seeded({bool paused = true}) async {
        final db = AppDatabase(NativeDatabase.memory());
        addTearDown(db.close);
        await seedCaptureM25(db, paused: paused);
        return db;
      }

      final thu0940 = DateTime(2026, 11, 5, 9, 40);

      testWidgets('M25: S-20 tạm dừng (nút hai vạch, banner, ô viền đứt)', (
        tester,
      ) async {
        await pumpAt(tester, await seeded(), thu0940);
        await training(tester);
        await shot(tester, 'm25_s20');
      });

      testWidgets('M25: S-21 ngày tạm dừng (T6 06/11)', (tester) async {
        await pumpAt(tester, await seeded(), thu0940);
        await training(tester);
        await tapKey(tester, 'month-cell-2026-11-06');
        await shot(tester, 'm25_s21');
      });

      testWidgets('M25: S-76 đang có khoảng', (tester) async {
        await pumpAt(tester, await seeded(), thu0940);
        await training(tester);
        await tapKey(tester, 'open-pause');
        await shot(tester, 'm25_s76_active');
      });

      testWidgets('M25: S-76 chưa có khoảng (hôm nay 03/11 → CN 08/11)', (
        tester,
      ) async {
        await pumpAt(
          tester,
          await seeded(paused: false),
          DateTime(2026, 11, 3, 21, 10),
        );
        await training(tester);
        unawaited(
          showIronlySheet<void>(
            tester.element(find.byType(ScheduleScreen)),
            builder: (_) => PauseSheet(
              initialFrom: LocalDate(2026, 11, 3),
              initialTo: LocalDate(2026, 11, 8),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await shot(tester, 'm25_s76_new');
      });

      testWidgets('M25: S-25 tuần tạm dừng (2 / 2)', (tester) async {
        final c = await pumpAt(tester, await seeded(), thu0940);
        await training(tester);
        unawaited(
          c
              .read(routerProvider)
              .push(
                weekProgressPath(
                  AppTab.schedule,
                  ProgressWeek.containing(captureMondayM25),
                ),
              ),
        );
        await tester.pumpAndSettle();
        await shot(tester, 'm25_s25');
      });

      testWidgets('M25: S-10 H7 tạm dừng, ngày có buổi (T4 04/11 18:12)', (
        tester,
      ) async {
        await pumpAt(tester, await seeded(), DateTime(2026, 11, 4, 18, 12));
        await shot(tester, 'm25_s10_h7');
      });

      testWidgets('M25: S-10 H8 tạm dừng, ngày nghỉ (T5 05/11)', (
        tester,
      ) async {
        await pumpAt(tester, await seeded(), thu0940);
        await shot(tester, 'm25_s10_h8');
      });
    }
    if (milestone == Milestone.m26) {
      // 06 Bản 5 VS-58: S-50, S-77 × 3 với cầu vị trí giả (mock S-77: T3
      // 03/11/2026 17:20). Vị trí thật trên simulator: gym_location_test.
      final tue = DateTime(2026, 11, 3, 17, 20);
      final saved = GymLocation(lat: 10.77, lng: 106.69, savedAt: tue);

      Future<FakeGymRegionBridge> pumpGym(
        WidgetTester tester,
        String location, {
        GymLocation? at,
        bool fetching = false,
      }) async {
        final db = AppDatabase(NativeDatabase.memory());
        addTearDown(db.close);
        await AccountRepository(db).put('Anton');
        if (at != null) await GymLocationRepository(db).put(at);
        final gym = FakeGymRegionBridge();
        if (fetching) gym.hold = Completer<GymFix?>();
        final container = ProviderContainer(
          retry: (_, _) => null,
          overrides: appOverrides(db: db, clock: FixedClock(tue), gym: gym),
        );
        addTearDown(container.dispose);
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const IronlyApp(),
          ),
        );
        await tester.pumpAndSettle();
        container.read(routerProvider).go(location);
        await tester.pumpAndSettle();
        if (fetching) {
          await tester.tap(find.byKey(const ValueKey('gym-save')));
          await tester.pump();
        }
        return gym;
      }

      testWidgets('M26: S-50 dòng Vị trí phòng gym', (tester) async {
        await pumpGym(tester, '/me', at: saved);
        await shot(tester, 'm26_s50');
      });

      testWidgets('M26: S-77 chưa lưu', (tester) async {
        await pumpGym(tester, gymLocationPath);
        await shot(tester, 'm26_s77_empty');
      });

      testWidgets('M26: S-77 đang lấy vị trí', (tester) async {
        final gym = await pumpGym(tester, gymLocationPath, fetching: true);
        await shot(tester, 'm26_s77_fetching');
        gym.hold!.complete(null);
        await tester.pumpAndSettle();
      });

      testWidgets('M26: S-77 đã lưu', (tester) async {
        await pumpGym(tester, gymLocationPath, at: saved);
        await shot(tester, 'm26_s77_saved');
      });
    }
  });
}
