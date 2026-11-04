import 'package:api_contract/api_contract.dart';
import 'package:domain/domain.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/app/app.dart';
import 'package:mobile/app/router.dart';
import 'package:mobile/app/strings_vi.dart';
import 'package:mobile/data/db/app_database.dart';
import 'package:mobile/data/sync/outbox_writer.dart';
import 'package:mobile/features/me/application/gym_location.dart';
import 'package:mobile/features/me/data/gym_location_repository.dart';
import 'package:mobile/features/me/presentation/gym_location_screen.dart';
import 'package:mobile/features/native/gym_region_bridge.dart';
import 'package:mobile/features/native/live_activity_controller.dart';
import 'package:mobile/features/native/native_logout_hooks.dart';
import 'package:mobile/features/schedule/data/schedule_pause_repository.dart';
import 'package:mobile/features/schedule/data/schedule_repository.dart';
import 'package:mobile/ui/components/ironly_switch.dart';

import '../../support/app_harness.dart';
import '../../support/fake_native.dart';

/// 06 Bản 5 VS58-T04 → T06: S-50 dòng "Vị trí phòng gym", S-77 ba trạng thái,
/// lưu / lưu lại / công tắc / xóa (F32-AC1 → AC5), vùng iOS theo bản ghi trên
/// máy (F32-AC6), vào vùng → `gym_arrivals` một lần / ngày (§6.4.2), đăng
/// xuất ngừng theo dõi (F32-E3).
void main() {
  late AppDatabase db;
  late FixedClock clock;
  late FakeGymRegionBridge gym;

  // Thứ 3 03/11/2026, 17:20 (mock S-77 "Lưu lúc 17:20 · T3 03/11/2026").
  final tue = DateTime(2026, 11, 3, 17, 20);

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    clock = FixedClock(tue);
    gym = FakeGymRegionBridge();
  });

  Future<ProviderContainer> pump(WidgetTester tester) async {
    tester.view
      ..physicalSize = const Size(390 * 3, 844 * 3)
      ..devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final container = ProviderContainer(
      retry: (_, _) => null,
      overrides: appOverrides(db: db, clock: clock, gym: gym),
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const IronlyApp()),
    );
    await tester.pumpAndSettle();
    return container;
  }

  Future<void> open(WidgetTester tester, ProviderContainer c) async {
    c.read(routerProvider).go(gymLocationPath);
    await tester.pumpAndSettle();
  }

  Future<List<SyncMutation>> outbox() async => [
    for (final r in await db.select(db.outbox).get())
      if (r.entity == SyncEntities.gymLocation) r.toMutation(),
  ];

  IronlySwitch gymSwitch(WidgetTester tester) =>
      tester.widget<IronlySwitch>(find.byKey(const ValueKey('gym-switch')));

  testWidgets('S-50: chưa lưu → dòng "Vị trí phòng gym" không giá trị phụ; '
      'chạm → S-77', (tester) async {
    final c = await pump(tester);
    c.read(routerProvider).go('/me');
    await tester.pumpAndSettle();
    final row = find.byKey(const ValueKey('row-gym-location'));
    expect(row, findsOneWidget);
    expect(
      find.descendant(of: row, matching: find.text(S.gymLocation)),
      findsOneWidget,
    );
    expect(find.textContaining('Lưu '), findsNothing);
    await tester.tap(row);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('gym-save')), findsOneWidget);
  });

  testWidgets(
    'F32-AC1, U5-AC8: chưa lưu → công tắc mờ; "Lưu vị trí này" → lấy vị '
    'trí → "Lưu lúc 17:20 · T3 03/11/2026", công tắc bật, theo dõi vùng; '
    'F32-AC5: không tọa độ',
    (tester) async {
      final c = await pump(tester);
      await open(tester, c);
      expect(find.text(S.saveGymLocation), findsOneWidget);
      expect(gymSwitch(tester).onChanged, isNull);
      expect(gymSwitch(tester).value, isFalse);
      expect(find.byKey(const ValueKey('row-gym-permission')), findsNothing);

      await tester.tap(find.byKey(const ValueKey('gym-save')));
      await tester.pumpAndSettle();
      expect(gym.calls, containsAllInOrder(['requestLocation', 'start']));
      expect(gym.region, (lat: 10.7701234, lng: 106.6904567));
      expect(find.text('Lưu lúc 17:20 · T3 03/11/2026'), findsOneWidget);
      expect(find.text(S.gymSaved), findsOneWidget);
      expect(find.text(S.resaveGymLocation), findsOneWidget);
      expect(gymSwitch(tester).value, isTrue);
      expect(gymSwitch(tester).onChanged, isNotNull);
      expect(find.text(S.locationPermission), findsOneWidget);
      expect(find.text(S.locationAlways), findsOneWidget);
      expect(find.text(S.deleteGymLocation), findsOneWidget);
      // F32-AC5, F32-R2: không tọa độ, không địa chỉ trên màn.
      expect(find.textContaining('10.77'), findsNothing);
      expect(find.textContaining('106.69'), findsNothing);
      final saved = await GymLocationRepository(db).get();
      expect((saved!.enabled, saved.savedAt), (true, tue));
      final m = (await outbox()).single;
      expect((m.key, m.op), ('me', SyncOp.upsert));
      expect(m.data!['lat'], 10.770123);

      // S-50: "Lưu 03/11 · Đang bật".
      c.read(routerProvider).go('/me');
      await tester.pumpAndSettle();
      expect(find.text(S.gymSummary('03/11', on: true)), findsOneWidget);
    },
  );

  testWidgets('F32-AC2: không lấy được vị trí → banner F32-R3 + "Mở Cài đặt"; '
      'không lưu gì; công tắc mờ', (tester) async {
    gym.fix = null;
    gym.access = LocationAccess.denied;
    final c = await pump(tester);
    await open(tester, c);
    await tester.tap(find.byKey(const ValueKey('gym-save')));
    await tester.pumpAndSettle();
    expect(find.text(S.gymNoFix), findsOneWidget);
    expect(await GymLocationRepository(db).get(), isNull);
    expect(await outbox(), isEmpty);
    expect(gym.region, isNull);
    expect(gymSwitch(tester).onChanged, isNull);
    await tester.tap(
      find.descendant(
        of: find.byKey(const ValueKey('gym-error')),
        matching: find.text(S.openSettings),
      ),
    );
    expect(gym.settingsOpened, 1);
  });

  testWidgets('F32-AC3: "Lưu lại vị trí này" → hộp → "Lưu lại" ghi đè, giờ '
      'lưu mới; "Hủy" không đổi', (tester) async {
    await GymLocationRepository(
      db,
    ).put(GymLocation(lat: 10.70, lng: 106.60, savedAt: tue));
    final c = await pump(tester);
    await open(tester, c);
    await tester.tap(find.byKey(const ValueKey('gym-resave')));
    await tester.pumpAndSettle();
    expect(find.text(S.resaveGymTitle), findsOneWidget);
    expect(find.text(S.resaveGymBody), findsOneWidget);
    await tester.tap(find.text(S.cancel));
    await tester.pumpAndSettle();
    expect(gym.calls, isNot(contains('requestLocation')));

    clock.set(DateTime(2026, 11, 5, 7, 5));
    await tester.tap(find.byKey(const ValueKey('gym-resave')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('confirm-resave-gym')));
    await tester.pumpAndSettle();
    expect(find.text('Lưu lúc 07:05 · T5 05/11/2026'), findsOneWidget);
    final g = await GymLocationRepository(db).get();
    expect((g!.lat, g.lng), (10.7701234, 106.6904567));
    expect(gym.region?.lat, 10.7701234);
  });

  testWidgets(
    'F32-AC4, F25-AC66, F32-R4: tắt công tắc → ngừng theo dõi, vị trí giữ, '
    'ghim không viền; S-50 "Đã tắt"; bật lại → theo dõi lại',
    (tester) async {
      await GymLocationRepository(
        db,
      ).put(GymLocation(lat: 10.77, lng: 106.69, savedAt: tue));
      final c = await pump(tester);
      expect(gym.region, isNotNull, reason: 'mở app → theo dõi theo bản ghi');
      await open(tester, c);
      await tester.tap(find.byKey(const ValueKey('gym-switch')));
      await tester.pumpAndSettle();
      expect(gym.region, isNull);
      expect((await GymLocationRepository(db).get())!.enabled, isFalse);
      expect(find.textContaining('Lưu lúc'), findsOneWidget);
      expect((await outbox()).last.data!['enabled'], isFalse);
      c.read(routerProvider).go('/me');
      await tester.pumpAndSettle();
      expect(find.text(S.gymSummary('03/11', on: false)), findsOneWidget);
      await open(tester, c);
      await tester.tap(find.byKey(const ValueKey('gym-switch')));
      await tester.pumpAndSettle();
      expect(gym.region, (lat: 10.77, lng: 106.69));
    },
  );

  testWidgets('F32-R8: "Xóa vị trí" → hộp "Xóa vị trí phòng gym?" → Xóa → về '
      'chưa lưu, ngừng theo dõi, outbox delete', (tester) async {
    await GymLocationRepository(
      db,
    ).put(GymLocation(lat: 10.77, lng: 106.69, savedAt: tue));
    final c = await pump(tester);
    await open(tester, c);
    await tester.tap(find.byKey(const ValueKey('gym-delete')));
    await tester.pumpAndSettle();
    expect(find.text(S.deleteGymTitle), findsOneWidget);
    expect(find.text(S.deleteGymBody), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('confirm-delete-gym')));
    await tester.pumpAndSettle();
    expect(await GymLocationRepository(db).get(), isNull);
    expect(gym.region, isNull);
    expect(find.byKey(const ValueKey('gym-save')), findsOneWidget);
    expect(gymSwitch(tester).onChanged, isNull);
    expect((await outbox()).single.op, SyncOp.delete);
  });

  testWidgets(
    'F32-R5: dòng "Quyền vị trí" chỉ thông tin: Khi dùng app / Không; '
    'chạm → Mở Cài đặt',
    (tester) async {
      await GymLocationRepository(
        db,
      ).put(GymLocation(lat: 10.77, lng: 106.69, savedAt: tue));
      gym.access = LocationAccess.whenInUse;
      final c = await pump(tester);
      await open(tester, c);
      expect(find.text(S.locationWhenInUse), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('row-gym-permission')));
      expect(gym.settingsOpened, 1);
      gym.access = LocationAccess.denied;
      c.invalidate(locationAccessProvider);
      await tester.pumpAndSettle();
      expect(find.text(S.locationNone), findsOneWidget);
    },
  );

  testWidgets('F32-AC6: vị trí đồng bộ về (máy mới) → theo dõi vùng; xóa ở máy '
      'khác → ngừng', (tester) async {
    await pump(tester);
    expect(gym.region, isNull);
    await GymLocationRepository(
      db,
    ).put(GymLocation(lat: 21.03, lng: 105.85, savedAt: tue));
    await tester.pumpAndSettle();
    expect(gym.region, (lat: 21.03, lng: 105.85));
    await GymLocationRepository(db).delete();
    await tester.pumpAndSettle();
    expect(gym.region, isNull);
  });

  testWidgets('§6.4.2 GymArrival (phần trên máy): vào vùng → gym_arrivals hôm '
      'nay một lần; ngày khác / tắt công tắc không ghi', (tester) async {
    await GymLocationRepository(
      db,
    ).put(GymLocation(lat: 10.77, lng: 106.69, savedAt: tue));
    await pump(tester);
    final today = LocalDate(2026, 11, 3);
    gym.enter(today, LocalTime(17, 20));
    await tester.pumpAndSettle();
    expect(await GymLocationRepository(db).arrived(today), isTrue);
    expect(gym.queue, isEmpty);
    // Sự kiện hôm qua còn trong hàng chờ (app mở muộn): bỏ qua.
    gym.enter(today.addDays(-1), LocalTime(18, 0));
    await tester.pumpAndSettle();
    expect(await GymLocationRepository(db).arrived(today.addDays(-1)), isFalse);
  });

  group('GymArrivalUseCase / GymRegionSync', () {
    late GymLocationRepository repo;
    late GymArrivalUseCase arrival;
    final today = LocalDate(2026, 11, 3);
    final event = (date: today, localTime: LocalTime(17, 20));

    final reported = <String>[];
    var offline = false;

    setUp(() {
      repo = GymLocationRepository(db);
      reported.clear();
      offline = false;
      arrival = GymArrivalUseCase(
        db: db,
        repo: repo,
        schedule: ScheduleRepository(db),
        pauses: SchedulePauseRepository(db),
        outbox: OutboxWriter(db, clock),
        bridge: gym,
        report: (date, time) async {
          if (offline) throw Exception('offline');
          reported.add('${date.toKey()} ${time.toKey()}');
        },
        clock: clock,
      );
    });
    tearDown(() => db.close());

    test(
      'F25-AC66, một lần / ngày (A5-09); chưa lưu, tắt, tạm dừng → không',
      () async {
        expect(await arrival(event), isFalse, reason: 'chưa lưu vị trí');
        await repo.put(
          GymLocation(lat: 10.77, lng: 106.69, savedAt: tue, enabled: false),
        );
        expect(await arrival(event), isFalse, reason: 'công tắc tắt');
        await repo.put(GymLocation(lat: 10.77, lng: 106.69, savedAt: tue));
        await SchedulePauseRepository(db).put(
          SchedulePause(id: 'p1', startDate: today, endDate: today.addDays(2)),
        );
        expect(await arrival(event), isFalse, reason: 'tạm dừng');
        await SchedulePauseRepository(db).delete('p1');
        expect(await arrival(event), isTrue);
        expect(await arrival(event), isFalse, reason: 'đã báo hôm nay');
        expect(await repo.arrived(today), isTrue);
      },
    );

    test('drain lấy hàng chờ iOS và xử lý, báo iOS xong', () async {
      await repo.put(GymLocation(lat: 10.77, lng: 106.69, savedAt: tue));
      gym.queue.add(event);
      await arrival.drain();
      expect(gym.queue, isEmpty);
      expect(await repo.arrived(today), isTrue);
      expect(reported, ['2026-11-03 17:20']);
      expect(gym.handled, 1);
    });

    // Thứ 3 03/11 có buổi Lưng 18:00 (FD5-01 = A, VS59-T03).
    final tueDay = PlanDay(
      date: today,
      kind: DayKind.workout,
      time: LocalTime(18, 0),
      muscles: const [MuscleGroup.back],
    );
    Future<void> seedDay(PlanDay d) => ScheduleRepository(db).putDay(d);

    test('FD5-01, F25-E61: tới gym 17:20 trước giờ tập 18:00 → openedAt 17:20 '
        '+ outbox day, báo server; ghi tạ, "Đã tập" mở từ 17:20', () async {
      await repo.put(GymLocation(lat: 10.77, lng: 106.69, savedAt: tue));
      await seedDay(tueDay);
      clock.set(DateTime(2026, 11, 3, 17, 21));
      expect(await arrival(event), isTrue);
      final day = (await ScheduleRepository(db).day(today))!;
      expect(day.openedAt, DateTime(2026, 11, 3, 17, 20));
      expect(SessionRules.canMarkDone(day, clock.now()), isTrue);
      expect(LiftWindow.of(day, clock.now()).isOpen, isTrue);
      final days = [
        for (final r in await db.select(db.outbox).get())
          if (r.entity == SyncEntities.day) r.toMutation(),
      ];
      expect(days.single.data!['openedAt'], '2026-11-03T10:20:00.000Z');
      expect(reported, ['2026-11-03 17:20']);
    });

    test('F25-R66: mất mạng → không thẻ, nhưng buổi vẫn mở sớm và không gọi '
        'lại trong ngày', () async {
      await repo.put(GymLocation(lat: 10.77, lng: 106.69, savedAt: tue));
      await seedDay(tueDay);
      offline = true;
      expect(await arrival(event), isTrue);
      expect(reported, isEmpty);
      expect((await ScheduleRepository(db).day(today))!.openedAt, isNotNull);
      offline = false;
      expect(await arrival(event), isFalse);
      expect(reported, isEmpty);
    });

    test('Tạm dừng: không báo server (A5-07) nhưng vẫn mở buổi sớm (F31-R5); '
        'sau giờ tập / đã đánh dấu → không mở sớm', () async {
      await repo.put(GymLocation(lat: 10.77, lng: 106.69, savedAt: tue));
      await seedDay(tueDay);
      await SchedulePauseRepository(
        db,
      ).put(SchedulePause(id: 'p1', startDate: today, endDate: today));
      expect(await arrival(event), isFalse);
      expect(reported, isEmpty);
      expect((await ScheduleRepository(db).day(today))!.openedAt, isNotNull);

      await ScheduleRepository(db).putDay(tueDay);
      await SchedulePauseRepository(db).delete('p1');
      expect(
        await arrival((date: today, localTime: LocalTime(18, 30))),
        isTrue,
      );
      expect((await ScheduleRepository(db).day(today))!.openedAt, isNull);
    });

    test('GymRegionSync chỉ gọi iOS khi bản ghi đổi', () async {
      final sync = GymRegionSync(gym);
      final g = GymLocation(lat: 10.77, lng: 106.69, savedAt: tue);
      await sync.apply(g);
      await sync.apply(g);
      await sync.apply(g.withEnabled(false));
      await sync.apply(null);
      expect(gym.calls, ['start', 'stop']);
    });

    test('F32-E3: đăng xuất → ngừng theo dõi vùng, bỏ hàng chờ', () async {
      gym.region = (lat: 10.77, lng: 106.69);
      gym.queue.add(event);
      final hooks = NativeLogoutHooks(
        FakeNativeBridge(),
        clock,
        store: MemoryLiveActivityStore(),
        gym: gym,
      );
      await hooks.endActivities();
      expect(gym.region, isNull);
      expect(gym.queue, isEmpty);
    });
  });
}
