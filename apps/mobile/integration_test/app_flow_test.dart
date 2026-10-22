// Integration test trên iOS simulator (ED-10): chạy bằng tool/integration_test.sh
// với server và PostgreSQL thật, app cài mới và Keychain trống.
//
// `flutter test` gỡ app sau mỗi file, nên "mở lại app" (UX-AC3) được làm trong
// cùng file: test sau gọi lại `app.main()`, đọc database và Keychain đã lưu.
import 'package:domain/domain.dart';
import 'package:domain/testing.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mobile/app/providers.dart';
import 'package:mobile/app/shell/app_tab_bar.dart';
import 'package:mobile/app/strings_vi.dart';
import 'package:mobile/core/formatters.dart';
import 'package:mobile/data/auth/session_store.dart';
import 'package:mobile/data/db/app_database.dart';
import 'package:mobile/data/logout_flag.dart';
import 'package:mobile/features/auth/presentation/login_screen.dart';
import 'package:mobile/main.dart' as app;

import 'flow_helpers.dart';

/// Ngày thử: ngày gần nhất trước hôm nay không phải chủ nhật. Cả luồng chạy
/// với giờ của ngày đó, bắt đầu lúc 16:50 (trước buổi tập 18:00).
final LocalDate testDay = () {
  var d = LocalDate.fromDateTime(DateTime.now()).addDays(-1);
  if (d.isSunday) d = d.addDays(-1);
  return d;
}();
final clock = ShiftedClock(
  DateTime.now().difference(testDay.atTime(LocalTime(16, 50))),
);

/// Mật khẩu của tài khoản đăng ký ở đầu luồng, dùng lại khi đăng nhập khôi phục.
final password = randomTestPassword();

