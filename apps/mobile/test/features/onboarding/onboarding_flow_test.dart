import 'dart:convert';

import 'package:api_contract/api_contract.dart';
import 'package:domain/domain.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/app/app.dart';
import 'package:mobile/app/shell/app_tab_bar.dart';
import 'package:mobile/app/strings_vi.dart';
import 'package:mobile/core/widgets/labeled_field.dart';
import 'package:mobile/data/db/app_database.dart';
import 'package:mobile/features/me/data/profile_repository.dart';
import 'package:mobile/features/onboarding/application/setup_state.dart';
import 'package:mobile/features/onboarding/data/onboarding_draft_repository.dart';
import 'package:mobile/features/weight/data/weight_repository.dart';

import '../../support/app_harness.dart';
import '../../support/fake_server.dart';

void main() {
  late AppDatabase db;
  late FakeServer server;
  late FixedClock clock;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    server = FakeServer();
    clock = FixedClock(DateTime(2026, 10, 7, 18, 42));
  });

  /// Mở app đã đăng nhập, đọc trạng thái thiết lập thật từ [db]. Đồng hồ
  /// harness: 18:42 thứ 4 07/10/2026.
  Future<ProviderContainer> pump(WidgetTester tester) async {
    tester.view
      ..physicalSize = const Size(390 * 3, 844 * 3)
      ..devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final container = ProviderContainer(
      retry: (_, _) => null,
      overrides: appOverrides(
        server: server,
        db: db,
        clock: clock,
        onboarded: false,
        // Như main.dart: đọc trạng thái thiết lập trước khi vẽ màn hình đầu.
        initialSetup: SetupState.of(await ProfileRepository(db).get()),
      ),
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const HealthApp()),
    );
    await tester.pumpAndSettle();
    return container;
  }

  Finder input(String label) => find.descendant(
    of: find.byWidgetPredicate((w) => w is LabeledField && w.label == label),
    matching: find.byType(TextField),
  );

  Future<void> tapText(WidgetTester tester, String text) async {
    final f = find.text(text).last;
    await tester.ensureVisible(f);
    await tester.pumpAndSettle();
    await tester.tap(f);
    await tester.pumpAndSettle();
  }

  Future<void> tapKey(WidgetTester tester, String key) async {
    final f = find.byKey(ValueKey(key));
    await tester.ensureVisible(f);
    await tester.pumpAndSettle();
    await tester.tap(f);
    await tester.pumpAndSettle();
  }

  /// S-03 theo F02-AC1: nam, 1996 (30 tuổi), 175 cm, 80 kg, vận động vừa.
  Future<void> fillProfile(
    WidgetTester tester, {
    String height = '175',
    String weight = '80',
  }) async {
    await tester.enterText(input(S.fieldHeight), height);
    await tapKey(tester, 'birth-year-field');
    await tapText(tester, S.done); // bánh xe mặc định 30 tuổi → 1996
    await tapKey(tester, 'sex-male');
    await tapKey(tester, 'activity-moderate');
    await tester.enterText(input(S.fieldInitialWeight), weight);
    await tester.pumpAndSettle();
  }

  Future<Profile?> profile() => ProfileRepository(db).get();

  Future<List<Map<String, Object?>>> outbox(String entity) async => [
    for (final o in await db.select(db.outbox).get())
      if (o.entity == entity)
        {
          'key': o.entityKey,
          'op': o.op,
          'data': o.payload == null ? null : jsonDecode(o.payload!),
        },
  ];

  testWidgets(
    'F10-AC1, NAV-7: chưa bấm "Tôi đã hiểu" thì không đi tiếp, không có nút bỏ '
    'qua, không có thanh tab',
    (tester) async {
      await pump(tester);
      expect(find.text(S.disclaimerTitle), findsOneWidget);
      expect(find.text(S.stepOf(1)), findsOneWidget);
      expect(find.text(S.back), findsNothing);
      expect(find.byType(AppTabBar), findsNothing);
      for (final p in [
        S.disclaimerPoint1,
        S.disclaimerPoint2,
        S.disclaimerPoint3,
        S.disclaimerPoint4,
      ]) {
        expect(find.text(p), findsOneWidget);
      }
      expect(find.byType(FilledButton), findsOneWidget);
      expect(find.byType(OutlinedButton), findsNothing);
      expect(await profile(), isNull);

      await tapText(tester, S.iUnderstand);
      expect(find.text(S.profileTitle), findsOneWidget);
      expect(find.text(S.stepOf(2)), findsOneWidget);
      final p = (await profile())!;
      expect(p.onboardingStep, 2);
      expect(p.disclaimerAcceptedAt, DateTime(2026, 10, 7, 18, 42));
      expect(
        (await outbox('profile')).single['data'],
        containsPair('onboardingStep', 2),
      );
    },
  );

  testWidgets(
    'F01-AC1, OB-5: "Tiếp tục" luôn bấm được; thiếu thông tin → lỗi dưới từng '
    'ô, không lưu gì',
    (tester) async {
      await pump(tester);
      await tapText(tester, S.iUnderstand);
      await tapText(tester, S.continueLabel);
      for (final e in [
        S.invalidHeight,
        S.invalidBirthYear,
        S.missingSex,
        S.missingActivityLevel,
        S.invalidWeight,
      ]) {
        expect(find.text(e), findsOneWidget, reason: e);
      }
      expect((await profile())!.onboardingStep, 2);
      expect(await WeightRepository(db).all(), isEmpty);
      // Cuộn tới ô lỗi đầu tiên: ô chiều cao đang hiện trên màn hình.
      expect(tester.getTopLeft(input(S.fieldHeight)).dy, lessThan(844));

      // Lỗi biến mất khi Bạn sửa ô đó (04 §6.13.5).
      await tester.enterText(input(S.fieldHeight), '17');
      await tester.pumpAndSettle();
      expect(find.text(S.invalidHeight), findsNothing);
    },
  );

  testWidgets('F01-AC2: chiều cao 119 hoặc 231 → báo lỗi F01-V1', (
    tester,
  ) async {
    await pump(tester);
    await tapText(tester, S.iUnderstand);
    for (final h in ['119', '231']) {
      await fillProfile(tester, height: h);
      await tapText(tester, S.continueLabel);
      expect(find.text(S.invalidHeight), findsOneWidget, reason: h);
      expect(find.text(S.profileTitle), findsOneWidget);
    }
  });

  for (final typed in ['72,5', '72.5']) {
    testWidgets('F01-AC3, F01-R3: cân "$typed" → 72,5 kg của tuần hiện tại', (
      tester,
    ) async {
      await pump(tester);
      await tapText(tester, S.iUnderstand);
      await fillProfile(tester, weight: typed);
      await tapText(tester, S.continueLabel);
      expect(find.text(S.calorieTitle), findsOneWidget);
      expect(await WeightRepository(db).all(), [
        (week: LocalDate(2026, 10, 5), kgX10: 725),
      ]);
      expect(await outbox('weight'), [
        {
          'key': '2026-10-05',
          'op': 'upsert',
          'data': {'weightKgX10': 725},
        },
      ]);
    });
  }

  testWidgets(
    'Demo VS-03 / F02-AC1: hồ sơ F02-AC1 → S-04 hiện 2.210 kcal, Tự động, nhãn '
    '"tham khảo"; "Giữ mức này" → Bước 4/5',
    (tester) async {
      await pump(tester);
      await tapText(tester, S.iUnderstand);
      await fillProfile(tester);
      expect(find.text(S.ageYears(30)), findsOneWidget);
      await tapText(tester, S.continueLabel);

      expect(find.text(S.stepOf(3)), findsOneWidget);
      expect(find.text(S.calorieAuto), findsOneWidget);
      expect(find.text(S.referenceTag), findsOneWidget);
      expect(find.text('2.210 kcal', findRichText: true), findsOneWidget);
      expect(find.text(S.belowMaintenance('500')), findsOneWidget);
      expect(find.byKey(const ValueKey('calorie-note')), findsNothing);

      await tapText(tester, S.keepThisLevel);
      expect(find.text(S.stepOf(4)), findsOneWidget);
      final p = (await profile())!;
      expect(
        (p.onboardingStep, p.calorieMode, p.calorieKcal, p.heightCm, p.sex),
        (4, CalorieMode.auto, 2210, 175, Sex.male),
      );
      expect(p.birthYear, 1996);
      expect(p.activityLevel, ActivityLevel.moderate);
    },
  );

  testWidgets(
    'F02-AC3, F02-R5: tự đặt 1.300 kcal (nam) → cảnh báo trước khi lưu, vẫn '
    'cho lưu; nhãn "Dưới ngưỡng an toàn"',
    (tester) async {
      await pump(tester);
      await tapText(tester, S.iUnderstand);
      await fillProfile(tester);
      await tapText(tester, S.continueLabel);

      await tapText(tester, S.setOtherLevel);
      expect(find.text(S.setCalorieTitle), findsOneWidget);
      await tester.enterText(input(S.fieldDailyCalorie), '799');
      await tapText(tester, S.save);
      expect(find.text(S.invalidManualKcal), findsOneWidget);

      await tester.enterText(input(S.fieldDailyCalorie), '1.300');
      await tapText(tester, S.save);
      expect(find.text(S.lowCalorieTitle), findsOneWidget);
      expect(find.text(S.lowCalorieWarning('1.500')), findsOneWidget);
      await tapText(tester, S.editAgain);
      expect(find.text(S.setCalorieTitle), findsOneWidget);
      expect((await profile())!.calorieKcal, isNull);

      await tapText(tester, S.save);
      await tapText(tester, S.saveAnyway);
      expect(find.text(S.stepOf(4)), findsOneWidget);
      final p = (await profile())!;
      expect((p.calorieMode, p.calorieKcal), (CalorieMode.manual, 1300));
      expect(CalorieRules.menuKcal(p.calorieKcal!, p.sex!), 1500);

      // OB-2: quay lại bước 3 thấy đúng mức đã đặt.
      await tapText(tester, S.back);
      expect(find.text(S.calorieManual), findsOneWidget);
      expect(find.text(S.belowSafetyFloor), findsOneWidget);
      expect(find.text('1.300 kcal', findRichText: true), findsOneWidget);
    },
  );

  testWidgets('F02-AC2: nữ 55 tuổi 150 cm 45 kg ít vận động → 1.200 kcal kèm '
      'ghi chú F02-E2', (tester) async {
    // OB-3: thông tin nhập dở lần trước được giữ (nháp trên máy).
    await ProfileRepository(db).put(
      Profile(onboardingStep: 2, disclaimerAcceptedAt: DateTime(2026, 10, 7)),
    );
    await OnboardingDraftRepository(db).save(
      const ProfileDraft(
        height: '150',
        birthYear: 1971,
        sex: Sex.female,
        activityLevel: ActivityLevel.sedentary,
        weight: '45',
      ),
    );
    await pump(tester);
    expect(find.text(S.profileTitle), findsOneWidget);
    expect(find.text('1971'), findsOneWidget);
    expect(find.text(S.ageYears(55)), findsOneWidget);
    await tapText(tester, S.continueLabel);
    expect(find.text('1.200 kcal', findRichText: true), findsOneWidget);
    expect(find.text(S.noteMaintenanceBelowFloor), findsOneWidget);
    expect(find.textContaining('Thấp hơn mức duy trì'), findsNothing);
  });

  testWidgets(
    'OB-3, UX-AC3: nhập dở rồi thoát app → mở lại đúng bước, thông tin còn '
    'nguyên; thoát ở bước 3 → mở lại bước 3',
    (tester) async {
      await pump(tester);
      await tapText(tester, S.iUnderstand);
      await tester.enterText(input(S.fieldHeight), '168');
      await tester.pumpAndSettle();

      // Mở lại app (container mới, cùng database).
      await tester.pumpWidget(const SizedBox());
      await pump(tester);
      expect(find.text(S.stepOf(2)), findsOneWidget);
      expect(find.text('168'), findsOneWidget);

      await fillProfile(tester);
      await tapText(tester, S.continueLabel);
      expect(find.text(S.stepOf(3)), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      await pump(tester);
      expect(find.text(S.stepOf(3)), findsOneWidget);
      expect(find.text('2.210 kcal', findRichText: true), findsOneWidget);
    },
  );

  testWidgets(
    'OB-2: quay lại bước 2 không mất thông tin; lưu lại ở tuần khác không '
    'thành 2 số cân',
    (tester) async {
      await pump(tester);
      await tapText(tester, S.iUnderstand);
      await fillProfile(tester);
      await tapText(tester, S.continueLabel);
      await tapText(tester, S.back);
      expect(find.text(S.stepOf(2)), findsOneWidget);
      expect(find.text('175'), findsOneWidget);
      expect(find.text('1996'), findsOneWidget);
      expect(find.text('80'), findsOneWidget);

      // Thiết lập kéo sang tuần sau (ED-06): cân ban đầu chuyển sang tuần mới.
      clock.set(DateTime(2026, 10, 12, 8));
      await tester.enterText(input(S.fieldInitialWeight), '79,5');
      await tapText(tester, S.continueLabel);
      expect(await WeightRepository(db).all(), [
        (week: LocalDate(2026, 10, 12), kgX10: 795),
      ]);
      expect(
        [for (final w in await outbox('weight')) (w['key'], w['op'])],
        [('2026-10-05', 'delete'), ('2026-10-12', 'upsert')],
      );
    },
  );

  testWidgets(
    'Q-2: "Đặt mức khác" có thay đổi chưa lưu → chạm vùng mờ hỏi "Bỏ các thay '
    'đổi chưa lưu?"',
    (tester) async {
      await pump(tester);
      await tapText(tester, S.iUnderstand);
      await fillProfile(tester);
      await tapText(tester, S.continueLabel);
      await tapText(tester, S.setOtherLevel);
      await tester.enterText(input(S.fieldDailyCalorie), '1900');
      await tester.pumpAndSettle();

      await tester.tapAt(const Offset(195, 60));
      await tester.pumpAndSettle();
      expect(find.text(S.discardChangesTitle), findsOneWidget);
      await tapText(tester, S.keepEditing);
      expect(find.text(S.setCalorieTitle), findsOneWidget);

      await tester.fling(
        find.text(S.setCalorieTitle),
        const Offset(0, 400),
        1000,
      );
      await tester.pumpAndSettle();
      expect(find.text(S.discardChangesTitle), findsOneWidget);
      await tapText(tester, S.discard);
      expect(find.text(S.setCalorieTitle), findsNothing);
      expect((await profile())!.calorieKcal, isNull);
    },
  );

  testWidgets(
    '04 §6.13.2, F10-R4: chạm nhãn "tham khảo" → ý chính F10-R1, "Xem đầy đủ" '
    '→ S-55',
    (tester) async {
      await pump(tester);
      await tapText(tester, S.iUnderstand);
      await fillProfile(tester);
      await tapText(tester, S.continueLabel);
      await tapKey(tester, 'reference-tag');
      expect(find.text(S.aboutReferenceTitle), findsOneWidget);
      expect(find.text(S.disclaimerPoint4), findsOneWidget);
      await tapText(tester, S.seeFull);
      expect(find.text(S.disclaimerTitle), findsOneWidget);
      expect(find.text(S.iUnderstand), findsNothing);
      await tapText(tester, S.back);
      expect(find.text(S.calorieTitle), findsOneWidget);
    },
  );

  testWidgets(
    'OB-6: đăng nhập tài khoản đang thiết lập dở ở bước 3 → lấy hồ sơ về máy, '
    'mở đúng S-04 với thông tin đã nhập',
    (tester) async {
      server
        ..on(
          'POST',
          '/v1/auth/login',
          (_) => (
            200,
            {
              'accessToken': 'A1',
              'refreshToken': 'R1',
              'accessTokenExpiresAt': '2099-01-01T00:00:00.000Z',
            },
          ),
        )
        ..on(
          'GET',
          '/v1/me',
          (_) => (
            200,
            {
              'userId': 'u1',
              'phone': '0912345678',
              'displayName': 'Minh',
              'onboardingState': 'in_progress',
              'onboardingStep': 3,
            },
          ),
        )
        ..on(
          'GET',
          '/v1/sync/pull',
          (_) => (
            200,
            {
              'changes': [
                {
                  'entity': 'profile',
                  'key': 'me',
                  'deleted': false,
                  'serverVersion': 5,
                  'data': const ProfileCodec().encode(
                    Profile(
                      onboardingStep: 3,
                      disclaimerAcceptedAt: DateTime.utc(2026, 10, 6),
                      heightCm: 175,
                      birthYear: 1996,
                      sex: Sex.male,
                      activityLevel: ActivityLevel.moderate,
                    ),
                  ),
                },
                {
                  'entity': 'weight',
                  'key': '2026-10-05',
                  'deleted': false,
                  'serverVersion': 6,
                  'data': {'weightKgX10': 800},
                },
              ],
              'nextCursor': 6,
              'hasMore': false,
              'remaining': 0,
              'meta': {'serverTime': '2026-10-07T11:42:00.000Z'},
            },
          ),
        );
      tester.view
        ..physicalSize = const Size(390 * 3, 844 * 3)
        ..devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      final container = ProviderContainer(
        retry: (_, _) => null,
        overrides: appOverrides(
          server: server,
          db: db,
          clock: clock,
          session: null,
        ),
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const HealthApp(),
        ),
      );
      await tester.pumpAndSettle();
      await tapText(tester, S.login);
      await tester.enterText(input(S.fieldPhone), '0912345678');
      await tester.enterText(input(S.fieldPassword), 'matkhau123');
      await tester.tap(find.widgetWithText(FilledButton, S.login));
      await tester.pumpAndSettle();

      expect(find.text(S.stepOf(3)), findsOneWidget);
      expect(find.text('2.210 kcal', findRichText: true), findsOneWidget);
    },
  );
}
