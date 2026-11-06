import 'dart:async';

import 'package:domain/domain.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/app/app.dart';
import 'package:mobile/app/strings_vi.dart';
import 'package:mobile/data/db/app_database.dart';
import 'package:mobile/features/schedule/data/schedule_pause_repository.dart';
import 'package:mobile/features/schedule/presentation/pause_sheet.dart';
import 'package:mobile/features/today/presentation/today_screen.dart';
import 'package:mobile/ui/components/components.dart';
import 'package:mobile/ui/keys.dart';

import '../../support/app_harness.dart';
import '../../support/fake_server.dart';
import '../../support/fake_sync.dart';
import '../../support/schedule_fixture.dart';

/// 06 Bản 5 VS56-T05: J5-03 và F31-AC1 → AC7, F03-AC61, F06-AC61, F20-R65,
/// R66 (H7, H8) trên app với `FixedClock`. Lịch `templateAc2`: tuần 12/10 –
/// 17/10 có T2 Ngực + Tay sau (đã tập), T4 14/10 Lưng, T6 16/10 Vai 18:00.
void main() {
  late AppDatabase db;
  late FixedClock clock;
  late FakeScheduler scheduler;
  final mon = LocalDate(2026, 10, 12);
  final wed = LocalDate(2026, 10, 14);
  final fri = LocalDate(2026, 10, 16);
  final sun = LocalDate(2026, 10, 18);

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    clock = FixedClock(DateTime(2026, 10, 13, 21));
    scheduler = FakeScheduler();
    await seedSetUp(db);
    await seedMark(db, mon, DayMark.done);
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
        clock: clock,
        scheduler: scheduler,
        server: FakeServer(),
      ),
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const IronlyApp()),
    );
    await tester.pumpAndSettle();
  }

  Future<void> advanceTo(WidgetTester tester, DateTime at) async {
    clock.set(at);
    scheduler.fireSync();
    await tester.pumpAndSettle();
  }

  Future<void> tap(WidgetTester tester, Finder f) async {
    await tester.ensureVisible(f);
    await tester.pumpAndSettle();
    await tester.tap(f);
    await tester.pumpAndSettle();
  }

  Future<void> tapKey(WidgetTester tester, String key) =>
      tap(tester, find.byKey(ValueKey(key)));

  Future<void> openTab(WidgetTester tester, String label) => tap(
    tester,
    find.descendant(of: find.byType(IronlyTabBar), matching: find.text(label)),
  );

  /// Chọn ngày trên bộ chọn ngày của S-76: kéo cột ngày từ ngày [from] đi
  /// [days] nấc.
  Future<void> pickDays(
    WidgetTester tester,
    String field,
    int from,
    int days,
  ) async {
    await tapKey(tester, field);
    final picker = find.byKey(const ValueKey('date-picker'));
    expect(picker, findsOneWidget);
    final current = find.descendant(of: picker, matching: find.text('$from'));
    await tester.drag(current.first, Offset(0, -32.0 * days));
    await tester.pumpAndSettle();
    await tapKey(tester, 'date-done');
  }

  Finder pauseBars(LocalDate date) => find.descendant(
    of: find.byKey(K.monthCell(date.toKey())),
    matching: find.byKey(const ValueKey('pause-bar-0')),
  );

  Finder ratio(String text) => find.text(text, findRichText: true);

  testWidgets(
    'J5-03, U5-AC5, F31-AC1, F03-AC61, F06-AC61: T3 21:00 S-20 nút hai vạch '
    '→ S-76 → từ mai đến CN → "Tạm dừng" → banner, ô T4, T6 viền đứt, '
    '"Tuần này 1 / 1"; T4 H7 ẩn danh sách bài, "Vẫn tập hôm nay" → hiện lại '
    '(Bạn chọn B 06/11/2026); F31-AC3: T4 H7 chốt "Đã tập" → 2 / 2; F31-AC2: T5 '
    'H8, "+ Buổi thêm" vẫn có; F31-AC4: T7 "Kết thúc" → hộp → banner mất; '
    'F31-AC5: T6 hết ngày chưa chốt vẫn Tạm dừng',
    (tester) async {
      await pump(tester);
      await openTab(tester, S.tabTraining);
      expect(find.byKey(const ValueKey('pause-banner')), findsNothing);
      await tapKey(tester, 'open-pause');
      expect(find.text(S.pauseSheetTitle), findsOneWidget);
      expect(find.text(S.todayDayMonth('13/10')), findsNWidgets(2));
      await pickDays(tester, 'pause-from-field', 13, 1);
      expect(find.text('T4 14/10'), findsNWidgets(2));
      await pickDays(tester, 'pause-to-field', 14, 4);
      expect(find.text('CN 18/10'), findsOneWidget);
      expect(find.text('Lưng T4 · Vai T6'), findsOneWidget);
      await tapKey(tester, 'pause-submit');
      expect(find.text(S.pausedUntil('18/10')), findsOneWidget);
      final saved = (await SchedulePauseRepository(db).all()).single;
      expect((saved.startDate, saved.endDate), (wed, sun));

      // S-20: banner "Đến CN 18/10", ô T4 / T6 viền đứt + hai vạch, tuần 1 / 1.
      expect(find.byKey(const ValueKey('pause-banner')), findsOneWidget);
      expect(find.text('Đến CN 18/10', findRichText: true), findsOneWidget);
      expect(pauseBars(wed), findsOneWidget);
      expect(pauseBars(fri), findsOneWidget);
      expect(pauseBars(mon), findsNothing);
      expect(
        find.bySemanticsLabel('Thứ 4, 14/10: Lưng, Tạm dừng'),
        findsOneWidget,
      );
      // U5-AC11: banner đọc "Đang tạm dừng đến {ngày}" (04 Bản 5 §6.9).
      expect(find.bySemanticsLabel(S.pausingUntil('CN 18/10')), findsOneWidget);
      expect(ratio('1 / 1'), findsWidgets);

      // Hôm nay T3 không đổi (không banner, F31-E3).
      await openTab(tester, S.tabToday);
      expect(find.byKey(const ValueKey('pause-banner')), findsNothing);

      // T4 18:05 trong khoảng: H7 — banner, vòng hai vạch góc trên → S-65.
      await advanceTo(tester, DateTime(2026, 10, 14, 18, 5));
      expect(find.byKey(const ValueKey('pause-banner')), findsOneWidget);
      expect(find.byKey(K.glyph('paused')), findsWidgets);
      expect(ratio('1 / 1'), findsOneWidget);
      // Bạn chọn B 06/11/2026: H7 ẩn danh sách bài; "Vẫn tập hôm nay" →
      // danh sách hiện lại (có "+ Thêm bài"), tạm dừng giữ nguyên.
      expect(find.byKey(const ValueKey('session-log-list')), findsNothing);
      await tapKey(tester, 'train-anyway');
      expect(find.byKey(const ValueKey('session-log-list')), findsOneWidget);
      expect(find.byKey(const ValueKey('add-exercise')), findsOneWidget);
      expect(find.byKey(const ValueKey('train-anyway')), findsNothing);
      expect(find.byKey(const ValueKey('pause-banner')), findsOneWidget);
      await tapKey(tester, 'today-mark-done');
      expect(find.text(S.doneConfirmTitle('Lưng')), findsOneWidget);
      await tapKey(tester, 'lock-confirm-save');
      expect(ratio('2 / 2'), findsOneWidget);
      expect(find.byKey(const ValueKey('pause-banner')), findsOneWidget);

      // T5 nghỉ trong khoảng: H8 — banner, buổi tới T6 kèm hai vạch.
      await advanceTo(tester, DateTime(2026, 10, 15, 9, 40));
      expect(find.byKey(const ValueKey('pause-banner')), findsOneWidget);
      expect(find.byKey(const ValueKey('rest-card')), findsOneWidget);
      expect(find.byKey(const ValueKey('next-session-paused')), findsOneWidget);
      expect(find.byKey(const ValueKey('extra-log')), findsOneWidget);
      expect(ratio('2 / 2'), findsOneWidget);

      // T7: hết T6 chưa chốt → vẫn Tạm dừng; "Kết thúc" → hộp → banner mất.
      await advanceTo(tester, DateTime(2026, 10, 17, 9));
      await tapKey(tester, 'pause-banner-end');
      expect(find.text(S.endPauseTitle), findsOneWidget);
      expect(find.text(S.endPauseBody), findsOneWidget);
      await tapKey(tester, 'confirm-end-pause');
      expect(find.text(S.pauseEnded), findsOneWidget);
      expect(find.byKey(const ValueKey('pause-banner')), findsNothing);
      final ended = (await SchedulePauseRepository(db).all()).single;
      expect(ended.endedOn, fri);
      await openTab(tester, S.tabTraining);
      expect(find.byKey(const ValueKey('pause-banner')), findsNothing);
      expect(pauseBars(fri), findsOneWidget);
      expect(
        find.bySemanticsLabel('Thứ 6, 16/10: Vai, Tạm dừng'),
        findsOneWidget,
      );
    },
  );

  testWidgets('F31-AC6: đang có khoảng → S-76 "Đang tạm dừng", không có cách '
      'tạo khoảng thứ hai; F31-AC7: B trước A → câu lỗi, nút mờ', (
    tester,
  ) async {
    await pump(tester);
    unawaited(
      showIronlySheet<void>(
        tester.element(find.byType(TodayScreen)),
        builder: (_) => PauseSheet(initialFrom: fri, initialTo: wed),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text(S.pauseEndBeforeStart), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('pause-submit')));
    await tester.pumpAndSettle();
    expect(await SchedulePauseRepository(db).all(), isEmpty);
    await tester.tapAt(const Offset(20, 60));
    await tester.pumpAndSettle();

    await SchedulePauseRepository(db).put(
      SchedulePause(
        id: '6f1d2c3b-0000-4000-8000-0000000000d1',
        startDate: wed,
        endDate: sun,
      ),
    );
    await openTab(tester, S.tabTraining);
    await tapKey(tester, 'open-pause');
    expect(find.byKey(const ValueKey('pause-sheet-active')), findsOneWidget);
    expect(find.text(S.pausingTitle), findsOneWidget);
    expect(find.byKey(const ValueKey('pause-submit')), findsNothing);
    expect(find.byKey(const ValueKey('pause-save')), findsOneWidget);
    expect(find.text(S.endPause), findsOneWidget);
  });
}
