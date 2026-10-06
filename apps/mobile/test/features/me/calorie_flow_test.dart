import 'package:domain/domain.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/app/app.dart';
import 'package:mobile/app/shell/app_tab.dart';
import 'package:mobile/app/shell/app_tab_bar.dart';
import 'package:mobile/app/shell/tab_scroll.dart';
import 'package:mobile/app/strings_vi.dart';
import 'package:mobile/core/widgets/labeled_field.dart';
import 'package:mobile/data/db/app_database.dart';
import 'package:mobile/data/local_marks.dart';
import 'package:mobile/features/me/data/profile_repository.dart';
import 'package:mobile/features/me/presentation/calorie_proposal_sheet.dart';
import 'package:mobile/features/weight/data/weight_repository.dart';

import '../../support/app_harness.dart';
import '../../support/fake_server.dart';
import '../../support/fake_sync.dart';
import '../../support/schedule_fixture.dart';

void main() {
  late AppDatabase db;
  late FixedClock clock;
  late ProviderContainer container;

  // seedSetUp: nam, 1996, 175 cm, vận động vừa, 80 kg tuần 05/10, Tự động
  // 2.210 kcal. Ghi 76 kg (chênh dưới 5 kg, không hỏi F07-V2) → mức ước tính
  // 2.150 kcal.
  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    clock = FixedClock(DateTime(2026, 10, 14, 9));
  });

  Future<void> pump(WidgetTester tester, {LocalMarks? marks}) async {
    tester.view
      ..physicalSize = const Size(390 * 3, 844 * 3)
      ..devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    container = ProviderContainer(
      retry: (_, _) => null,
      overrides: appOverrides(
        db: db,
        clock: clock,
        scheduler: FakeScheduler(),
        server: FakeServer(),
        marks: marks ?? MemoryLocalMarks(2026),
      ),
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const HealthApp()),
    );
    await tester.pumpAndSettle();
  }

  Finder tab(String label) =>
      find.descendant(of: find.byType(AppTabBar), matching: find.text(label));

  Finder input(String label) => find.descendant(
    of: find.byWidgetPredicate((w) => w is LabeledField && w.label == label),
    matching: find.byType(TextField),
  );

  Future<void> tapFinder(WidgetTester tester, Finder f) async {
    await tester.ensureVisible(f);
    await tester.pumpAndSettle();
    await tester.tap(f);
    await tester.pumpAndSettle();
  }

  Future<void> tapKey(WidgetTester tester, String key) =>
      tapFinder(tester, find.byKey(ValueKey(key)));

  Future<void> tapText(WidgetTester tester, String text) =>
      tapFinder(tester, find.text(text).last);

  Future<void> openMe(WidgetTester tester) => tapFinder(tester, tab(S.tabMe));

  Future<Profile> profile() async => (await ProfileRepository(db).get())!;

  Future<void> seedManual(int kcal) => seedSetUp(
    db,
    profile: completedProfile(mode: CalorieMode.manual, kcal: kcal),
  );

  /// Ghi cân tuần này ở S-40 → S-41 → "Lưu".
  Future<void> logWeight(WidgetTester tester, String value) async {
    await tapFinder(tester, tab(S.tabWeight));
    await tapFinder(tester, find.widgetWithText(FilledButton, S.logThisWeek));
    await tester.enterText(
      find.descendant(
        of: find.byKey(const ValueKey('weight-input')),
        matching: find.byType(TextField),
      ),
      value,
    );
    await tester.tap(find.widgetWithText(FilledButton, S.save).last);
    await tester.pumpAndSettle();
  }

  /// Vuốt bảng trượt S-53 xuống để đóng mà không chọn (UA-14).
  Future<void> swipeDown(WidgetTester tester) async {
    await tester.fling(
      find.byType(CalorieProposalSheet),
      const Offset(0, 600),
      2000,
    );
    await tester.pumpAndSettle();
  }

  /// Đi tới [f] trong danh sách đang cuộn (ListView chỉ dựng phần gần màn
  /// hình).
  Future<void> reveal(WidgetTester tester, Finder f) async {
    await tester.scrollUntilVisible(
      f,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
  }

  /// "‹ Tôi" ở đầu S-51 (cuộn lên nếu đã khuất).
  Future<void> profileBack(WidgetTester tester) async {
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('profile-back')),
      -200,
      scrollable: find.byType(Scrollable).first,
    );
    await tapKey(tester, 'profile-back');
  }

  bool meDot() => container.read(tabDotsProvider).contains(AppTab.me);

  testWidgets('04 S-50: dòng "Hồ sơ cơ thể" "175 cm · 30 tuổi · Nam", "Mức '
      'calo" "2.210 kcal · Tự động"; chạm → S-51, S-52', (tester) async {
    await seedSetUp(db);
    await pump(tester);
    await openMe(tester);
    expect(find.text('175 cm · 30 tuổi · Nam'), findsOneWidget);
    expect(find.text('2.210 kcal · Tự động'), findsOneWidget);
    expect(find.byKey(const ValueKey('row-dot')), findsNothing);

    await tapKey(tester, 'row-profile');
    expect(find.text(S.bodyProfile), findsOneWidget);
    await reveal(tester, find.text(S.currentWeight));
    expect(find.text('80 kg'), findsOneWidget);
    await profileBack(tester);

    await tapKey(tester, 'row-calorie');
    expect(find.text(S.calorieLevel), findsOneWidget);
    expect(find.text('2.210 kcal', findRichText: true), findsOneWidget);
    expect(find.text(S.setOtherLevel), findsOneWidget);
    // Chế độ Tự động: không có "Dùng lại ước tính của app".
    expect(find.byKey(const ValueKey('use-app-estimate')), findsNothing);
    expect(find.text(S.howEstimated), findsOneWidget);
  });

  testWidgets(
    'F02-AC4, F07-AC6, F02-R8: Tự động, ghi 76 kg → "Đã lưu 76 kg" rồi '
    '"Mức calo đã cập nhật từ 2.210 thành 2.150 kcal."; S-50 hiện 2.150',
    (tester) async {
      await seedSetUp(db);
      await pump(tester);
      await logWeight(tester, '76');
      expect(find.text(S.weightSaved('76 kg')), findsOneWidget);
      expect(find.byType(CalorieProposalSheet), findsNothing);
      // Thông báo nhanh thứ hai hiện sau thông báo đầu (04 S-41).
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      expect(
        find.text('Mức calo đã cập nhật từ 2.210 thành 2.150 kcal.'),
        findsOneWidget,
      );
      expect((await profile()).calorieKcal, 2150);
      await openMe(tester);
      expect(find.text('2.150 kcal · Tự động'), findsOneWidget);
    },
  );

  testWidgets(
    'F02-R10: Tự động, số cân mới làm mức ước tính chênh dưới 10 kcal '
    '→ chỉ "Đã lưu", không có thông báo mức calo',
    (tester) async {
      await seedSetUp(db);
      await pump(tester);
      // 80 → 79,9 kg: mức ước tính vẫn 2.210 kcal sau khi làm tròn.
      await logWeight(tester, '79,9');
      expect(find.text(S.weightSaved('79,9 kg')), findsOneWidget);
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      expect(find.textContaining('Mức calo đã cập nhật'), findsNothing);
      expect(find.byType(CalorieProposalSheet), findsNothing);
    },
  );

  testWidgets(
    'F02-AC5, UX-AC13: Bạn tự đặt 1.900, ghi cân mới → S-53 "Theo cân nặng '
    'mới…"; vuốt đóng → đề xuất còn ở S-52, tab Tôi và dòng "Mức calo" có '
    'chấm; "Dùng 2.150 kcal" ở banner → Tự động, hết chấm',
    (tester) async {
      await seedManual(1900);
      await pump(tester);
      await logWeight(tester, '76');
      expect(find.byType(CalorieProposalSheet), findsOneWidget);
      expect(find.text(S.updateCalorieTitle), findsOneWidget);
      expect(
        find.text(
          'Theo cân nặng mới, mức ước tính là 2.150 kcal. Bạn muốn dùng con '
          'số này không?',
        ),
        findsOneWidget,
      );
      expect(find.text('Hiện tại Bạn đang dùng 1.900 kcal.'), findsOneWidget);
      expect(find.text('Dùng 2.150 kcal'), findsOneWidget);
      expect(find.text(S.keepCurrent), findsOneWidget);

      await swipeDown(tester);
      expect(find.byType(CalorieProposalSheet), findsNothing);
      final p = await profile();
      expect(
        (p.calorieMode, p.calorieKcal, p.caloriePendingKcal),
        (CalorieMode.manual, 1900, 2150),
      );
      expect(meDot(), isTrue);

      await openMe(tester);
      expect(find.text('1.900 kcal · Bạn tự đặt'), findsOneWidget);
      expect(find.byKey(const ValueKey('row-dot')), findsOneWidget);
      await tapKey(tester, 'row-calorie');
      expect(find.byKey(const ValueKey('proposal-banner')), findsOneWidget);
      expect(
        find.text('Dùng lại ước tính của app (2.150 kcal)'),
        findsOneWidget,
      );

      await tapKey(tester, 'banner-accept');
      expect(find.byKey(const ValueKey('proposal-banner')), findsNothing);
      final after = await profile();
      expect(
        (after.calorieMode, after.calorieKcal, after.caloriePendingKcal),
        (CalorieMode.auto, 2150, null),
      );
      expect(find.text(S.calorieAuto), findsOneWidget);
      expect(meDot(), isFalse);
    },
  );

  testWidgets('F02-R9: S-53 "Giữ nguyên" → vẫn Bạn tự đặt 1.900, không còn đề '
      'xuất, không có chấm; "Dùng {Y} kcal" ở S-53 → Tự động', (tester) async {
    await seedManual(1900);
    await pump(tester);
    await logWeight(tester, '76');
    await tapKey(tester, 'proposal-keep');
    expect(find.byType(CalorieProposalSheet), findsNothing);
    var p = await profile();
    expect(
      (p.calorieMode, p.calorieKcal, p.caloriePendingKcal),
      (CalorieMode.manual, 1900, null),
    );
    expect(meDot(), isFalse);

    // Ghi số khác trong tuần: số cân mới nhất đổi → đề xuất lại.
    await tapFinder(tester, find.widgetWithText(FilledButton, S.logThisWeek));
    await tester.enterText(
      find.descendant(
        of: find.byKey(const ValueKey('weight-input')),
        matching: find.byType(TextField),
      ),
      '72',
    );
    await tester.tap(find.widgetWithText(FilledButton, S.save).last);
    await tester.pumpAndSettle();
    await tapText(tester, S.replace);
    expect(find.byType(CalorieProposalSheet), findsOneWidget);
    await tapKey(tester, 'proposal-accept');
    p = await profile();
    expect(p.calorieMode, CalorieMode.auto);
    expect(p.caloriePendingKcal, isNull);
  });

  testWidgets('F02-AC6: Bạn tự đặt → S-52 có "Dùng lại ước tính của app (2.210 '
      'kcal)" → chế độ Tự động, 2.210 kcal', (tester) async {
    await seedManual(1900);
    await pump(tester);
    await openMe(tester);
    await tapKey(tester, 'row-calorie');
    expect(find.text(S.calorieManual), findsOneWidget);
    expect(find.text('Dùng lại ước tính của app (2.210 kcal)'), findsOneWidget);
    await tapKey(tester, 'use-app-estimate');
    final p = await profile();
    expect((p.calorieMode, p.calorieKcal), (CalorieMode.auto, 2210));
    expect(find.text(S.calorieAuto), findsOneWidget);
    expect(find.byKey(const ValueKey('use-app-estimate')), findsNothing);
  });

  testWidgets(
    'F02-R4, F02-R5: S-52 "Đặt mức khác" 1.300 (nam) → cảnh báo → "Vẫn lưu" → '
    'Bạn tự đặt kèm "Dưới ngưỡng an toàn"; đề xuất đang chờ bị bỏ',
    (tester) async {
      await seedSetUp(
        db,
        profile: completedProfile(
          mode: CalorieMode.manual,
          kcal: 1900,
        ).withPending(2090, CaloriePendingReason.weight),
      );
      await pump(tester);
      await openMe(tester);
      await tapKey(tester, 'row-calorie');
      await tapKey(tester, 'set-other-level');
      expect(find.text(S.setCalorieTitle), findsOneWidget);
      await tester.enterText(input(S.fieldDailyCalorie), '1.300');
      await tapText(tester, S.save);
      expect(find.text(S.lowCalorieWarning('1.500')), findsOneWidget);
      await tapText(tester, S.saveAnyway);
      final p = await profile();
      expect(
        (p.calorieMode, p.calorieKcal, p.caloriePendingKcal),
        (CalorieMode.manual, 1300, null),
      );
      expect(find.text(S.belowSafetyFloor), findsOneWidget);
      expect(find.byKey(const ValueKey('proposal-banner')), findsNothing);
      await tapFinder(tester, find.text(S.tabMe).first);
      expect(find.text('1.300 kcal · Dưới ngưỡng an toàn'), findsOneWidget);
    },
  );

  testWidgets(
    'F01-AC5, F01-R5: S-51 đổi mức vận động sang "Vận động nhẹ" → Lưu → "Đã '
    'lưu hồ sơ" rồi "Mức calo đã cập nhật…"; chiều cao sai → lỗi dưới ô',
    (tester) async {
      await seedSetUp(db);
      await pump(tester);
      await openMe(tester);
      await tapKey(tester, 'row-profile');
      // F01-R4: không có ô cân nặng; cân nặng hiện tại chỉ xem.
      expect(input(S.fieldWeight), findsNothing);
      await reveal(tester, find.text(S.logInWeightTab));
      await tester.scrollUntilVisible(
        input(S.fieldHeight),
        -200,
        scrollable: find.byType(Scrollable).first,
      );

      await tester.enterText(input(S.fieldHeight), '231');
      // Ô đang nhập giữ con trỏ trong tầm nhìn; ẩn bàn phím như khi chạm ra
      // ngoài rồi mới bấm "Lưu".
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      await tapText(tester, S.save);
      expect(find.text(S.invalidHeight), findsOneWidget);
      expect((await profile()).heightCm, 175);

      await tester.enterText(input(S.fieldHeight), '175');
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      await tapKey(tester, 'activity-light');
      await tapText(tester, S.save);
      expect(find.text(S.profileSaved), findsOneWidget);
      final p = await profile();
      final to = CalorieRules.forProfile(
        p,
        weightKgX10: 800,
        currentYear: 2026,
      )!.kcal;
      expect((p.activityLevel, p.calorieKcal), (ActivityLevel.light, to));
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      expect(
        find.text(
          'Mức calo đã cập nhật từ 2.210 thành ${_thousands(to)} kcal.',
        ),
        findsOneWidget,
      );
      // Đã về S-50 với tóm tắt mới.
      expect(find.text('${_thousands(to)} kcal · Tự động'), findsOneWidget);
    },
  );

  testWidgets(
    'F01-AC5: Bạn tự đặt, S-51 đổi mức vận động → S-53 "Theo thông tin mới…"',
    (tester) async {
      await seedManual(1900);
      await pump(tester);
      await openMe(tester);
      await tapKey(tester, 'row-profile');
      await tapKey(tester, 'activity-active');
      await tapText(tester, S.save);
      expect(find.byType(CalorieProposalSheet), findsOneWidget);
      expect(
        find.textContaining('Theo thông tin mới, mức ước tính là'),
        findsOneWidget,
      );
      expect(find.text('Hiện tại Bạn đang dùng 1.900 kcal.'), findsOneWidget);
    },
  );

  testWidgets('04 S-51: rời màn hình khi chưa lưu → "Bỏ các thay đổi chưa '
      'lưu?"; "Tiếp tục sửa" ở lại, "Bỏ" về S-50 không đổi hồ sơ', (
    tester,
  ) async {
    await seedSetUp(db);
    await pump(tester);
    await openMe(tester);
    await tapKey(tester, 'row-profile');
    await tapKey(tester, 'sex-female');
    await profileBack(tester);
    expect(find.text(S.discardChangesTitle), findsOneWidget);
    await tapText(tester, S.keepEditing);
    expect(find.text(S.bodyProfile), findsOneWidget);
    await profileBack(tester);
    await tapText(tester, S.discard);
    expect(find.byKey(const ValueKey('row-profile')), findsOneWidget);
    expect((await profile()).sex, Sex.male);
    expect(find.text('175 cm · 30 tuổi · Nam'), findsOneWidget);
  });

  testWidgets('04 S-51: "Ghi ở tab Cân nặng" → tab Cân nặng; cân nặng hiện tại '
      'là số cân mới nhất', (tester) async {
    await seedSetUp(db);
    await WeightRepository(db).put(LocalDate(2026, 10, 12), 725);
    await pump(tester);
    await openMe(tester);
    await tapKey(tester, 'row-profile');
    await reveal(tester, find.text('72,5 kg'));
    await tapKey(tester, 'go-weight-tab');
    expect(find.text(S.logThisWeek), findsOneWidget);
  });

  testWidgets('F01-E2, ED-07: mở app ngày 01/01/2027 ở chế độ Bạn tự đặt → đề '
      'xuất "Theo thông tin mới…" chờ ở S-52, tab Tôi có chấm', (tester) async {
    await seedManual(1900);
    clock.set(DateTime(2027, 1, 1, 8));
    await pump(tester, marks: MemoryLocalMarks(2026));
    final p = await profile();
    expect(p.caloriePendingReason, CaloriePendingReason.profile);
    expect(meDot(), isTrue);
    await openMe(tester);
    await tapKey(tester, 'row-calorie');
    expect(
      find.textContaining('Theo thông tin mới, mức ước tính là'),
      findsOneWidget,
    );
  });
}

String _thousands(int n) {
  final s = '$n';
  return s.length <= 3
      ? s
      : '${s.substring(0, s.length - 3)}.${s.substring(s.length - 3)}';
}
