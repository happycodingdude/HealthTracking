@Tags(['golden'])
library;

import 'dart:async';

import 'package:api_contract/api_contract.dart';
import 'package:domain/domain.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/app/app.dart';
import 'package:mobile/data/db/app_database.dart';
import 'package:mobile/data/sync/outbox_writer.dart';
import 'package:mobile/features/me/data/account_repository.dart';
import 'package:mobile/features/me/data/profile_repository.dart';
import 'package:mobile/features/schedule/data/schedule_repository.dart';
import 'package:mobile/features/schedule/presentation/extra_session_sheet.dart';
import 'package:mobile/features/today/presentation/today_screen.dart';
import 'package:mobile/features/weight/data/weight_repository.dart';

import '../../support/app_harness.dart';
import '../../support/fake_server.dart';
import '../../support/golden.dart';
import '../../support/schedule_fixture.dart';

void main() {
  final mon = LocalDate(2026, 10, 5);
  final wed = LocalDate(2026, 10, 7);

  /// Lịch tuần templateAc2, thiết lập sáng thứ 2 05/10 (giống mock S-10).
  Future<AppDatabase> seed({bool pendingSync = false}) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await AccountRepository(db).put('Minh');
    await ProfileRepository(db).put(completedProfile());
    await WeightRepository(db).put(mon, 800);
    final schedule = ScheduleRepository(db);
    await schedule.putTemplate(templateAc2);
    final g = MonthGenerator.first(templateAc2, DateTime(2026, 10, 5, 8));
    await schedule.putPlan(g.plan);
    for (final d in g.days) {
      await schedule.putDay(d);
    }
    await seedMark(db, mon, DayMark.done);
    if (pendingSync) {
      await OutboxWriter(
        db,
        FixedClock(DateTime(2026, 10, 8, 9)),
      ).enqueue('account', 'me', SyncOp.upsert, {'displayName': 'Minh'});
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
    tester.platformDispatcher
      ..platformBrightnessTestValue = variant.brightness
      ..textScaleFactorTestValue = variant.textScale;
    addTearDown(tester.platformDispatcher.clearAllTestValues);
    final server = FakeServer();
    // "Chưa đồng bộ": mọi lần gửi đều lỗi kết nối.
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

  /// S-24 của hôm nay (thứ 5 08/10 nghỉ), chọn Vai (mock S-24-1).
  Future<void> openExtraSheet(WidgetTester tester) async {
    unawaited(
      showExtraSessionSheet(
        tester.element(find.byType(TodayScreen)),
        LocalDate(2026, 10, 8),
      ),
    );
    await tester.pumpAndSettle();
    final shoulders = find.byKey(const ValueKey('muscle-shoulders'));
    await tester.ensureVisible(shoulders);
    await tester.pumpAndSettle();
    await tester.tap(shoulders);
    await tester.pumpAndSettle();
  }

  for (final v in GoldenVariant.all) {
    testWidgets('S-10 chờ đánh dấu (mock S-10-1) ${v.name}', (tester) async {
      await pump(tester, v, await seed(), DateTime(2026, 10, 7, 18, 5));
      await snap('s10_awaiting_${v.name}');
    });

    testWidgets('S-65 "Đã tập Lưng?" có dòng 2 (mock S-65-1) ${v.name}', (
      tester,
    ) async {
      await pump(tester, v, await seed(), DateTime(2026, 10, 7, 18, 5));
      final done = find.byKey(ValueKey('mark-done-${wed.toKey()}'));
      await tester.ensureVisible(done);
      await tester.pumpAndSettle();
      await tester.tap(done);
      await tester.pumpAndSettle();
      await snap('s65_today_${v.name}');
    });

    testWidgets('S-10 vừa lưu "Đã tập": đã chốt khi lưu (mock S-10-3) '
        '${v.name}', (tester) async {
      await pump(tester, v, await seed(), DateTime(2026, 10, 7, 18, 5));
      final done = find.byKey(ValueKey('mark-done-${wed.toKey()}'));
      await tester.ensureVisible(done);
      await tester.pumpAndSettle();
      await tester.tap(done);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('lock-confirm-save')));
      await tester.pumpAndSettle();
      await snap('s10_done_${v.name}');
    });

    testWidgets('S-10 vừa bấm "Không tập" (mock S-10-4) ${v.name}', (
      tester,
    ) async {
      await pump(tester, v, await seed(), DateTime(2026, 10, 7, 18, 5));
      final skipped = find.byKey(ValueKey('mark-skipped-${wed.toKey()}'));
      await tester.ensureVisible(skipped);
      await tester.pumpAndSettle();
      await tester.tap(skipped);
      await tester.pumpAndSettle();
      await snap('s10_skipped_${v.name}');
    });

    testWidgets(
      'S-10 ngày nghỉ, có buổi quên đánh dấu, chưa đồng bộ (mock S-10-3) '
      '${v.name}',
      (tester) async {
        await pump(
          tester,
          v,
          await seed(pendingSync: true),
          DateTime(2026, 10, 8, 9),
        );
        await snap('s10_rest_${v.name}');
      },
    );

    testWidgets('S-10 chưa đến giờ ${v.name}', (tester) async {
      final db = await seed();
      await seedMark(db, wed, DayMark.skipped);
      await pump(tester, v, db, DateTime(2026, 10, 9, 17));
      await snap('s10_upcoming_${v.name}');
    });

    testWidgets('S-10 chủ nhật ${v.name}', (tester) async {
      await pump(tester, v, await seed(), DateTime(2026, 10, 11, 9));
      await snap('s10_sunday_${v.name}');
    });

    testWidgets(
      'S-24 thêm buổi tập thêm, đã chọn Vai (mock S-24-1) ${v.name}',
      (tester) async {
        await pump(tester, v, await seed(), DateTime(2026, 10, 8, 21));
        await openExtraSheet(tester);
        await snap('s24_${v.name}');
      },
    );

    testWidgets('S-65 "Lưu buổi tập thêm?" hôm nay (mock S-65-2) ${v.name}', (
      tester,
    ) async {
      await pump(tester, v, await seed(), DateTime(2026, 10, 8, 21));
      await openExtraSheet(tester);
      final save = find.byKey(const ValueKey('extra-save'));
      await tester.ensureVisible(save);
      await tester.pumpAndSettle();
      await tester.tap(save);
      await tester.pumpAndSettle();
      await snap('s65_extra_${v.name}');
    });

    testWidgets('S-10 hôm nay đã có buổi tập thêm: chỉ xem ${v.name}', (
      tester,
    ) async {
      final db = await seed();
      await seedExtra(db, LocalDate(2026, 10, 8), const [MuscleGroup.abs]);
      await pump(tester, v, db, DateTime(2026, 10, 8, 21));
      await snap('s10_extra_${v.name}');
    });

    testWidgets('S-25 tiến độ tuần (mock S-25-1) ${v.name}', (tester) async {
      final db = await seed();
      await seedMark(db, wed, DayMark.done);
      await seedExtra(db, LocalDate(2026, 10, 8), const [MuscleGroup.abs]);
      await pump(tester, v, db, DateTime(2026, 10, 9, 12));
      final card = find.byKey(const ValueKey('progress-card'));
      await tester.scrollUntilVisible(
        card,
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(card);
      await tester.pumpAndSettle();
      await snap('s25_${v.name}');
    });
  }
}
