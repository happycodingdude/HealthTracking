@Tags(['golden'])
library;

import 'package:domain/domain.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/app/app.dart';
import 'package:mobile/app/router.dart';
import 'package:mobile/app/shell/app_tab.dart';
import 'package:mobile/data/db/app_database.dart';
import 'package:mobile/features/library/data/video_player_gateway.dart';
import 'package:mobile/features/workout/data/lift_log_repository.dart';
import 'package:mobile/features/workout/presentation/session_screen.dart';

import '../../support/app_harness.dart';
import '../../support/golden.dart';
import '../../support/library_fixture.dart';
import '../../support/schedule_fixture.dart';

/// 06 Bản 2 VS27-T07 (golden): S-63 (3 biến thể), S-64 (4 biến thể), S-67 có
/// khu mức tạ, S-10 có phần bài tập — sáng/tối × cỡ chữ (UX-AC43).
void main() {
  final mon = LocalDate(2026, 10, 12);
  final tue = LocalDate(2026, 10, 13);

  late List<Exercise> library;
  late FixedClock clock;

  Exercise ex(MuscleRegion region, [String? equipment]) =>
      exerciseOf(library, region, equipment);

  Future<AppDatabase> seeded() async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await seedSetUp(db);
    library = await seedLibrary(db);
    return db;
  }

  Future<void> log(
    AppDatabase db,
    LocalDate date,
    Exercise e,
    int start,
    int end,
  ) => LiftLogRepository(db).put(
    LiftLog(date: date, exerciseId: e.id, startKgX10: start, endKgX10: end),
  );

  Future<ProviderContainer> pump(
    WidgetTester tester,
    GoldenVariant variant,
    AppDatabase db,
    DateTime now,
  ) async {
    setPhoneSurface(tester);
    tester.platformDispatcher
      ..platformBrightnessTestValue = variant.brightness
      ..textScaleFactorTestValue = variant.textScale;
    addTearDown(tester.platformDispatcher.clearAllTestValues);
    clock = FixedClock(now);
    final container = ProviderContainer(
      retry: (_, _) => null,
      overrides: [
        ...appOverrides(db: db, clock: clock),
        videoPlayerGatewayProvider.overrideWithValue(FakeVideoGateway()),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const IronlyApp()),
    );
    await tester.pumpAndSettle();
    return container;
  }

  Future<void> go(
    WidgetTester tester,
    ProviderContainer container,
    String path,
  ) async {
    container.read(routerProvider).go(path);
    await tester.pumpAndSettle();
  }

  /// Chạm nút trong bảng S-64 (dựng đủ, chỉ cần cuộn tới).
  Future<void> tapKey(WidgetTester tester, String key) async {
    final f = find.byKey(ValueKey(key));
    await tester.ensureVisible(f);
    await tester.pumpAndSettle();
    await tester.tap(f);
    await tester.pumpAndSettle();
  }

  /// Chạm nút trên dòng bài của S-63: danh sách chỉ dựng phần đang thấy.
  Future<void> tapRow(WidgetTester tester, String key) async {
    final f = find.byKey(ValueKey(key));
    await tester.scrollUntilVisible(
      f,
      200,
      scrollable: find.descendant(
        of: find.byKey(const ValueKey('session-list')),
        matching: find.byType(Scrollable),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(f);
    await tester.pumpAndSettle();
  }

  Future<void> snap(String name) => expectLater(
    find.byType(MaterialApp),
    matchesGoldenFile('goldens/$name.png'),
  );

  for (final v in GoldenVariant.all) {
    testWidgets('S-63-1 trong cửa sổ, đã ghi 2 bài, thanh đáy "Đã tập" '
        '${v.name}', (tester) async {
      final db = await seeded();
      await log(db, mon, ex(MuscleRegion.chestUpper, 'machine'), 70, 80);
      await log(db, mon, ex(MuscleRegion.chestUpper, 'free-weight'), 100, 120);
      final c = await pump(tester, v, db, DateTime(2026, 10, 12, 18, 30));
      await go(tester, c, sessionPath(AppTab.today, mon));
      await snap('s63_window_${v.name}');
    });

    testWidgets('S-63-2 chưa đến giờ, chỉ xem ${v.name}', (tester) async {
      final db = await seeded();
      final c = await pump(tester, v, db, DateTime(2026, 10, 12, 17));
      await go(tester, c, sessionPath(AppTab.today, mon));
      await snap('s63_upcoming_${v.name}');
    });

    testWidgets('S-63-3 buổi tập thêm Vai và Bụng ${v.name}', (tester) async {
      final db = await seeded();
      await seedExtra(db, tue, const [MuscleGroup.shoulders, MuscleGroup.abs]);
      await log(db, tue, ex(MuscleRegion.deltFront, 'machine'), 50, 60);
      final c = await pump(tester, v, db, DateTime(2026, 10, 13, 20, 30));
      await go(tester, c, sessionPath(AppTab.today, tue));
      await snap('s63_extra_${v.name}');
    });

    testWidgets('S-64-1 lần ghi đầu tiên ${v.name}', (tester) async {
      final db = await seeded();
      final e = ex(MuscleRegion.chestMid, 'machine');
      final c = await pump(tester, v, db, DateTime(2026, 10, 12, 18, 30));
      await go(tester, c, sessionPath(AppTab.today, mon));
      await tapRow(tester, 'lift-log-${e.id}');
      await tester.enterText(
        find.byKey(const ValueKey('lift-start-input')),
        '7',
      );
      await tester.pumpAndSettle();
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      await snap('s64_first_${v.name}');
    });

    testWidgets('S-64-2 sửa, có cảnh báo, vẫn lưu được ${v.name}', (
      tester,
    ) async {
      final db = await seeded();
      final e = ex(MuscleRegion.chestUpper, 'free-weight');
      await log(db, LocalDate(2026, 10, 5), e, 120, 140);
      await log(db, mon, e, 100, 120);
      final c = await pump(tester, v, db, DateTime(2026, 10, 12, 18, 30));
      await go(tester, c, sessionPath(AppTab.today, mon));
      await tapRow(tester, 'lift-value-${e.id}');
      await snap('s64_edit_warning_${v.name}');
    });

    testWidgets('S-64-3 lỗi nhập liệu ${v.name}', (tester) async {
      final db = await seeded();
      final e = ex(MuscleRegion.chestMid, 'machine');
      final c = await pump(tester, v, db, DateTime(2026, 10, 12, 18, 30));
      await go(tester, c, sessionPath(AppTab.today, mon));
      await tapRow(tester, 'lift-log-${e.id}');
      await tester.enterText(
        find.byKey(const ValueKey('lift-start-input')),
        '7',
      );
      await tester.enterText(
        find.byKey(const ValueKey('lift-end-input')),
        '31',
      );
      await tester.pumpAndSettle();
      await tapKey(tester, 'lift-save');
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      await snap('s64_error_${v.name}');
    });

    testWidgets('S-64-4 lưu sau 00:00, buổi đã khóa ${v.name}', (tester) async {
      final db = await seeded();
      final e = ex(MuscleRegion.chestMid, 'machine');
      final c = await pump(tester, v, db, DateTime(2026, 10, 12, 23, 58));
      await go(tester, c, sessionPath(AppTab.today, mon));
      await tapRow(tester, 'lift-log-${e.id}');
      await tester.enterText(
        find.byKey(const ValueKey('lift-start-input')),
        '7',
      );
      await tester.enterText(find.byKey(const ValueKey('lift-end-input')), '8');
      await tester.pumpAndSettle();
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      clock.set(DateTime(2026, 10, 13, 0, 1));
      await tapKey(tester, 'lift-save');
      await snap('s64_locked_${v.name}');
    });

    testWidgets('S-67 khu mức tạ mở từ S-63, có buổi trước ${v.name}', (
      tester,
    ) async {
      final db = await seeded();
      final e = ex(MuscleRegion.chestUpper, 'free-weight');
      await log(db, LocalDate(2026, 10, 5), e, 120, 140);
      final c = await pump(tester, v, db, DateTime(2026, 10, 12, 18, 30));
      await go(tester, c, sessionExercisePath(AppTab.today, mon, e.id));
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('exercise-lift-area')),
        300,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.pumpAndSettle();
      await snap('s67_lift_area_${v.name}');
    });

    testWidgets('S-10-2 thẻ buổi tập có phần bài tập ${v.name}', (
      tester,
    ) async {
      final db = await seeded();
      await log(db, mon, ex(MuscleRegion.chestUpper, 'machine'), 70, 80);
      await log(db, mon, ex(MuscleRegion.tricepsLong), 100, 125);
      await pump(tester, v, db, DateTime(2026, 10, 12, 18, 30));
      await snap('s10_session_exercises_${v.name}');
    });
  }
}
