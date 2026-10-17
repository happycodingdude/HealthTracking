import 'package:domain/domain.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/app/app.dart';
import 'package:mobile/app/shell/app_tab_bar.dart';
import 'package:mobile/app/strings_vi.dart';
import 'package:mobile/data/db/app_database.dart';
import 'package:mobile/features/weight/data/weight_repository.dart';

import '../../support/app_harness.dart';
import '../../support/fake_server.dart';
import '../../support/fake_sync.dart';
import '../../support/schedule_fixture.dart';

void main() {
  late AppDatabase db;
  late FixedClock clock;

  // seedSetUp: thiết lập 07/10, cân ban đầu 80 kg tuần 05/10.
  final w0510 = LocalDate(2026, 10, 5);
  final w1210 = LocalDate(2026, 10, 12);

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    clock = FixedClock(DateTime(2026, 10, 8, 9));
  });

  Future<void> pump(WidgetTester tester, {bool openWeight = true}) async {
    tester.view
      ..physicalSize = const Size(390 * 3, 844 * 3)
      ..devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final container = ProviderContainer(
      retry: (_, _) => null,
      overrides: appOverrides(
        db: db,
        clock: clock,
        scheduler: FakeScheduler(),
        server: FakeServer(),
      ),
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const IronlyApp()),
    );
    await tester.pumpAndSettle();
    if (!openWeight) return;
    await tester.tap(
      find.descendant(
        of: find.byType(AppTabBar),
        matching: find.text(S.tabWeight),
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

  Future<void> logThisWeek(WidgetTester tester, String value) async {
    final button = find.widgetWithText(FilledButton, S.logThisWeek);
    await tester.ensureVisible(button);
    await tester.pumpAndSettle();
    await tester.tap(button);
    await tester.pumpAndSettle();
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

  Future<List<WeightEntry>> all() => WeightRepository(db).all();

  testWidgets(
    'F01-AC4: cân ban đầu là số cân tuần thiết lập; F07-E1: mới có 1 số cân → '
    '"Ghi thêm tuần sau để thấy xu hướng", ẩn "so với lần trước"',
    (tester) async {
      await seedSetUp(db);
      await pump(tester);
      final summary = find.byKey(const ValueKey('weight-summary'));
      expect(
        find.descendant(
          of: summary,
          matching: find.text(S.latestWeek('05/10 – 11/10')),
        ),
        findsOneWidget,
      );
      expect(find.text('0 kg so với ban đầu'), findsOneWidget);
      expect(find.textContaining('so với lần trước'), findsNothing);
      expect(find.text(S.firstWeightHint), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('weight-week-2026-10-05')),
          matching: find.text('80 kg'),
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'F07-AC1, UX-AC12: ghi 75 rồi 74,6 trong cùng tuần → "Tuần này đã ghi 75 '
    'kg. Thay bằng số mới?" → Thay → tuần chỉ còn 74,6 kg, "Đã lưu 74,6 kg"',
    (tester) async {
      await seedSetUp(db);
      clock.set(DateTime(2026, 10, 14, 9));
      await pump(tester);
      await logThisWeek(tester, '79');
      expect(find.text(S.weightSaved('79 kg')), findsOneWidget);

      await logThisWeek(tester, '78,6');
      expect(find.text(S.replaceWeight('79 kg')), findsOneWidget);
      await tapKey(tester, 'confirm-replace');
      expect(find.text(S.weightSaved('78,6 kg')), findsOneWidget);
      expect(await all(), [
        (week: w0510, kgX10: 800),
        (week: w1210, kgX10: 786),
      ]);
      // Mũi tên vẽ bằng biểu tượng; VoiceOver đọc cả câu (F07-R7).
      expect(
        find.bySemanticsLabel(
          '↓ 1,4 kg so với lần trước · ↓ 1,4 kg so với ban đầu',
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'F07-AC3: ghi 7,5 → lỗi F07-V1; ghi 88 khi lần trước 80 → "Số này chênh '
    '8 kg so với lần trước. Bạn chắc chắn chứ?" → Sửa lại giữ bảng, chưa lưu; '
    'Lưu → lưu',
    (tester) async {
      await seedSetUp(db);
      clock.set(DateTime(2026, 10, 14, 9));
      await pump(tester);
      await logThisWeek(tester, '7,5');
      expect(find.text(S.invalidWeight), findsOneWidget);

      await tester.enterText(
        find.descendant(
          of: find.byKey(const ValueKey('weight-input')),
          matching: find.byType(TextField),
        ),
        '88',
      );
      await tester.tap(find.widgetWithText(FilledButton, S.save).last);
      await tester.pumpAndSettle();
      expect(find.text(S.bigWeightChange('8 kg')), findsOneWidget);
      await tester.tap(find.text(S.editAgain));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('weight-input')), findsOneWidget);
      expect(await all(), hasLength(1));

      await tester.tap(find.widgetWithText(FilledButton, S.save).last);
      await tester.pumpAndSettle();
      await tapKey(tester, 'confirm-big-change');
      expect(await all(), hasLength(2));
    },
  );

  testWidgets(
    'F07-AC5: số cân duy nhất → "Xóa số cân này" báo "Cần giữ ít nhất 1 số cân '
    'để tính mức calo."; có 2 số → hộp "Xóa số cân tuần 12/10?" → xóa, số cân '
    'mới nhất về tuần 05/10 (F07-E2)',
    (tester) async {
      await seedSetUp(db);
      clock.set(DateTime(2026, 10, 14, 9));
      await pump(tester);
      await tapKey(tester, 'weight-week-2026-10-05');
      await tapKey(tester, 'weight-delete');
      expect(find.text(S.keepOneWeight), findsOneWidget);
      expect(await all(), hasLength(1));
      await tester.tapAt(const Offset(195, 60));
      await tester.pumpAndSettle();

      await WeightRepository(db).put(w1210, 790);
      await tester.pumpAndSettle();
      await tapKey(tester, 'weight-week-2026-10-12');
      await tapKey(tester, 'weight-delete');
      expect(find.text(S.deleteWeightConfirm('12/10')), findsOneWidget);
      await tapKey(tester, 'confirm-delete-weight');
      expect(await all(), [(week: w0510, kgX10: 800)]);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('weight-summary')),
          matching: find.text(S.latestWeek('05/10 – 11/10')),
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'F07-AC2, F07-R2: lịch sử từ tuần hiện tại về tuần thiết lập, không có '
    'tuần sau; tuần trống "Chưa ghi" · "Thêm" → S-41 của tuần đó',
    (tester) async {
      await seedSetUp(db);
      clock.set(DateTime(2026, 10, 21, 9));
      await pump(tester);
      expect(
        find.byKey(const ValueKey('weight-week-2026-10-26')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('weight-add-2026-10-19')),
        findsOneWidget,
      );
      await tapKey(tester, 'weight-add-2026-10-12');
      expect(find.text(S.weightSheetTitle('12/10 – 18/10')), findsOneWidget);
      expect(find.textContaining('Tuần này đã ghi'), findsNothing);
    },
  );

  testWidgets('lỗi tìm thấy ở demo VS-11: đang ở tab Tôi, sang ngày mới rồi mở '
      'tab Cân nặng lần đầu → không có lỗi "setState() during build" của '
      'Riverpod, S-40 theo ngày mới', (tester) async {
    await seedSetUp(db);
    await pump(tester, openWeight: false);
    Finder tab(String label) =>
        find.descendant(of: find.byType(AppTabBar), matching: find.text(label));
    await tester.tap(tab(S.tabMe));
    await tester.pumpAndSettle();
    // Sang tuần sau khi app đang chạy nền; quay lại app ở tab Tôi.
    clock.set(DateTime(2026, 10, 13, 9));
    for (final s in [
      AppLifecycleState.inactive,
      AppLifecycleState.hidden,
      AppLifecycleState.paused,
      AppLifecycleState.hidden,
      AppLifecycleState.inactive,
      AppLifecycleState.resumed,
    ]) {
      tester.binding.handleAppLifecycleStateChanged(s);
    }
    await tester.pumpAndSettle();
    await tester.tap(tab(S.tabWeight));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(
      find.byKey(const ValueKey('weight-week-2026-10-12')),
      findsOneWidget,
    );
  });
}
