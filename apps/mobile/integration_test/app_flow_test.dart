// Integration test trên iOS simulator (ED-10): chạy bằng tool/integration_test.sh
// với server và PostgreSQL thật, app cài mới và Keychain trống.
//
// `flutter test` gỡ app sau mỗi file, nên "mở lại app" (UX-AC3) được làm trong
// cùng file: test sau gọi lại `app.main()`, đọc database và Keychain đã lưu.
import 'package:domain/domain.dart';
import 'package:domain/testing.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mobile/app/providers.dart';
import 'package:mobile/app/strings_vi.dart';
import 'package:mobile/core/formatters.dart';
import 'package:mobile/data/auth/session_store.dart';
import 'package:mobile/data/db/app_database.dart';
import 'package:mobile/data/logout_flag.dart';
import 'package:mobile/features/auth/presentation/login_screen.dart';
import 'package:mobile/features/native/live_activity_controller.dart';
import 'package:mobile/features/native/native_bridge.dart';
import 'package:mobile/features/workout/presentation/lift_log_sheet.dart';
import 'package:mobile/main.dart' as app;
import 'package:mobile/ui/components/ironly_tab_bar.dart';

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
    await pumpUntil(tester, find.byKey(const ValueKey('welcome-login')));

    // VS01-T10: đăng ký thành công → S-02 (Bước 1/5), không có thanh tab.
    await tester.tap(find.byKey(const ValueKey('welcome-register')));
    await tester.pumpAndSettle();
    await enter(tester, S.fieldDisplayName, 'Minh');
    await enter(tester, S.fieldPhone, '0912345678');
    await enter(tester, S.fieldPassword, password);
    await enter(tester, S.fieldPasswordConfirm, password);
    await reveal(tester, find.byKey(const ValueKey('register-submit')));
    await tester.tap(find.byKey(const ValueKey('register-submit')));
    await pumpUntil(tester, find.text(S.disclaimerTitle));
    expect(find.bySemanticsLabel(S.stepOf(1)), findsOneWidget);
    expect(find.byType(IronlyTabBar), findsNothing);

    // VS-03: S-02 → S-03 (hồ sơ F02-AC1) → S-04.
    await tester.tap(find.text(S.iUnderstand));
    await pumpUntil(tester, find.text(S.profileTitle));
    await enter(tester, S.fieldHeight, '175');
    await tapVisible(tester, find.byKey(const ValueKey('birth-year-field')));
    await tester.tap(find.text(S.done)); // mặc định 30 tuổi
    await tester.pumpAndSettle();
    await tapVisible(tester, find.byKey(const ValueKey('sex-male')));
    await tapVisible(tester, find.byKey(const ValueKey('activity-moderate')));
    await enter(tester, S.fieldWeight, '80');
    await tester.tap(find.byKey(const ValueKey('profile-continue')));
    await pumpUntil(tester, find.text(S.calorieTitle));
    expect(find.bySemanticsLabel(S.stepOf(3)), findsOneWidget);
    // Bản 4 (04 S-04): thẻ chỉ số lớn, không chữ chế độ.
    expect(find.text('2.210 kcal', findRichText: true), findsOneWidget);
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
      expect(find.bySemanticsLabel(S.stepOf(3)), findsOneWidget);
      final kcal = CalorieRules.estimate(
        heightCm: 175,
        weightKgX10: 800,
        age: ProfileRules.age(1996, clock.now().year),
        sex: Sex.male,
        activity: ActivityLevel.moderate,
      ).kcal;
      expect(find.text(Fmt.kcal(kcal), findRichText: true), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('keep-this-level')));
      await pumpUntil(tester, find.bySemanticsLabel(S.stepOf(4)));

      // VS-04: S-05 xếp lịch thứ 2 → thứ 7 đều tập Ngực (giờ mặc định 18:00),
      // lưu → app chia lịch tháng → bước 5.
      expect(find.byKey(const ValueKey('day-switch-7')), findsNothing);
      for (var w = DateTime.monday; w <= DateTime.saturday; w++) {
        await tapVisible(tester, find.byKey(ValueKey('day-switch-$w')));
        await tapVisible(tester, find.byKey(ValueKey('day-time-$w')));
        await tester.tap(find.byKey(const ValueKey('time-done')));
        await tester.pumpAndSettle();
        await tapVisible(tester, find.byKey(const ValueKey('muscle-chest')));
      }
      await tester.tap(find.byKey(const ValueKey('save-schedule')));
      await pumpUntil(tester, find.bySemanticsLabel(S.stepOf(5)));

      // VS-05: S-06 có ví dụ thật từ lịch; "Để sau" (simulator không bấm được
      // hộp xin quyền của iOS) → hoàn tất thiết lập → Hôm nay (OB-4, NAV-1).
      expect(find.byKey(const ValueKey('reminder-preview')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('reminders-later')));
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
      // Bản 4 (04 S-20): lưới tháng, ô hôm nay viền cam.
      expect(
        find.byKey(
          ValueKey('month-cell-${LocalDate.fromDateTime(now).toKey()}'),
        ),
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
      // Bản 4 (FR4-04): không câu "Vùng cơ chịu tác động chính".
      expect(find.text(S.mainRegion), findsNothing);
      expect(find.text(S.howTo), findsOneWidget);
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
      await tester.enterText(
        find.byKey(const ValueKey('field-display-name')),
        'Minh Anh',
      );
      await tester.tap(find.byKey(const ValueKey('display-name-save')));
      await tester.pumpAndSettle();
      expect(find.text('Minh Anh'), findsOneWidget);
      await pumpUntil(tester, find.textContaining(S.syncedAt('')));
      expect(find.text(S.syncLossWarning), findsNothing);

      await tester.tap(find.byIcon(Icons.chevron_left));
      await tester.pumpAndSettle();
      // Bản 4: Hôm nay không còn câu chào; "Chưa đồng bộ" chỉ ở tab Tôi và
      // S-56, đã biến mất sau khi server nhận tên mới.
      expect(find.byKey(const ValueKey('sync-pending-icon')), findsNothing);
      await tester.tap(find.byKey(const ValueKey('tab-today-button')));
      await tester.pumpAndSettle();
      expect(find.text(S.tabToday), findsWidgets);
      expect(find.textContaining('Chào'), findsNothing);

      // VS-06: 16:5x chưa đến giờ → "Đánh dấu được từ 18:00" (UX-AC6). Bạn
      // rời app, 18:05 mở lại → "Chờ đánh dấu"; 1 chạm "Đã tập" → thẻ đổi
      // ngay, đồng bộ với server thật (server kiểm tra giờ tập theo múi giờ
      // của iPhone), chỉ báo "Chưa đồng bộ" biến mất (UX-AC5, TAC-01).
      // Bản 4 (04 S-10 H3): chưa đến giờ → góc phải là ngày, chưa có ô chốt.
      expect(find.byKey(const ValueKey('today-date')), findsOneWidget);
      expect(find.byKey(const ValueKey('today-mark-done')), findsNothing);
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
      final done = find.byKey(const ValueKey('today-mark-done'));
      await pumpUntil(tester, done);
      expect(find.bySemanticsLabel(S.statusAwaiting), findsOneWidget);
      await tester.tap(done);
      // VS-24: "Đã tập" qua hộp chốt buổi S-65; mutation `day` kèm
      // `liveActivityEnded` (VS-41, F25-AC3) được server nhận.
      await pumpUntil(tester, find.text(S.doneConfirmTitle('Ngực')));
      await tester.tap(find.byKey(const ValueKey('lock-confirm-save')));
      await pumpUntil(tester, find.text(S.markedDone('Ngực')));
      await pumpUntilGone(tester, find.text(S.markedDone('Ngực')));
      // Server nhận (không trả về bản cũ chưa đánh dấu).
      await tester.pumpAndSettle(const Duration(seconds: 2));
      expect(find.bySemanticsLabel(S.sessionDone), findsWidgets);
      expect(done, findsNothing, reason: 'server không trả bản chưa đánh dấu');

      // 06 Bản 5 VS52-T08, J5-05 (F05-AC61, F05-AC62): trong ngày đổi "Đã
      // tập" → "Không tập" → "Chưa đánh dấu" → "Đã tập" lại qua S-23; server
      // (khóa trong ngày, TD5-08) nhận cả ba lần, không hoàn về.
      final statusGlyph = find.byKey(const ValueKey('today-status'));
      await tester.tap(statusGlyph);
      await pumpUntil(tester, find.byKey(const ValueKey('status-sheet')));
      expect(find.text(S.unmarked), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('status-skipped')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('status-save')));
      await pumpUntil(tester, find.text(S.markedSkipped));
      await pumpUntilGone(tester, find.text(S.markedSkipped));
      await tester.pumpAndSettle(const Duration(seconds: 2));
      expect(find.bySemanticsLabel(S.sessionSkipped), findsWidgets);
      await tester.tap(statusGlyph);
      await pumpUntil(tester, find.byKey(const ValueKey('status-sheet')));
      await tester.tap(find.byKey(const ValueKey('status-unmarked')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('status-save')));
      await pumpUntil(tester, done);
      await tester.pumpAndSettle(const Duration(seconds: 2));
      expect(done, findsOneWidget, reason: 'server nhận bỏ đánh dấu');

      // 06 Bản 5 VS53-T05, J5-02 bước 3 (F28-AC1, F28-AC2): ··· bài 2 → S-74
      // → Đổi bài → S-75 → "Máy dốc gắn bánh tạ" (lưng) đứng chỗ bài 2; ghi
      // 20 → 25 kg cho bài thay; server thật nhận dòng thay rồi mức tạ (thứ
      // tự outbox, TD5-09), không hoàn về.
      const benchId = 'chest-mid-free-weight-flat-barbell-bench-press';
      const plateId = 'back-back-mid-plate-loaded-row-machine';
      const latsId = 'lats-machine-lat-pulldown';
      Finder byKey(String k) => find.byKey(ValueKey(k));
      Finder endIs(String id, String value) => find.byWidgetPredicate(
        (w) =>
            w is Text && w.key == ValueKey('lift-end-$id') && w.data == value,
      );
      await reveal(tester, byKey('exercise-$benchId'));
      await tester.tap(byKey('exercise-$benchId'));
      await pumpUntil(tester, byKey('action-replace'));
      await tester.tap(byKey('action-replace'));
      await pumpUntil(tester, byKey('pick-list'));
      await reveal(tester, byKey('pick-$plateId'));
      await tester.tap(byKey('pick-$plateId'));
      await pumpUntil(tester, byKey('replaced-mark-$plateId'));
      expect(byKey('lift-block-$benchId'), findsNothing);
      await reveal(tester, byKey('lift-row-$plateId'));
      await tester.tap(byKey('lift-row-$plateId'));
      await tester.pumpAndSettle();
      await tester.tap(byKey('lift-unit-kg'));
      await tester.pumpAndSettle();
      await tester.enterText(byKey('field-lift-start'), '20');
      await tester.enterText(byKey('field-lift-end'), '25');
      await tester.pumpAndSettle();
      await tester.tapAt(
        tester.getTopLeft(find.byType(LiftLogSheet)) + const Offset(24, 24),
      );
      await tester.pumpAndSettle();
      // 06 Bản 5 VS55-T05, J5-02 bước 3 (F33-AC1, F33-E4, F21-R61): chọn
      // "Thoải mái" cùng lần Lưu; mức thoải mái thuộc bài thay.
      await tester.ensureVisible(byKey('lift-feel-easy'));
      await tester.pumpAndSettle();
      await tester.tap(byKey('lift-feel-easy'));
      await tester.pumpAndSettle();
      await tester.tap(byKey('lift-save'));
      await pumpUntil(tester, endIs(plateId, '25'));
      await tester.pumpAndSettle(const Duration(seconds: 2));
      expect(endIs(plateId, '25'), findsOneWidget, reason: 'server nhận');
      expect(byKey('replaced-mark-$plateId'), findsOneWidget);
      expect(
        byKey('feel-today-$plateId'),
        findsOneWidget,
        reason: 'server nhận',
      );

      // F28-AC4 (FC5-14): bài thay đã ghi → Đổi bài → S-78 → "Xóa và đổi
      // bài" → S-75 → bài khác; bản ghi 20 → 25 không còn, server nhận.
      await reveal(tester, byKey('exercise-$plateId'));
      await tester.tap(byKey('exercise-$plateId'));
      await pumpUntil(tester, byKey('action-replace'));
      await tester.tap(byKey('action-replace'));
      await pumpUntil(tester, find.text(S.recordsDeleteBody));
      await tester.tap(byKey('records-delete-confirm'));
      await pumpUntil(tester, byKey('pick-list'));
      await reveal(tester, byKey('pick-$latsId'));
      await tester.tap(byKey('pick-$latsId'));
      await pumpUntil(tester, byKey('replaced-mark-$latsId'));
      await tester.pumpAndSettle(const Duration(seconds: 2));
      expect(byKey('lift-block-$plateId'), findsNothing);
      expect(byKey('replaced-mark-$latsId'), findsOneWidget);

      // 06 Bản 5 VS54-T05, J5-02 bước 5 → 6 (F29-AC1, F30-AC1, F20-AC61):
      // bỏ qua bài 4 → gạch ngang, hàng số mờ không ô tick (Bạn yêu cầu
      // 06/11/2026); "+ Thêm bài" → S-75 "Thêm
      // bài" → Plank nối cuối có "+"; server thật nhận dòng bỏ qua và dòng
      // bài thêm (không hoàn về), lịch tuần không đổi.
      const declineId = 'chest-chest-lower-decline-plate-loaded-press';
      const plankId = 'abs-mid-bodyweight-forearm-plank';
      await reveal(tester, byKey('exercise-$declineId'));
      await tester.tap(byKey('exercise-$declineId'));
      await pumpUntil(tester, byKey('action-skip'));
      await tester.tap(byKey('action-skip'));
      await pumpUntil(tester, byKey('skipped-mark-$declineId'));
      expect(byKey('lift-row-$declineId'), findsOneWidget);
      expect(byKey('lift-tick-$declineId'), findsNothing);
      await reveal(tester, byKey('add-exercise'));
      await tester.tap(byKey('add-exercise'));
      await pumpUntil(tester, byKey('pick-list'));
      expect(find.text(S.pickAddTitle), findsWidgets);
      // Viên "Bụng" (thanh viên cuộn ngang) cuộn danh sách tới nhóm (S-75),
      // rồi chạm Plank.
      await tester.ensureVisible(byKey('pick-group-abs'));
      await tester.pumpAndSettle();
      await tester.tap(byKey('pick-group-abs'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(byKey('pick-$plankId'));
      await tester.pumpAndSettle();
      await tester.tap(byKey('pick-$plankId'));
      await pumpUntil(tester, byKey('extra-mark-$plankId'));
      await tester.pumpAndSettle(const Duration(seconds: 2));
      expect(byKey('skipped-mark-$declineId'), findsOneWidget);
      expect(
        byKey('extra-mark-$plankId'),
        findsOneWidget,
        reason: 'server nhận',
      );

      // 06 Bản 5 VS55-T05, J5-02 bước 6 (F33-E5, FC5-05): Plank (bụng) →
      // S-64 chỉ thanh ba mức + ghi chú; "Mệt" + "60 giây" → server thật nhận
      // cả hai (exercise_feel không xét bài có mức tạ), không hoàn về.
      // Thông báo nhanh "Đã thêm …" (3 giây) che dòng cuối (Plank nằm cuối
      // danh sách từ khi "+ Thêm bài" lên đầu, 06/11/2026): chờ tắt rồi chạm.
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();
      await reveal(tester, byKey('note-mark-$plankId-none'));
      await tester.tap(byKey('note-mark-$plankId-none'));
      await pumpUntil(tester, byKey('lift-feel-bar'));
      expect(byKey('lift-box-start'), findsNothing);
      await tester.tap(byKey('lift-feel-hard'));
      await tester.pumpAndSettle();
      await tester.enterText(byKey('note-input'), '60 giây');
      await tester.pumpAndSettle();
      await tester.tap(byKey('lift-save'));
      await pumpUntil(tester, byKey('feel-today-$plankId'));
      await tester.pumpAndSettle(const Duration(seconds: 2));
      expect(
        byKey('feel-today-$plankId'),
        findsOneWidget,
        reason: 'server nhận',
      );
      expect(find.text('60 giây'), findsOneWidget);

      // J5-02 bước 7: "Đã tập" (còn bài không bỏ qua → hộp S-65 thường).
      await tester.tap(done);
      await pumpUntil(tester, find.text(S.doneConfirmBody));
      await tester.tap(find.byKey(const ValueKey('lock-confirm-save')));
      await pumpUntil(tester, find.text(S.markedDone('Ngực')));
      await pumpUntilGone(tester, find.text(S.markedDone('Ngực')));
      await tester.pumpAndSettle(const Duration(seconds: 2));
      expect(done, findsNothing, reason: 'server nhận "Đã tập" lại');

      // F28-AC5 (BR5-13): buổi "Đã tập" → S-74 chỉ Xem bài sáng.
      await reveal(tester, byKey('exercise-$latsId'));
      await tester.tap(byKey('exercise-$latsId'));
      await pumpUntil(tester, byKey('action-replace'));
      expect(
        tester
            .widget<Opacity>(
              find
                  .descendant(
                    of: byKey('action-replace'),
                    matching: find.byType(Opacity),
                  )
                  .first,
            )
            .opacity,
        0.4,
      );
      await tester.tapAt(const Offset(195, 120));
      await tester.pumpAndSettle();

      // VS-27, VS-36: "Xem bài tập" → S-63; buổi đã chốt vẫn ghi tạ đến hết
      // ngày (F21-E1). "Ghi" → S-64 lần ghi đầu: chọn nấc máy, nhập 7 và 8 →
      // Lưu → dòng bài đổi ngay, không chờ mạng; về Hôm nay, "Chưa đồng bộ"
      // biến mất khi server nhận cả đơn vị lẫn mức tạ, server không hoàn về
      // (F21-AC11, F21-AC44, 05 Bản 3 TD3-05).
      // Bản 4 (FR4-07): danh sách bài của buổi hôm nay nằm ngay ở Hôm nay;
      // chạm hàng số → S-64.
      const pressId = 'chest-upper-machine-incline-machine-chest-press';
      final row = find.byKey(const ValueKey('lift-row-$pressId'));
      await reveal(tester, row);
      await tester.tap(row);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('lift-unit-steps')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('field-lift-start')),
        '7',
      );
      await tester.enterText(find.byKey(const ValueKey('field-lift-end')), '8');
      await tester.pumpAndSettle();
      // Bàn phím số iPhone không có phím Xong: chạm ra ngoài ô thì đóng.
      final endInput = tester.widget<EditableText>(
        find.descendant(
          of: find.byKey(const ValueKey('field-lift-end')),
          matching: find.byType(EditableText),
        ),
      );
      expect(endInput.focusNode.hasFocus, isTrue);
      await tester.tapAt(
        tester.getTopLeft(find.byType(LiftLogSheet)) + const Offset(24, 24),
      );
      await tester.pumpAndSettle();
      expect(endInput.focusNode.hasFocus, isFalse);
      await tester.tap(find.byKey(const ValueKey('lift-save')));
      await pumpUntil(
        tester,
        find.byWidgetPredicate(
          (w) =>
              w is Text &&
              w.key == const ValueKey('lift-end-$pressId') &&
              w.data == '8',
        ),
      );
      expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('lift-start-$pressId')))
            .data,
        '7',
      );
      await tester.pumpAndSettle(const Duration(seconds: 2));
      // Server nhận, không hoàn về: "Đã ghi 1 / n" giữ nguyên.
      expect(
        find.byWidgetPredicate(
          (w) =>
              w is Text &&
              w.key == const ValueKey('stat-logged') &&
              w.data!.startsWith('1 / '),
        ),
        findsOneWidget,
      );

      // 06 Bản 5 VS56-T05, J5-03 (F31-AC1, F31-AC6, F31-R8): tab Tập luyện →
      // nút hai vạch → S-76 → "Tạm dừng" hôm nay → banner "Đến …"; server
      // nhận khoảng (không hoàn về). Đang có khoảng → S-76 "Đang tạm dừng",
      // không có nút tạo khoảng → "Kết thúc tạm dừng" → hộp → kết thúc vào
      // ngày bắt đầu = xóa khoảng, server nhận (banner không quay lại).
      await tester.tap(find.byKey(const ValueKey('tab-schedule')));
      await tester.pumpAndSettle();
      await tester.tap(byKey('open-pause'));
      await pumpUntil(tester, byKey('pause-sheet'));
      expect(
        find.text(S.todayDayMonth(Fmt.dayMonth(testDay))),
        findsNWidgets(2),
      );
      await tester.tap(byKey('pause-submit'));
      await pumpUntil(tester, byKey('pause-banner'));
      await tester.pumpAndSettle(const Duration(seconds: 2));
      expect(byKey('pause-banner'), findsOneWidget, reason: 'server nhận');
      await tester.tap(byKey('open-pause'));
      await pumpUntil(tester, byKey('pause-sheet-active'));
      expect(byKey('pause-submit'), findsNothing);
      await tester.tap(byKey('pause-end'));
      await pumpUntil(tester, byKey('confirm-end-pause'));
      await tester.tap(byKey('confirm-end-pause'));
      await pumpUntilGone(tester, byKey('pause-banner'));
      await tester.pumpAndSettle(const Duration(seconds: 2));
      expect(byKey('pause-banner'), findsNothing, reason: 'server nhận xóa');
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
      await tester.enterText(
        find.byKey(const ValueKey('field-daily-calorie')),
        '1900',
      );
      await tester.tap(find.byKey(const ValueKey('calorie-save')));
      // Bản 4: đang Tự đặt → mục "Tự động" của thanh chọn là lối dùng lại.
      await pumpUntil(tester, find.byKey(const ValueKey('use-app-estimate')));
      await tester.tap(find.byIcon(Icons.chevron_left));
      await tester.pumpAndSettle();

      // Ghi 76 kg tuần này (thay 80 kg lúc thiết lập) → S-53; vuốt đóng →
      // đề xuất nằm lại, tab Tôi có chấm.
      final proposed = kcalFor(760, ActivityLevel.moderate);
      await tester.tap(tabLabel(S.tabWeight));
      await tester.pumpAndSettle();
      // Bản 4 S-40 / S-41: nút "Ghi cân" → một ô số lớn → "Lưu".
      await tapVisible(tester, find.byKey(const ValueKey('log-weight')));
      await tester.enterText(find.byKey(const ValueKey('field-weight')), '76');
      await tester.tap(find.byKey(const ValueKey('weight-save')));
      await tester.pumpAndSettle();
      await tester.tap(find.text(S.replace).last);
      // Bản 4 (04 S-53): bảng không tiêu đề, câu nguyên văn + hai nút.
      final accept = find.byKey(const ValueKey('proposal-accept'));
      await pumpUntil(tester, accept);
      expect(find.text(S.useKcal(Fmt.kcal(proposed))), findsOneWidget);
      await tester.fling(accept, const Offset(0, 600), 2000);
      await tester.pumpAndSettle();
      expect(accept, findsNothing);
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
      await tapVisible(tester, find.byKey(const ValueKey('profile-save')));
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
      // Bản 4 S-30 trống: chỉ nút "Gợi ý thực đơn" + "Còn 3 lượt".
      expect(find.text(S.generateMenuShort), findsOneWidget);
      expect(find.text(S.remainingShort(3)), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('generate-menu')));
      await pumpUntil(tester, find.text(S.mealBreakfast.toUpperCase()));
      expect(find.text(S.mealLunch.toUpperCase()), findsOneWidget);
      final regenerate = find.byKey(const ValueKey('regenerate'));
      await reveal(tester, regenerate);
      // Nút ở cuối trang: kéo lên khỏi thanh tab rồi mới chạm.
      await tester.ensureVisible(regenerate);
      await tester.pumpAndSettle();
      expect(find.text(S.regenerateShort(2)), findsOneWidget);

      await tester.tap(regenerate);
      await tester.pumpAndSettle();
      expect(find.text(S.regenerateBody(2)), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('confirm-regenerate')));
      await tester.pump(const Duration(milliseconds: 300));
      await pumpUntilGone(
        tester,
        find.byKey(const ValueKey('menu-generating')),
      );
      await pumpUntil(tester, find.text(S.mealBreakfast.toUpperCase()));
      // Danh sách dựng lười: cuộn tới nút ở cuối trang.
      await reveal(tester, regenerate);
      await tester.pumpAndSettle();
      expect(find.text(S.regenerateShort(1)), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('tab-today-button')));
      await tester.pumpAndSettle();
      // Bản 4 (04 S-10): ngày có buổi → thực đơn một dòng; ngày nghỉ → thẻ
      // ba dòng (giờ thật nên không biết trước).
      await expectMenuOnToday(tester);
      await tester.tap(tabLabel(S.tabMe));
      // Icon chưa đồng bộ xoay liên tục: pumpAndSettle sẽ chờ tới khi đồng bộ
      // xong, bỏ qua giới hạn của pumpUntilGone.
      await tester.pump();
      await pumpUntilGone(
        tester,
        find.byKey(const ValueKey('sync-pending-icon')),
      );

      // VS-13: chi phí của 2 lần tạo hiện ở dòng "Ngân sách AI" và S-54.
      await tester.tap(tabLabel(S.tabMe));
      await tester.pumpAndSettle();
      final row = find.byKey(const ValueKey('row-budget'));
      await reveal(tester, row);
      // Bản 4 (04 S-50): giá trị "{đã dùng}đ" + thanh nhỏ; S-54 không đoạn
      // giải thích.
      expect(
        find.descendant(of: row, matching: find.textContaining('đ')),
        findsWidgets,
      );
      expect(find.descendant(of: row, matching: find.text('0đ')), findsNothing);
      await tester.tap(row);
      await tester.pumpAndSettle();
      expect(find.text(S.budgetExplain), findsNothing);
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
      await pumpUntil(tester, find.byKey(const ValueKey('welcome-login')));
      await tester.tap(find.byKey(const ValueKey('welcome-login')));
      await tester.pumpAndSettle();
      await enter(tester, S.fieldPhone, '0912345678');
      await enter(tester, S.fieldPassword, password);
      await reveal(tester, find.byKey(const ValueKey('login-submit')));
      await tester.tap(find.byKey(const ValueKey('login-submit')));
      await pumpUntil(tester, find.text(S.restored));
      expect(find.byType(IronlyTabBar), findsOneWidget);
      expect(find.text(S.tabToday), findsWidgets);
      await expectMenuOnToday(tester);
      await tester.tap(tabLabel(S.tabMe));
      await tester.pumpAndSettle();
      expect(find.textContaining(S.calorieAuto), findsOneWidget);
      expect(find.text('0đ / 50.000đ'), findsNothing, reason: 'F09-AC3');
    },
  );

  testWidgets(
    'VS-38, F27-E2: tắt app sau khi bật cờ đăng xuất → mở lại xóa nốt → màn '
    'Đăng nhập; đăng nhập lại khôi phục; VS-41: cầu thẻ màn hình khóa thật '
    '(không thẻ nào khi server chưa bật, gửi push-to-start token nếu iOS cấp); '
    'đăng xuất qua S-56 (TAC3-10) → Keychain, cờ, token thẻ trống, mở lại app '
    'vào màn Chào mừng',
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
      await reveal(tester, find.byKey(const ValueKey('login-submit')));
      await tester.tap(find.byKey(const ValueKey('login-submit')));
      await pumpUntil(tester, find.text(S.restored));
      expect(find.text(S.tabToday), findsWidgets);

      // VS-41 (TA3-15): simulator không bật được thẻ bằng push; app không bao
      // giờ tự bật (ED3-09) → không thẻ nào; cập nhật / tắt thẻ không có
      // không lỗi; push-to-start token (nếu iOS cấp) gửi lên server thật.
      final container = ProviderScope.containerOf(
        tester.element(find.byType(IronlyTabBar)),
      );
      final bridge = container.read(nativeBridgeProvider);
      expect(await bridge.liveActivities(), isEmpty);
      await bridge.updateLiveActivity('none', '{}');
      await bridge.endLiveActivity('none');
      await bridge.endAllLiveActivities();
      final token = await bridge.pushToStartToken();
      await container.read(liveActivityControllerProvider).refresh();
      final sent = await PrefsLiveActivityStore().sent();
      expect(sent?.pushToStart, token);
      // ignore: avoid_print
      print('VS-41 push-to-start token trên simulator: ${token != null}');

      await tester.tap(tabLabel(S.tabMe));
      await tester.pumpAndSettle();
      await tapVisible(tester, find.byKey(const ValueKey('row-account-data')));
      await tapVisible(tester, find.byKey(const ValueKey('row-logout')));
      await tester.tap(find.byKey(const ValueKey('logout-confirm')));
      await pumpUntil(tester, find.byType(LoginScreen));
      expect(find.byType(IronlyTabBar), findsNothing);
      expect(await SecureSessionStore().read(), isNull);
      expect(await PrefsLogoutFlag().isPending(), isFalse);
      expect(await PrefsLiveActivityStore().sent(), isNull);

      await tester.pumpWidget(const SizedBox());
      await launch();
      await pumpUntil(tester, find.byKey(const ValueKey('welcome-login')));
      expect(find.byType(IronlyTabBar), findsNothing);
    },
  );

  testWidgets(
    'TAC-15: đăng nhập sai 6 lần → lần thứ 6 bị server chặn nhưng vẫn là câu '
    'chung (chạy cuối: bộ chặn đếm cả theo IP, chặn 15 phút)',
    (tester) async {
      await tester.pumpWidget(const SizedBox());
      await const FlutterSecureStorage().deleteAll();
      await launch(database: AppDatabase(NativeDatabase.memory()));
      await pumpUntil(tester, find.byKey(const ValueKey('welcome-login')));
      await tester.tap(find.byKey(const ValueKey('welcome-login')));
      await tester.pumpAndSettle();
      await enter(tester, S.fieldPhone, '0987654321');
      await enter(tester, S.fieldPassword, randomTestPassword());
      for (var attempt = 1; attempt <= 6; attempt++) {
        await reveal(tester, find.byKey(const ValueKey('login-submit')));
        await tester.tap(find.byKey(const ValueKey('login-submit')));
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