Future<void> launch({AppDatabase? database}) => app.runIronlyApp(
  overrides: [clockProvider.overrideWithValue(clock)],
  database: database,
);

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('VS01-T10: đăng ký → S-02. '
      'VS-03: S-02 → S-03 → S-04, thoát app ở bước 3', (tester) async {
    await launch();
    await pumpUntil(tester, find.widgetWithText(OutlinedButton, S.login));

    // VS01-T10: đăng ký thành công → S-02 (Bước 1/5), không có thanh tab.
    await tester.tap(find.widgetWithText(FilledButton, S.register));
    await tester.pumpAndSettle();
    await enter(tester, S.fieldDisplayName, 'Minh');
    await enter(tester, S.fieldPhone, '0912345678');
    await enter(tester, S.fieldPassword, password);
    await enter(tester, S.fieldPasswordConfirm, password);
    await reveal(tester, find.widgetWithText(FilledButton, S.register));
    await tester.tap(find.widgetWithText(FilledButton, S.register));
    await pumpUntil(tester, find.text(S.disclaimerTitle));
    expect(find.text(S.stepOf(1)), findsOneWidget);
    expect(find.byType(AppTabBar), findsNothing);

    // VS-03: S-02 → S-03 (hồ sơ F02-AC1) → S-04.
    await tester.tap(find.text(S.iUnderstand));
    await pumpUntil(tester, find.text(S.profileTitle));
    await enter(tester, S.fieldHeight, '175');
    await tapVisible(tester, find.byKey(const ValueKey('birth-year-field')));
    await tester.tap(find.text(S.done)); // mặc định 30 tuổi
    await tester.pumpAndSettle();
    await tapVisible(tester, find.byKey(const ValueKey('sex-male')));
    await tapVisible(tester, find.byKey(const ValueKey('activity-moderate')));
    await enter(tester, S.fieldInitialWeight, '80');
    await tester.tap(find.widgetWithText(FilledButton, S.continueLabel));
    await pumpUntil(tester, find.text(S.calorieTitle));
    expect(find.text(S.stepOf(3)), findsOneWidget);
    expect(find.text(S.calorieAuto), findsOneWidget);
    // Thoát app ở bước 3; test sau mở lại.
  });

  testWidgets(
    'UX-AC3: mở lại app → đúng bước 3, thông tin còn nguyên. Giữ mức → VS-04: '
    'xếp lịch tuần → VS-05: bước 5 "Để sau" → khung 5 tab (UX-AC1), lịch tháng; tab '
    'Tôi gọi được /healthz; VS-02: đổi tên → đồng bộ với server, Hôm nay chào '
    'tên mới. VS-06: chưa đến giờ → 18:05 mở lại → 1 chạm "Đã tập" → đồng bộ',
    (tester) async {
      // Mở lại app: dựng từ đầu, đọc trạng thái đã lưu trên máy.
      await tester.pumpWidget(const SizedBox());
      await launch();
      await pumpUntil(tester, find.text(S.calorieTitle));
      expect(find.text(S.stepOf(3)), findsOneWidget);
      final kcal = CalorieRules.estimate(
        heightCm: 175,
        weightKgX10: 800,
        age: ProfileRules.age(1996, clock.now().year),
        sex: Sex.male,
        activity: ActivityLevel.moderate,
      ).kcal;
      expect(find.text(Fmt.kcal(kcal), findRichText: true), findsOneWidget);

      await tester.tap(find.widgetWithText(FilledButton, S.keepThisLevel));
      await pumpUntil(tester, find.text(S.stepOf(4)));

      // VS-04: S-05 xếp lịch thứ 2 → thứ 7 đều tập Ngực (giờ mặc định 18:00),
      // lưu → app chia lịch tháng → bước 5.
      expect(find.byKey(const ValueKey('day-switch-7')), findsNothing);
      for (var w = DateTime.monday; w <= DateTime.saturday; w++) {
        await tapVisible(tester, find.byKey(ValueKey('day-switch-$w')));
        await tapVisible(tester, find.byKey(ValueKey('day-time-$w')));
        await tester.tap(find.text(S.done));
        await tester.pumpAndSettle();
        await tapVisible(tester, find.byKey(const ValueKey('muscle-chest')));
      }
      await tester.tap(find.widgetWithText(FilledButton, S.saveSchedule));
      await pumpUntil(tester, find.text(S.stepOf(5)));

      // VS-05: S-06 có ví dụ thật từ lịch; "Để sau" (simulator không bấm được
      // hộp xin quyền của iOS) → hoàn tất thiết lập → Hôm nay (OB-4, NAV-1).
      expect(find.byKey(const ValueKey('reminder-preview')), findsOneWidget);
      await tester.tap(find.widgetWithText(OutlinedButton, S.later));
      await pumpUntil(tester, tabLabel(S.tabToday));
      for (final label in [
        S.tabTraining,
        S.tabMenu,
        S.tabToday,
        S.tabWeight,
        S.tabMe,
      ]) {
        expect(tabLabel(label), findsOneWidget, reason: label);
      }
      expect(find.byKey(const ValueKey('tab-today-button')), findsOneWidget);

      // S-20: tháng hiện tại, bắt đầu từ hôm nay (F03-R5).
      final now = clock.now();
      await tester.tap(tabLabel(S.tabTraining));
      await tester.pumpAndSettle();
      expect(find.text(S.monthTitle(now.month, now.year)), findsOneWidget);
      expect(
        find.text(Fmt.shortWeekdayDate(LocalDate.fromDateTime(now))),
        findsOneWidget,
      );

      // VS-23, VS-33: mục Bài tập. Thư viện 28 bài về máy qua pull (dòng
      // dùng chung, AP-7), mặc định nhóm cơ của buổi hôm nay (Ngực, UA3-11),
      // danh sách phẳng; chạm bài → S-67 có khu video chưa phát, hình vùng
      // cơ, hướng dẫn; "‹ Thư viện" quay lại.
      await tester.tap(find.byKey(const ValueKey('section-library')));
      const press = 'exercise-chest-upper-machine-incline-machine-chest-press';
      await pumpUntil(tester, find.byKey(const ValueKey(press)));
      await tapVisible(tester, find.byKey(const ValueKey(press)));
      expect(find.byKey(const ValueKey('video-play')), findsOneWidget);
      expect(find.text(S.mainRegion), findsOneWidget);
      expect(
        find.byKey(const ValueKey('body-map-male_front-chest_upper')),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const ValueKey('exercise-back')));
      await tester.pumpAndSettle();
      // Chạm lại tab đang mở → mục đang mở cuộn lên đầu, thấy thanh chọn mục.
      await tester.tap(tabLabel(S.tabTraining));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('section-schedule')));
      await tester.pumpAndSettle();

      await tester.tap(tabLabel(S.tabMe));
      await tester.pumpAndSettle();
      await pumpUntil(tester, find.textContaining('Dev server: OK'));

      // VS-02: đổi tên ở S-56 → hiện ngay, đồng bộ với server thật; Hôm nay
      // chào bằng tên mới (UA-21, UX-AC22).
      await tester.tap(find.byKey(const ValueKey('row-account-data')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('row-display-name')));
      await tester.pumpAndSettle();
      await tester.enterText(input(S.fieldDisplayName), 'Minh Anh');
      await tester.tap(find.widgetWithText(FilledButton, S.save));
      await tester.pumpAndSettle();
      expect(find.text('Minh Anh'), findsOneWidget);
      await pumpUntil(tester, find.textContaining(S.syncedAt('')));
      expect(find.text(S.syncLossWarning), findsNothing);

      await tester.tap(find.byIcon(Icons.chevron_left));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('tab-today-button')));
      await tester.pumpAndSettle();
      expect(find.textContaining(S.greeting('Minh Anh')), findsOneWidget);
      expect(find.byKey(const ValueKey('sync-indicator')), findsNothing);

      // VS-06: 16:5x chưa đến giờ → "Đánh dấu được từ 18:00" (UX-AC6). Bạn
      // rời app, 18:05 mở lại → "Chờ đánh dấu"; 1 chạm "Đã tập" → thẻ đổi
      // ngay, đồng bộ với server thật (server kiểm tra giờ tập theo múi giờ
      // của iPhone), chỉ báo "Chưa đồng bộ" biến mất (UX-AC5, TAC-01).
      expect(find.text(S.markableFrom('18:00')), findsOneWidget);
      clock.setNow(testDay.atTime(LocalTime(18, 5)));
      // Không `pump` khi đang `paused`: Flutter tắt vẽ khung hình nên `pump`
      // chờ mãi.
      final binding = tester.binding;
      binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      final done = find.byKey(ValueKey('mark-done-${testDay.toKey()}'));
      await pumpUntil(tester, done);
      expect(find.text(S.statusAwaiting), findsOneWidget);
      await tester.tap(done);
      // VS-24: "Đã tập" qua hộp chốt buổi S-65.
      await pumpUntil(tester, find.text(S.doneConfirmTitle('Ngực')));
      await tester.tap(find.byKey(const ValueKey('lock-confirm-save')));
      await pumpUntil(tester, find.text(S.markedDone('Ngực')));
      await pumpUntilGone(tester, find.byKey(const ValueKey('sync-indicator')));
      // Server nhận (không trả về bản cũ chưa đánh dấu).
      await tester.pumpAndSettle(const Duration(seconds: 2));
      expect(find.text(S.sessionDone), findsWidgets);
      expect(done, findsNothing, reason: 'server không trả bản chưa đánh dấu');

      // VS-27, VS-36: "Xem bài tập" → S-63; buổi đã chốt vẫn ghi tạ đến hết
      // ngày (F21-E1). "Ghi" → S-64 lần ghi đầu: chọn nấc máy, nhập 7 và 8 →
      // Lưu → dòng bài đổi ngay, không chờ mạng; về Hôm nay, "Chưa đồng bộ"
      // biến mất khi server nhận cả đơn vị lẫn mức tạ, server không hoàn về
      // (F21-AC11, F21-AC44, 05 Bản 3 TD3-05).
      const pressId = 'chest-upper-machine-incline-machine-chest-press';
      await tester.tap(find.byKey(const ValueKey('session-view-exercises')));
      await pumpUntil(tester, find.byKey(const ValueKey('lift-log-$pressId')));
      await tester.tap(find.byKey(const ValueKey('lift-log-$pressId')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('lift-unit-steps')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('lift-start-input')),
        '7',
      );
      await tester.enterText(find.byKey(const ValueKey('lift-end-input')), '8');
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('lift-save')));
      await pumpUntil(
        tester,
        find.byKey(const ValueKey('lift-value-$pressId')),
      );
      expect(find.text('7 → 8 nấc'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('session-back')));
      await tester.pumpAndSettle();
      await pumpUntilGone(tester, find.byKey(const ValueKey('sync-indicator')));
      await tester.pumpAndSettle(const Duration(seconds: 2));
      expect(
        find.text(S.liftLoggedCount(1)),
        findsOneWidget,
        reason: 'server nhận, không hoàn về',
      );
    },
  );

  testWidgets(
    'VS-11: S-52 đặt mức 1.900 → ghi cân → S-53, vuốt đóng → chấm ở tab Tôi; '
    'banner "Dùng {Y} kcal" → Tự động; S-51 đổi mức vận động → "Mức calo đã '
    'cập nhật…" → đồng bộ, server giữ hồ sơ mới (F02-AC4 → AC6, UX-AC13)',
    (tester) async {
      await tester.pumpWidget(const SizedBox());
      await launch();
      await pumpUntil(tester, tabLabel(S.tabMe));
      final year = clock.now().year;
      int kcalFor(int kgX10, ActivityLevel a) => CalorieRules.estimate(
        heightCm: 175,
        weightKgX10: kgX10,
        age: ProfileRules.age(1996, year),
        sex: Sex.male,
        activity: a,
      ).kcal;

      // S-52 "Đặt mức khác" 1.900 kcal → Bạn tự đặt.
      await tester.tap(tabLabel(S.tabMe));
      await tester.pumpAndSettle();
      await tapVisible(tester, find.byKey(const ValueKey('row-calorie')));
      await tapVisible(tester, find.byKey(const ValueKey('set-other-level')));
      await tester.enterText(input(S.fieldDailyCalorie), '1900');
      await tester.tap(find.widgetWithText(FilledButton, S.save).last);
      await pumpUntil(tester, find.text(S.calorieManual));
      await tester.tap(find.byIcon(Icons.chevron_left));
      await tester.pumpAndSettle();

      // Ghi 76 kg tuần này (thay 80 kg lúc thiết lập) → S-53; vuốt đóng →
      // đề xuất nằm lại, tab Tôi có chấm.
      final proposed = kcalFor(760, ActivityLevel.moderate);
      await tester.tap(tabLabel(S.tabWeight));
      await tester.pumpAndSettle();
      await tapVisible(
        tester,
        find.widgetWithText(FilledButton, S.logThisWeek),
      );
      await tester.enterText(
        find.descendant(
          of: find.byKey(const ValueKey('weight-input')),
          matching: find.byType(TextField),
        ),
        '76',
      );
      await tester.tap(find.widgetWithText(FilledButton, S.save).last);
      await tester.pumpAndSettle();
      await tester.tap(find.text(S.replace).last);
      await pumpUntil(tester, find.text(S.updateCalorieTitle));
      expect(find.text(S.useKcal(Fmt.kcal(proposed))), findsOneWidget);
      await tester.fling(
        find.text(S.updateCalorieTitle),
        const Offset(0, 600),
        2000,
      );
      await tester.pumpAndSettle();
      expect(find.text(S.updateCalorieTitle), findsNothing);
      await tester.tap(tabLabel(S.tabMe));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('row-dot')), findsOneWidget);

      // S-52: banner "Dùng {Y} kcal" → Tự động, hết chấm.
      await tapVisible(tester, find.byKey(const ValueKey('row-calorie')));
      await tapVisible(tester, find.byKey(const ValueKey('banner-accept')));
      expect(find.text(S.calorieAuto), findsOneWidget);
      await tester.tap(find.byIcon(Icons.chevron_left));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('row-dot')), findsNothing);

      // S-51: đổi sang "Vận động nhẹ" → "Đã lưu hồ sơ" rồi mức calo cập nhật.
      final light = kcalFor(760, ActivityLevel.light);
      await tapVisible(tester, find.byKey(const ValueKey('row-profile')));
      await tapVisible(tester, find.byKey(const ValueKey('activity-light')));
      // Thông báo nhanh "Đã lưu 76 kg" (4 giây) còn nổi trên nút "Lưu" ở cuối
      // trang: chờ nó tắt rồi mới chạm.
      await pumpUntilGone(tester, find.byType(SnackBar));
      await tapVisible(tester, find.widgetWithText(FilledButton, S.save));
      await pumpUntil(tester, find.text(S.profileSaved));
      await pumpUntil(
        tester,
        find.text(S.calorieUpdated(Fmt.integer(proposed), Fmt.integer(light))),
      );

      // Đồng bộ xong, server nhận hồ sơ (không trả bản cũ về).
      await tester.tap(find.byKey(const ValueKey('tab-today-button')));
      await tester.pumpAndSettle();
      await pumpUntilGone(tester, find.byKey(const ValueKey('sync-indicator')));
      await tester.pumpAndSettle(const Duration(seconds: 2));
      await tester.tap(tabLabel(S.tabMe));
      await tester.pumpAndSettle();
      expect(
        find.text(S.calorieSummary(Fmt.kcal(light), S.calorieAuto)),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'VS-12: tab Thực đơn trống → "Gợi ý thực đơn hôm nay" → server thật (nhà '
    'cung cấp giả, ED-11) trả thực đơn → "Gợi ý lại" có hộp xác nhận → còn 1 '
    'lượt; thẻ thực đơn ở Hôm nay mỗi bữa một dòng (F08-AC1, AC4, UX-AC10, '
    'UX-AC11)',
    (tester) async {
      // Server chỉ nhận ngày bấm lệch tối đa 1 ngày (05 §6.9.2): dùng giờ thật.
      clock.setNow(DateTime.now().subtract(const Duration(minutes: 1)));
      await tester.pumpWidget(const SizedBox());
      await launch();
      await pumpUntil(tester, tabLabel(S.tabMenu));
      await tester.tap(tabLabel(S.tabMenu));
      await tester.pumpAndSettle();
      expect(find.text(S.menuEmptyTitle), findsOneWidget);
      expect(find.text(S.remainingToday(3)), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('generate-menu')));
      await pumpUntil(tester, find.text(S.mealBreakfast));
      expect(find.text(S.mealLunch), findsOneWidget);
      final regenerate = find.byKey(const ValueKey('regenerate'));
      await reveal(tester, regenerate);
      // Nút ở cuối trang: kéo lên khỏi thanh tab rồi mới chạm.
      await tester.ensureVisible(regenerate);
      await tester.pumpAndSettle();
      expect(find.text(S.regenerateWithRemaining(2)), findsOneWidget);

      await tester.tap(regenerate);
      await tester.pumpAndSettle();
      expect(find.text(S.regenerateBody(2)), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('confirm-regenerate')));
      await tester.pump(const Duration(milliseconds: 300));
      await pumpUntilGone(
        tester,
        find.byKey(const ValueKey('menu-generating')),
      );
      await pumpUntil(tester, find.text(S.mealBreakfast));
      // Danh sách dựng lười: cuộn tới nút ở cuối trang.
      await reveal(tester, regenerate);
      await tester.pumpAndSettle();
      expect(find.text(S.regenerateWithRemaining(1)), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('tab-today-button')));
      await tester.pumpAndSettle();
      final card = find.byKey(const ValueKey('menu-card'));
      await reveal(tester, card);
      await tester.pumpAndSettle();
      expect(
        find.descendant(of: card, matching: find.text(S.mealBreakfast)),
        findsOneWidget,
      );
      await pumpUntilGone(tester, find.byKey(const ValueKey('sync-indicator')));

      // VS-13: chi phí của 2 lần tạo hiện ở dòng "Ngân sách AI" và S-54.
      await tester.tap(tabLabel(S.tabMe));
      await tester.pumpAndSettle();
      final row = find.byKey(const ValueKey('row-budget'));
      await reveal(tester, row);
      expect(
        find.descendant(of: row, matching: find.textContaining('/ 50.000đ')),
        findsOneWidget,
      );
      expect(find.text('0đ / 50.000đ'), findsNothing);
      await tester.tap(row);
      await tester.pumpAndSettle();
      expect(find.text(S.budgetExplain), findsOneWidget);
    },
  );

  testWidgets(
    'VS-14, UX-AC4, J-06: iPhone mới (database trống, Keychain trống) đăng '
    'nhập cùng số → S-07 khôi phục → Hôm nay "Đã khôi phục dữ liệu", lời chào, '
    'thực đơn, mức calo như máy cũ',
    (tester) async {
      await tester.pumpWidget(const SizedBox());
      await const FlutterSecureStorage().deleteAll();
      await launch(database: AppDatabase(NativeDatabase.memory()));
      await pumpUntil(tester, find.widgetWithText(OutlinedButton, S.login));
      await tester.tap(find.widgetWithText(OutlinedButton, S.login));
      await tester.pumpAndSettle();
      await enter(tester, S.fieldPhone, '0912345678');
      await enter(tester, S.fieldPassword, password);
      await reveal(tester, find.widgetWithText(FilledButton, S.login));
      await tester.tap(find.widgetWithText(FilledButton, S.login));
      await pumpUntil(tester, find.text(S.restored));
      expect(find.byType(AppTabBar), findsOneWidget);
      expect(find.textContaining(S.greeting('Minh Anh')), findsOneWidget);
      final card = find.byKey(const ValueKey('menu-card'));
      await reveal(tester, card);
      expect(
        find.descendant(of: card, matching: find.text(S.mealBreakfast)),
        findsOneWidget,
        reason: 'thực đơn hôm nay khôi phục được',
      );
      await tester.tap(tabLabel(S.tabMe));
      await tester.pumpAndSettle();
      expect(find.textContaining(S.calorieAuto), findsOneWidget);
      expect(find.text('0đ / 50.000đ'), findsNothing, reason: 'F09-AC3');
    },
  );

  testWidgets(
    'VS-38, F27-E2: tắt app sau khi bật cờ đăng xuất → mở lại xóa nốt → màn '
    'Đăng nhập; đăng nhập lại khôi phục; đăng xuất qua S-56 (TAC3-10 phần app) '
    '→ Keychain, cờ trống, mở lại app vào màn Chào mừng',
    (tester) async {
      // Máy đang đăng nhập (test trước) bị tắt ngay sau bước bật cờ.
      await tester.pumpWidget(const SizedBox());
      await PrefsLogoutFlag().set();
      await launch();
      await pumpUntil(tester, find.byType(LoginScreen));
      expect(await SecureSessionStore().read(), isNull);
      expect(await PrefsLogoutFlag().isPending(), isFalse);

      await enter(tester, S.fieldPhone, '0912345678');
      await enter(tester, S.fieldPassword, password);
      await reveal(tester, find.widgetWithText(FilledButton, S.login));
      await tester.tap(find.widgetWithText(FilledButton, S.login));
      await pumpUntil(tester, find.text(S.restored));
      expect(find.textContaining(S.greeting('Minh Anh')), findsOneWidget);

      await tester.tap(tabLabel(S.tabMe));
      await tester.pumpAndSettle();
      await tapVisible(tester, find.byKey(const ValueKey('row-account-data')));
      await tapVisible(tester, find.byKey(const ValueKey('row-logout')));
      await tester.tap(find.byKey(const ValueKey('logout-confirm')));
      await pumpUntil(tester, find.byType(LoginScreen));
      expect(find.byType(AppTabBar), findsNothing);
      expect(await SecureSessionStore().read(), isNull);
      expect(await PrefsLogoutFlag().isPending(), isFalse);

      await tester.pumpWidget(const SizedBox());
      await launch();
      await pumpUntil(tester, find.widgetWithText(OutlinedButton, S.login));
      expect(find.byType(AppTabBar), findsNothing);
    },
  );

  testWidgets(
    'TAC-15: đăng nhập sai 6 lần → lần thứ 6 bị server chặn nhưng vẫn là câu '
    'chung (chạy cuối: bộ chặn đếm cả theo IP, chặn 15 phút)',
    (tester) async {
      await tester.pumpWidget(const SizedBox());
      await const FlutterSecureStorage().deleteAll();
      await launch(database: AppDatabase(NativeDatabase.memory()));
      await pumpUntil(tester, find.widgetWithText(OutlinedButton, S.login));
      await tester.tap(find.widgetWithText(OutlinedButton, S.login));
      await tester.pumpAndSettle();
      await enter(tester, S.fieldPhone, '0987654321');
      await enter(tester, S.fieldPassword, randomTestPassword());
      for (var attempt = 1; attempt <= 6; attempt++) {
        await reveal(tester, find.widgetWithText(FilledButton, S.login));
        await tester.tap(find.widgetWithText(FilledButton, S.login));
        await pumpUntil(tester, find.text(S.errorInvalidCredentials));
        expect(
          find.text(S.errorInvalidCredentials),
          findsOneWidget,
          reason: 'lần $attempt',
        );
      }
    },
  );
}
