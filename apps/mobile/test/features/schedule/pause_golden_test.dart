// U5-AC1 (04 Bản 5): golden theme tối × 2 cỡ chữ cho S-10 H7 / H8, S-20,
// S-21, S-25, S-76 tạm dừng (reviewMatrix ED5-09).
@Tags(['golden'])
library;

import 'dart:async';

import 'package:domain/domain.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/app/app.dart';
import 'package:mobile/app/shell/app_tab.dart';
import 'package:mobile/app/strings_vi.dart';
import 'package:mobile/data/db/app_database.dart';
import 'package:mobile/features/me/data/account_repository.dart';
import 'package:mobile/features/me/data/profile_repository.dart';
import 'package:mobile/features/schedule/data/schedule_pause_repository.dart';
import 'package:mobile/features/schedule/data/schedule_repository.dart';
import 'package:mobile/features/schedule/presentation/pause_sheet.dart';
import 'package:mobile/features/schedule/presentation/schedule_screen.dart';
import 'package:mobile/features/today/presentation/today_screen.dart';
import 'package:mobile/features/today/presentation/week_progress_screen.dart';
import 'package:mobile/ui/components/components.dart';
import 'package:mobile/ui/keys.dart';

import '../../support/app_harness.dart';
import '../../support/fake_server.dart';
import '../../support/golden.dart';
import '../../support/library_fixture.dart';
import '../../support/schedule_fixture.dart';

/// 06 Bản 5 VS56-T05 (golden): S-76 × 2, S-20 (tạm dừng), S-25, S-10 H7, H8,
/// S-21 (ngày tạm dừng) — theme tối × cỡ chữ mặc định + lớn nhất. Lịch
/// `templateAc2`: tuần 12/10 – 17/10 có T2 Ngực + Tay sau (đã tập), T4 14/10
/// Lưng, T6 16/10 Vai; tạm dừng T4 14/10 → CN 18/10 (như mock S-20, S-25).
void main() {
  final mon = LocalDate(2026, 10, 12);
  final wed = LocalDate(2026, 10, 14);
  final sun = LocalDate(2026, 10, 18);

  Future<AppDatabase> seed({bool paused = true}) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await AccountRepository(db).put('Minh');
    await ProfileRepository(db).put(completedProfile());
    final schedule = ScheduleRepository(db);
    await schedule.putTemplate(templateAc2);
    final g = MonthGenerator.first(templateAc2, DateTime(2026, 10, 5, 8));
    await schedule.putPlan(g.plan);
    for (final d in g.days) {
      await schedule.putDay(d);
    }
    await seedMark(db, mon, DayMark.done);
    await seedLibrary(db, realLibraryV3());
    if (paused) {
      await SchedulePauseRepository(db).put(
        SchedulePause(
          id: '6f1d2c3b-0000-4000-8000-0000000000c1',
          startDate: wed,
          endDate: sun,
        ),
      );
    }
    return db;
  }

  Future<void> pump(
    WidgetTester tester,
    GoldenVariant variant,
    AppDatabase db,
    DateTime now,
  ) async {
    setPhoneSurface(tester);
    applyVariant(tester, variant);
    final server = FakeServer();
    server.offline = true;
    final container = ProviderContainer(
      retry: (_, _) => null,
      overrides: appOverrides(db: db, clock: FixedClock(now), server: server),
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const IronlyApp()),
    );
    await tester.pumpAndSettle();
  }

  Future<void> snap(String name) => expectLater(
    find.byType(MaterialApp),
    matchesGoldenFile('goldens/$name.png'),
  );

  Future<void> tap(WidgetTester tester, Finder f) async {
    await tester.ensureVisible(f);
    await tester.pumpAndSettle();
    await tester.tap(f);
    await tester.pumpAndSettle();
  }

  Future<void> openTraining(WidgetTester tester) => tap(
    tester,
    find.descendant(
      of: find.byType(IronlyTabBar),
      matching: find.text(S.tabTraining),
    ),
  );

  final thu = DateTime(2026, 10, 15, 9, 40);

  for (final v in GoldenVariant.all) {
    testWidgets('S-20 tạm dừng T4 → CN, hôm nay T5: nút hai vạch, banner, ô '
        '14 và 16 viền đứt, "Tuần này 1 / 1" ${v.name}', (tester) async {
      await pump(tester, v, await seed(), thu);
      await openTraining(tester);
      await snap('s20_paused_${v.name}');
    });

    testWidgets('S-25 tuần tạm dừng: 1 / 1, dấu hai vạch ${v.name}', (
      tester,
    ) async {
      await pump(tester, v, await seed(), thu);
      await openTraining(tester);
      unawaited(
        GoRouter.of(
          tester.element(find.byType(ScheduleScreen)),
        ).push(weekProgressPath(AppTab.schedule, ProgressWeek.containing(mon))),
      );
      await tester.pumpAndSettle();
      await snap('s25_paused_${v.name}');
    });

    testWidgets('S-76 đang có khoảng ${v.name}', (tester) async {
      await pump(tester, v, await seed(), thu);
      await openTraining(tester);
      await tap(tester, find.byKey(const ValueKey('open-pause')));
      await snap('s76_active_${v.name}');
    });

    testWidgets('S-21 ngày tạm dừng (T6 16/10) ${v.name}', (tester) async {
      await pump(tester, v, await seed(), thu);
      await openTraining(tester);
      await tap(tester, find.byKey(K.monthCell('2026-10-16')));
      await snap('s21_paused_${v.name}');
    });

    testWidgets('S-76 chưa có khoảng: hôm nay → CN, dòng buổi rơi vào khoảng '
        '${v.name}', (tester) async {
      await pump(
        tester,
        v,
        await seed(paused: false),
        DateTime(2026, 10, 13, 21, 10),
      );
      unawaited(
        showIronlySheet<void>(
          tester.element(find.byType(TodayScreen)),
          builder: (_) =>
              PauseSheet(initialFrom: LocalDate(2026, 10, 13), initialTo: sun),
        ),
      );
      await tester.pumpAndSettle();
      await snap('s76_new_${v.name}');
    });

    testWidgets('S-10 H7 tạm dừng, ngày có buổi (T4 18:12) ${v.name}', (
      tester,
    ) async {
      await pump(tester, v, await seed(), DateTime(2026, 10, 14, 18, 12));
      await snap('s10_h7_${v.name}');
    });

    testWidgets('S-10 H8 tạm dừng, ngày nghỉ (T5) ${v.name}', (tester) async {
      await pump(tester, v, await seed(), thu);
      await snap('s10_h8_${v.name}');
    });
  }
}
