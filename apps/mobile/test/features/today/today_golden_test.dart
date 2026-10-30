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
import 'package:mobile/features/workout/data/exercise_unit_repository.dart';
import 'package:mobile/features/workout/data/lift_log_repository.dart';

import '../../support/app_harness.dart';
import '../../support/fake_server.dart';
import '../../support/golden.dart';
import '../../support/library_fixture.dart';
import '../../support/schedule_fixture.dart';

/// 06 Bản 4 VS44-T07 (golden): S-10 đủ H1 → H6 + buổi tập thêm (04 Bản 4
/// S-10, `todayFiveStates`), S-65 (chốt buổi, buổi tập thêm), S-23, S-24,
/// S-25 — theme tối × cỡ chữ mặc định + lớn nhất. Lịch `templateAc2`: T2 05/10
/// Ngực + Tay sau, T4 07/10 Lưng, T6 09/10 Vai.
void main() {
  final mon = LocalDate(2026, 10, 5);
  final wed = LocalDate(2026, 10, 7);

  Future<AppDatabase> seed({
    bool pendingSync = false,
    bool lifts = true,
  }) async {
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
    final library = await seedLibrary(db, realLibraryV3());
    if (lifts) {
      // Buổi Lưng 07/10: bài 1 có buổi trước (30/09) 60 → 65 kg, bài 2 nấc.
      final back = [
        for (final e in library)
          if (e.group == MuscleGroup.back) e,
      ];
      final prev = LocalDate(2026, 9, 30);
      await ExerciseUnitRepository(db).put(
        ExerciseUnit(
          exerciseId: back[0].id,
          unit: LiftUnit.kg,
          changedOn: prev,
        ),
      );
      await LiftLogRepository(db).put(
        LiftLog(
          date: prev,
          exerciseId: back[0].id,
          startKgX10: 600,
          endKgX10: 650,
        ),
      );
      await ExerciseUnitRepository(db).put(
        ExerciseUnit(
          exerciseId: back[1].id,
          unit: LiftUnit.steps,
          changedOn: prev,
        ),
      );
      await LiftLogRepository(db).put(
        LiftLog(
          date: prev,
          exerciseId: back[1].id,
          startKgX10: 80,
          endKgX10: 90,
        ),
      );
      // Hôm nay đã ghi bài 1: 60 → 67,5.
      await LiftLogRepository(db).put(
        LiftLog(
          date: wed,
          exerciseId: back[0].id,
          startKgX10: 600,
          endKgX10: 675,
        ),
      );
    }
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

  Future<void> tapKey(WidgetTester tester, String key) async {
    final f = find.byKey(ValueKey(key));
    await tester.ensureVisible(f);
    await tester.pumpAndSettle();
    await tester.tap(f);
    await tester.pumpAndSettle();
  }

  /// S-24 của hôm nay (thứ 5 08/10 nghỉ), chọn Vai.
  Future<void> openExtraSheet(WidgetTester tester) async {
    unawaited(
      showExtraSessionSheet(
        tester.element(find.byType(TodayScreen)),
        LocalDate(2026, 10, 8),
      ),
    );
    await tester.pumpAndSettle();
    await tapKey(tester, 'muscle-shoulders');
  }

  for (final v in GoldenVariant.all) {
    testWidgets('S-10 H4 có buổi, đã đến giờ, đã ghi 1 bài ${v.name}', (
      tester,
    ) async {
      await pump(tester, v, await seed(), DateTime(2026, 10, 7, 18, 5));
      await snap('s10_logging_${v.name}');
    });

    testWidgets('S-10 H3 có buổi, chưa đến giờ ${v.name}', (tester) async {
      await pump(tester, v, await seed(), DateTime(2026, 10, 7, 17, 0));
      await snap('s10_not_started_${v.name}');
    });

    testWidgets('S-65 "Đã tập Lưng?" từ dấu tích góc trên ${v.name}', (
      tester,
    ) async {
      await pump(tester, v, await seed(), DateTime(2026, 10, 7, 18, 5));
      await tapKey(tester, 'today-mark-done');
      await snap('s65_today_${v.name}');
    });

    testWidgets('S-10 H5 đã tập ${v.name}', (tester) async {
      final db = await seed();
      await seedMark(db, wed, DayMark.done);
      await pump(tester, v, db, DateTime(2026, 10, 7, 19));
      await snap('s10_done_${v.name}');
    });

    testWidgets('S-23 từ dấu tích buổi đã tập ${v.name}', (tester) async {
      final db = await seed();
      await seedMark(db, wed, DayMark.done);
      await pump(tester, v, db, DateTime(2026, 10, 7, 19));
      await tapKey(tester, 'today-status');
      await snap('s23_done_${v.name}');
    });

    testWidgets('S-10 H6 không tập ${v.name}', (tester) async {
      final db = await seed(lifts: false);
      await seedMark(db, wed, DayMark.skipped);
      await pump(tester, v, db, DateTime(2026, 10, 7, 19));
      await snap('s10_skipped_${v.name}');
    });

    testWidgets('S-10 H2 ngày nghỉ, chưa đồng bộ (không hiện) ${v.name}', (
      tester,
    ) async {
      await pump(
        tester,
        v,
        await seed(pendingSync: true),
        DateTime(2026, 10, 8, 9),
      );
      await snap('s10_rest_${v.name}');
    });

    testWidgets('S-10 chủ nhật ${v.name}', (tester) async {
      await pump(tester, v, await seed(), DateTime(2026, 10, 11, 9));
      await snap('s10_sunday_${v.name}');
    });

    testWidgets('S-24 thêm buổi tập thêm, đã chọn Vai ${v.name}', (
      tester,
    ) async {
      await pump(tester, v, await seed(), DateTime(2026, 10, 8, 21));
      await openExtraSheet(tester);
      await snap('s24_${v.name}');
    });

    testWidgets('S-65 "Lưu buổi tập thêm?" hôm nay ${v.name}', (tester) async {
      await pump(tester, v, await seed(), DateTime(2026, 10, 8, 21));
      await openExtraSheet(tester);
      await tapKey(tester, 'extra-save');
      await snap('s65_extra_${v.name}');
    });

    testWidgets('S-10 hôm nay đã có buổi tập thêm ${v.name}', (tester) async {
      final db = await seed();
      await seedExtra(db, LocalDate(2026, 10, 8), const [MuscleGroup.abs]);
      await pump(tester, v, db, DateTime(2026, 10, 8, 21));
      await snap('s10_extra_${v.name}');
    });

    testWidgets('S-25 tiến độ tuần từ thẻ Tuần này ${v.name}', (tester) async {
      final db = await seed();
      await seedMark(db, wed, DayMark.done);
      await seedExtra(db, LocalDate(2026, 10, 8), const [MuscleGroup.abs]);
      await pump(tester, v, db, DateTime(2026, 10, 10, 12));
      await tapKey(tester, 'week-card');
      await snap('s25_${v.name}');
    });
  }
}
