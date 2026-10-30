import 'dart:async';

import 'package:domain/domain.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/app/app.dart';
import 'package:mobile/app/router.dart';
import 'package:mobile/app/strings_vi.dart';
import 'package:mobile/app/theme.dart';
import 'package:mobile/data/db/app_database.dart';
import 'package:mobile/features/schedule/application/month_materializer.dart';
import 'package:mobile/features/schedule/data/schedule_repository.dart';
import 'package:mobile/features/schedule/presentation/day_sheet.dart';
import 'package:mobile/features/schedule/presentation/muscle_picker.dart';
import 'package:mobile/features/schedule/presentation/schedule_screen.dart';
import 'package:mobile/features/workout/presentation/session_screen.dart';
import 'package:mobile/ui/components/ironly_button.dart';
import 'package:mobile/ui/components/ironly_tab_bar.dart';

import '../../support/app_harness.dart';
import '../../support/fake_notifications.dart';
import '../../support/fake_server.dart';
import '../../support/fake_sync.dart';
import '../../support/golden.dart' show maxTextScale;
import '../../support/library_fixture.dart';
import '../../support/schedule_fixture.dart';

void main() {
  late AppDatabase db;
  late FixedClock clock;
  late FakeScheduler scheduler;
  late FakeNotificationGateway notifications;
  late ProviderContainer container;

  // templateAc2 thiết lập 12:00 thứ 4 07/10; hôm nay 10:00 thứ 4 14/10.
  final wed14 = LocalDate(2026, 10, 14);

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    clock = FixedClock(DateTime(2026, 10, 14, 10));
    scheduler = FakeScheduler();
    notifications = FakeNotificationGateway();
  });

  Future<void> pump(WidgetTester tester) async {
    tester.view
      ..physicalSize = const Size(390 * 3, 844 * 3)
      ..devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    container = ProviderContainer(
      retry: (_, _) => null,
      overrides: appOverrides(
        db: db,
        clock: clock,
        scheduler: scheduler,
        server: FakeServer(),
        notifications: notifications,
      ),
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const IronlyApp()),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(IronlyTabBar),
        matching: find.text(S.tabTraining),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> tapKey(WidgetTester tester, String key) async {
    final f = find.byKey(ValueKey(key));
    // Phần tử ngoài khung nhìn (S-22 dài, S-21 cuộn): cuộn danh sách gần nhất.
    if (f.evaluate().isEmpty) {
      await tester.scrollUntilVisible(
        find.byKey(ValueKey(key), skipOffstage: false),
        200,
        scrollable: find.byType(Scrollable).last,
      );
    }
    await tester.ensureVisible(f);
    await tester.pumpAndSettle();
    await tester.tap(f);
    await tester.pumpAndSettle();
  }

  /// Mở S-21 của ngày [date] như chạm vào dòng ở S-20.
  /// "Lưu" của S-22 (`weekly-save`) hoặc của khối sửa trong S-21 (`day-save`).
  Future<void> tapSave(WidgetTester tester) async {
    final weekly = find.byKey(const ValueKey('weekly-save'));
    await tapKey(
      tester,
      weekly.evaluate().isEmpty ? 'day-save' : 'weekly-save',
    );
  }

  Future<void> open(WidgetTester tester, LocalDate date) async {
    unawaited(showDaySheet(tester.element(find.byType(ScheduleScreen)), date));
    await tester.pumpAndSettle();
  }

  Future<PlanDay> day(int d) async =>
      (await ScheduleRepository(db).day(LocalDate(2026, 10, d)))!;

  group('UX-AC8: S-21 chỉ hiện thao tác hợp lệ', () {
    testWidgets(
      'ngày tập hôm nay chưa đến giờ (mock S-21-1): đổi giờ, đổi nhóm cơ, cho '
      'nghỉ; chạm dòng ở S-20 mở S-21',
      (tester) async {
        await seedSetUp(db);
        await pump(tester);
        await tapKey(tester, 'day-2026-10-16');
        expect(find.text('Thứ 6, 16/10'), findsOneWidget);
        // Bản 4: dòng chữ phụ "Vai · 18:00", không "Theo lịch tuần" (FR4-04).
        expect(find.text('Vai · 18:00'), findsOneWidget);
        for (final k in ['day-change-time', 'day-change-muscles', 'day-rest']) {
          expect(find.byKey(ValueKey(k)), findsOneWidget, reason: k);
        }
        expect(find.byKey(const ValueKey('day-revert')), findsNothing);
        expect(find.text(S.onlyThisDay), findsNothing);
      },
    );

    testWidgets('ngày nghỉ từ ngày mai: chỉ "Lên lịch tập ngày này"', (
      tester,
    ) async {
      await seedSetUp(db);
      await pump(tester);
      await open(tester, LocalDate(2026, 10, 15));
      expect(find.text(S.scheduleThisDay), findsOneWidget);
      expect(find.text(S.logExtraSession), findsNothing);
      expect(find.byKey(const ValueKey('day-rest')), findsNothing);
    });

    testWidgets(
      'hôm nay nghỉ (mock S-21-2): lên lịch tập hôm nay · ghi buổi tập thêm; '
      'đã có buổi tập thêm → chỉ xem "Buổi tập thêm · {nhóm cơ}", "Đã chốt '
      'khi lưu", câu F03-E4 (04 Bản 2 S-21)',
      (tester) async {
        clock.set(DateTime(2026, 10, 15, 9));
        await seedSetUp(db);
        await pump(tester);
        await open(tester, LocalDate(2026, 10, 15));
        expect(find.text('Thứ 5, 15/10'), findsOneWidget);
        expect(find.text(S.scheduleToday), findsOneWidget);
        expect(find.text(S.logExtraSession), findsOneWidget);
        await tapKey(tester, 'day-log-extra');
        expect(find.byKey(const ValueKey('extra-sheet')), findsOneWidget);

        await tester.pumpWidget(const SizedBox());
        await seedExtra(db, LocalDate(2026, 10, 15), const [MuscleGroup.abs]);
        await pump(tester);
        await open(tester, LocalDate(2026, 10, 15));
        expect(find.text(S.scheduleToday), findsNothing);
        expect(find.text(S.logExtraSession), findsNothing);
        // Bản 4: "Nghỉ · Bụng" + dấu "+" ở tiêu đề; không câu "Đã chốt khi
        // lưu", không câu F03-E4 (FR4-04).
        expect(find.text(S.restWithExtra('Bụng')), findsOneWidget);
        expect(find.bySemanticsLabel(S.extraSession), findsOneWidget);
        expect(find.byKey(const ValueKey('locked-on-save')), findsNothing);
        expect(find.text(S.extraBlocksSchedule), findsNothing);
      },
    );

    testWidgets(
      'buổi Không tập (tự động) trong 7 ngày → "Đổi sang Đã tập" (không còn '
      'S-23); ngày nghỉ đã qua → S-24; quá 7 ngày → khóa; chủ nhật → chỉ xem',
      (tester) async {
        await seedSetUp(db);
        await pump(tester);
        await open(tester, LocalDate(2026, 10, 9));
        expect(find.byKey(const ValueKey('day-change-time')), findsNothing);
        expect(find.text(S.changeableUntil('16/10')), findsNothing);
        expect(
          find.byKey(const ValueKey('change-to-done-2026-10-09')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('mark-skipped-2026-10-09')),
          findsNothing,
        );
        await tester.tapAt(const Offset(195, 60));
        await tester.pumpAndSettle();

        await open(tester, LocalDate(2026, 10, 13));
        await tapKey(tester, 'day-log-extra');
        expect(find.byKey(const ValueKey('extra-sheet')), findsOneWidget);
        await tester.tapAt(const Offset(195, 60));
        await tester.pumpAndSettle();

        clock.set(DateTime(2026, 10, 16, 10));
        scheduler.fireSync();
        await tester.pumpAndSettle();
        await open(tester, LocalDate(2026, 10, 7));
        // Bản 4: ổ khóa cạnh dòng tóm tắt, nút "Đổi sang Đã tập" mờ (F4-R6).
        expect(find.bySemanticsLabel(S.lockedNote), findsOneWidget);
        expect(
          find.byKey(const ValueKey('change-to-done-2026-10-07-locked')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('change-to-done-2026-10-07')),
          findsNothing,
        );
        await tester.tapAt(const Offset(195, 60));
        await tester.pumpAndSettle();

        await open(tester, LocalDate(2026, 10, 18));
        expect(find.text('Chủ nhật, 18/10'), findsOneWidget);
        expect(find.text(S.sundayRest), findsNothing);
        expect(find.byType(IronlyButton), findsNothing);
      },
    );
  });

  testWidgets(
    'UX-AC26, UA2-07: S-21 buổi Chờ đánh dấu có "Đã tập" · "Không tập" ngay '
    'trong bảng; "Đã tập" → S-65 (buổi đã qua: không có dòng 2) → Lưu → bảng '
    'đóng, "Đã ghi: tập Lưng"; "Không tập" → lưu ngay, bảng đóng, thông báo có '
    '"Đổi sang Đã tập"',
    (tester) async {
      clock.set(DateTime(2026, 10, 8, 10));
      await seedSetUp(db);
      await pump(tester);
      final wed7 = LocalDate(2026, 10, 7);
      await open(tester, wed7);
      expect(find.bySemanticsLabel(S.statusAwaiting), findsWidgets);
      await tapKey(tester, 'mark-done-${wed7.toKey()}');
      expect(find.text(S.doneConfirmTitle('Lưng')), findsOneWidget);
      expect(find.byKey(const ValueKey('lock-confirm-line2')), findsNothing);
      await tapKey(tester, 'lock-confirm-cancel');
      expect(
        find.byKey(ValueKey('mark-done-${wed7.toKey()}')),
        findsOneWidget,
        reason: 'Hủy: bảng vẫn mở, không đổi gì',
      );
      await tapKey(tester, 'mark-done-${wed7.toKey()}');
      await tapKey(tester, 'lock-confirm-save');
      expect(find.byKey(const ValueKey('day-summary')), findsNothing);
      expect(find.text(S.markedDone('Lưng')), findsOneWidget);
      expect((await day(7)).mark, DayMark.done);

      await open(tester, wed7);
      // Bản 4: dấu tích ở tiêu đề, không câu "Đã chốt khi lưu".
      expect(find.bySemanticsLabel(S.sessionDone), findsWidgets);
      expect(find.byKey(const ValueKey('locked-on-save')), findsNothing);
      expect(
        find.byKey(ValueKey('mark-skipped-${wed7.toKey()}')),
        findsNothing,
      );
    },
  );

  testWidgets('UR2-05: "Không tập" trong S-21 → lưu ngay, bảng đóng, thông báo '
      '"Đã ghi: không tập" có "Đổi sang Đã tập", không có Hoàn tác', (
    tester,
  ) async {
    clock.set(DateTime(2026, 10, 8, 10));
    await seedSetUp(db);
    await pump(tester);
    final wed7 = LocalDate(2026, 10, 7);
    await open(tester, wed7);
    await tapKey(tester, 'mark-skipped-${wed7.toKey()}');
    expect(find.byKey(const ValueKey('lock-confirm')), findsNothing);
    expect(find.byKey(const ValueKey('day-summary')), findsNothing);
    expect(find.text(S.markedSkipped), findsOneWidget);
    expect(find.text(S.changeToDone), findsOneWidget);
    expect((await day(7)).mark, DayMark.skipped);
  });

  testWidgets(
    'F03-AC8 (spec ghi thứ 5 23/10; năm 2026 thứ 5 là 22/10): "Lên lịch tập '
    'ngày này" → chưa chọn nhóm cơ báo F03-V4 → Bụng 18:00 → "Đã sửa riêng '
    'Thứ 5 22/10", S-20 có nhãn "Đã sửa riêng"; "Trả về theo lịch tuần" → '
    'hộp xác nhận → lại nghỉ',
    (tester) async {
      await seedSetUp(db, profile: completedProfile(remindersEnabled: true));
      await pump(tester);
      await open(tester, LocalDate(2026, 10, 22));
      await tapKey(tester, 'day-schedule');
      await tapSave(tester);
      expect(find.text(S.missingTimeOrMuscles), findsOneWidget);
      await tapKey(tester, 'muscle-abs');
      await tapSave(tester);
      expect(find.text('Đã sửa riêng Thứ 5 22/10'), findsOneWidget);
      final d = await day(22);
      expect((d.isWorkout, d.time), (true, LocalTime(18, 0)));
      expect(d.muscles, [MuscleGroup.abs]);
      expect(
        notifications.scheduled.map((n) => n.at),
        contains(DateTime(2026, 10, 22, 17)),
      );
      // Bản 4: chấm "Đã sửa riêng" (VoiceOver đọc trong nhãn dòng); danh
      // sách tuần hiện tuần của ô vừa chạm.
      await tapKey(tester, 'month-cell-2026-10-22');
      await tester.tapAt(const Offset(195, 60));
      await tester.pumpAndSettle();
      final row = find.byKey(const ValueKey('day-2026-10-22'));
      expect(
        find.descendant(
          of: row,
          matching: find.bySemanticsLabel(RegExp(S.overridden)),
        ),
        findsOneWidget,
      );

      await tapKey(tester, 'day-2026-10-22');
      await tapKey(tester, 'day-revert');
      expect(find.text(S.revertConfirmTitle), findsOneWidget);
      await tapKey(tester, 'confirm-revert');
      expect((await day(22)).isWorkout, isFalse);
      expect((await day(22)).source, DaySource.template);
    },
  );

  testWidgets(
    'F04-E4: "Cho nghỉ ngày này" → hộp xác nhận "Cho nghỉ Thứ 4, 14/10? Nhắc '
    'của ngày này sẽ được hủy." → ngày nghỉ, nhắc bị hủy; F03-E2: đổi giờ hôm '
    'nay còn chưa đầy 1 giờ → ghi chú không có nhắc',
    (tester) async {
      clock.set(DateTime(2026, 10, 14, 17, 10));
      await seedSetUp(db, profile: completedProfile(remindersEnabled: true));
      await pump(tester);
      await open(tester, wed14);
      await tapKey(tester, 'day-change-time');
      expect(find.byKey(const ValueKey('under-hour-note')), findsOneWidget);
      expect(find.text(S.noReminderUnderHour), findsOneWidget);
      await tester.tapAt(const Offset(195, 60));
      await tester.pumpAndSettle();
      if (find.text(S.discardChangesTitle).evaluate().isNotEmpty) {
        await tester.tap(find.text(S.discard));
        await tester.pumpAndSettle();
      }

      await open(tester, wed14);
      await tapKey(tester, 'day-rest');
      expect(
        find.text('Cho nghỉ Thứ 4, 14/10? Nhắc của ngày này sẽ được hủy.'),
        findsOneWidget,
      );
      await tapKey(tester, 'confirm-rest');
      expect((await day(14)).isWorkout, isFalse);
      expect(
        notifications.scheduled.where(
          (n) => LocalDate.fromDateTime(n.at) == wed14,
        ),
        isEmpty,
      );
      expect(find.text('Đã sửa riêng Thứ 4 14/10'), findsOneWidget);
    },
  );

  testWidgets(
    'UX-AC9, F03-AC5 → AC7: S-22 đổi thứ 4 sang Vai → "Đã lưu lịch tuần", '
    'banner + chấm ở tab Lịch tập; Chia lại → hộp xác nhận → "Đã chia lại '
    'lịch từ 14/10 đến 31/10. Giữ nguyên 1 ngày Bạn đã sửa riêng.", banner và '
    'chấm biến mất',
    (tester) async {
      await seedSetUp(db);
      final schedule = ScheduleRepository(db);
      await schedule.putDay(
        OverrideRules.override(await day(21), now: clock.now()),
      );
      await pump(tester);
      expect(find.byKey(const ValueKey('redistribute-banner')), findsNothing);
      expect(find.byKey(const ValueKey('tab-dot-schedule')), findsNothing);

      await tapKey(tester, 'open-weekly');
      expect(find.text(S.weeklyEditHint), findsNothing);
      await tapKey(tester, 'day-row-3');
      await tapKey(tester, 'muscle-back');
      await tapKey(tester, 'muscle-shoulders');
      await tapSave(tester);
      expect(find.text(S.templateSaved), findsOneWidget);
      expect(find.byKey(const ValueKey('redistribute-banner')), findsOneWidget);
      expect(find.text(S.templateChangedBanner), findsOneWidget);
      expect(find.byKey(const ValueKey('tab-dot-schedule')), findsOneWidget);
      expect((await day(14)).muscles, [MuscleGroup.back], reason: 'F03-AC5');

      await tapKey(tester, 'redistribute');
      expect(find.text(S.redistributeTitle), findsOneWidget);
      expect(find.text(S.redistributeBody), findsOneWidget);
      expect(find.text(S.redistributeNote), findsOneWidget);
      await tapKey(tester, 'confirm-redistribute');
      expect(
        find.text(
          'Đã chia lại lịch từ 14/10 đến 31/10. Giữ nguyên 1 ngày Bạn đã sửa '
          'riêng.',
        ),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('redistribute-banner')), findsNothing);
      expect(find.byKey(const ValueKey('tab-dot-schedule')), findsNothing);
      expect((await day(14)).muscles, [MuscleGroup.shoulders]);
      expect((await day(21)).isWorkout, isFalse);
    },
  );

  testWidgets(
    'F03-E5: lịch tuần đã đổi nhưng chưa chia lại, sang tháng mới → tháng mới '
    'theo lịch tuần mới, banner biến mất',
    (tester) async {
      await seedSetUp(db);
      await pump(tester);
      await tapKey(tester, 'open-weekly');
      await tapKey(tester, 'day-row-3');
      await tapKey(tester, 'muscle-back');
      await tapKey(tester, 'muscle-shoulders');
      await tapSave(tester);
      expect(find.byKey(const ValueKey('redistribute-banner')), findsOneWidget);

      clock.set(DateTime(2026, 11, 1, 0, 0, 1));
      await container.read(monthMaterializerProvider).run();
      scheduler.fireSync();
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('redistribute-banner')), findsNothing);
      expect(
        (await ScheduleRepository(db).day(LocalDate(2026, 11, 4)))!.muscles,
        [MuscleGroup.shoulders],
      );
    },
  );

  testWidgets(
    'S-22: đổi rồi bấm "‹ Lịch tập" → hỏi "Bỏ các thay đổi chưa lưu?"; Bỏ → '
    'về S-20, lịch tuần không đổi',
    (tester) async {
      await seedSetUp(db);
      await pump(tester);
      await tapKey(tester, 'open-weekly');
      await tapKey(tester, 'day-switch-2');
      await tapKey(tester, 'page-back');
      expect(find.text(S.discardChangesTitle), findsOneWidget);
      await tester.tap(find.text(S.discard));
      await tester.pumpAndSettle();
      expect(find.text(S.weeklyEditHint), findsNothing);
      expect(
        (await ScheduleRepository(db).template())!.contentHash,
        templateAc2.contentHash,
      );
    },
  );

  group('VS-33: Chân trong lịch (F03-R41 → R43)', () {
    List<Finder> pills() => [
      for (final m in MuscleGroup.pickerOrder)
        find.byKey(ValueKey('muscle-${m.name}')),
    ];

    /// UA3-10, UX-AC44: 7 viên theo thứ tự bộ chọn, Chân cuối, đọc từ trái
    /// sang phải rồi xuống hàng, không cuộn ngang.
    void expectSevenPills(WidgetTester tester, {int rows = 2}) {
      expect(
        [
          for (final p in pills())
            tester
                .widget<Text>(
                  find.descendant(of: p, matching: find.byType(Text)),
                )
                .data,
        ],
        ['Ngực', 'Tay sau', 'Vai', 'Bụng', 'Lưng', 'Tay trước', 'Chân'],
      );
      final at = [for (final p in pills()) tester.getTopLeft(p)];
      expect({for (final o in at) o.dy}, hasLength(rows));
      for (var i = 1; i < at.length; i++) {
        expect(
          at[i].dy > at[i - 1].dy ||
              (at[i].dy == at[i - 1].dy && at[i].dx > at[i - 1].dx),
          isTrue,
          reason: 'viên ${i + 1} đứng sau viên $i',
        );
      }
      expect(
        find.ancestor(
          of: pills().first,
          matching: find.byWidgetPredicate(
            (w) => w is Scrollable && w.axisDirection == AxisDirection.right,
          ),
        ),
        findsNothing,
      );
    }

    testWidgets('F03-AC41, UX-AC44: S-22 và S-21 → bộ chọn 7 viên, Chân ở '
        'cuối, hai hàng; F03-R42: lịch hiện có không có buổi Chân, không '
        'nhắc xếp Chân', (tester) async {
      await seedSetUp(db);
      await pump(tester);
      expect(find.textContaining('Chân'), findsNothing);
      expect(find.byKey(const ValueKey('redistribute-banner')), findsNothing);

      await tapKey(tester, 'open-weekly');
      await tapKey(tester, 'day-row-3');
      expectSevenPills(tester);
      await tapKey(tester, 'page-back');

      await open(tester, LocalDate(2026, 10, 22));
      await tapKey(tester, 'day-schedule');
      expectSevenPills(tester);
    });

    testWidgets('UA3-10: màn hẹp nhất (320 pt cho bộ chọn) cỡ chữ mặc định → '
        'hai hàng; cỡ chữ lớn nhất → xuống thêm hàng, không tràn, không cuộn '
        'ngang', (tester) async {
      for (final (scale, rows) in [(1.0, 2), (maxTextScale, 5)]) {
        await tester.pumpWidget(
          MaterialApp(
            theme: IronlyTheme.dark(),
            home: MediaQuery(
              data: MediaQueryData(textScaler: TextScaler.linear(scale)),
              child: Scaffold(
                body: Align(
                  alignment: Alignment.topLeft,
                  child: SizedBox(
                    width: 320,
                    child: MusclePicker(selected: const [], onChanged: (_) {}),
                  ),
                ),
              ),
            ),
          ),
        );
        expect(tester.takeException(), isNull, reason: 'cỡ chữ $scale');
        expectSevenPills(tester, rows: rows);
      }
    });

    testWidgets('F03-AC43, F03-E41: S-22 đổi thứ 6 từ Nghỉ sang Chân → chia '
        'lại → lịch tháng từ thứ 6 16/10 có buổi Chân, ngày đã qua giữ '
        'nguyên; buổi Chân mở ra thấy 5 bài chân', (tester) async {
      await seedSetUp(
        db,
        template: WeeklyTemplate({
          1: templateAc2.day(1),
          3: templateAc2.day(3),
        }),
      );
      final library = await seedLibrary(db, realLibraryV3());
      await pump(tester);
      await tapKey(tester, 'open-weekly');
      await tapKey(tester, 'day-switch-5');
      await tapKey(tester, 'day-time-5');
      await tester.tap(find.byKey(const ValueKey('time-done')));
      await tester.pumpAndSettle();
      await tapKey(tester, 'muscle-legs');
      await tapSave(tester);
      await tapKey(tester, 'redistribute');
      await tapKey(tester, 'confirm-redistribute');

      expect((await day(9)).isWorkout, isFalse, reason: 'đã qua');
      for (final d in [16, 23, 30]) {
        final fri = await day(d);
        expect(fri.time, LocalTime(18, 0), reason: '$d/10');
        expect(fri.muscles, [MuscleGroup.legs], reason: '$d/10');
      }
      expect(
        find.byKey(const ValueKey('month-cell-2026-10-16')),
        findsOneWidget,
      );

      container.read(routerProvider).go('/schedule/session/2026-10-16');
      await tester.pumpAndSettle();
      final legs = [
        for (final e in library)
          if (e.group == MuscleGroup.legs) e.id,
      ];
      expect(legs, hasLength(5));
      for (final id in legs) {
        expect(
          find.descendant(
            of: find.byType(SessionScreen),
            matching: find.byKey(ValueKey('exercise-$id'), skipOffstage: false),
          ),
          findsOneWidget,
          reason: id,
        );
      }
    });
  });
}
