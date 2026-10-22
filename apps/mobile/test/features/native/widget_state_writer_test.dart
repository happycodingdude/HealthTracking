import 'dart:convert';

import 'package:domain/domain.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart' hide WidgetState;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/app/app.dart';
import 'package:mobile/app/providers.dart';
import 'package:mobile/app/time_ticker.dart';
import 'package:mobile/core/formatters.dart';
import 'package:mobile/data/auth/token_manager.dart';
import 'package:mobile/data/db/app_database.dart';
import 'package:mobile/features/native/native_bridge.dart';
import 'package:mobile/features/native/native_logout_hooks.dart';
import 'package:mobile/features/native/widget_state_writer.dart';
import 'package:mobile/features/schedule/application/schedule_edits.dart';
import 'package:mobile/features/schedule/data/schedule_repository.dart';
import 'package:mobile/features/today/application/mark_session.dart';

import '../../support/app_harness.dart';
import '../../support/fake_native.dart';
import '../../support/fake_server.dart';
import '../../support/schedule_fixture.dart';

/// 06 Bản 3 VS39-T04, T08 (app): nội dung widget được ghi ở mọi sự kiện F24-R5
/// (cầu Swift giả), không ghi lại khi không đổi, ghi < 200 ms (IA3-09).
void main() {
  final monday = LocalDate(2026, 10, 12);
  final tuesday = LocalDate(2026, 10, 13);
  late AppDatabase db;
  late FakeNativeBridge native;
  late FakeServer server;
  late FixedClock clock;
  late ProviderContainer container;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    native = FakeNativeBridge();
    server = FakeServer();
  });

  Future<void> pump(WidgetTester tester, DateTime now) async {
    await seedSetUp(db);
    clock = FixedClock(now);
    container = ProviderContainer(
      retry: (_, _) => null,
      overrides: appOverrides(
        db: db,
        server: server,
        clock: clock,
        native: native,
      ),
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const IronlyApp()),
    );
    await tester.pumpAndSettle();
  }

  Map<String, Object?> today() =>
      ((native.current!['days']! as List).first as Map).cast();

  Map<String, Object?> week() => (today()['week']! as Map).cast();

  testWidgets('mở app: ghi nội dung hôm nay rồi reloadAllTimelines (thứ 2 '
      'Ngực + Tay sau, 0/3)', (tester) async {
    await pump(tester, DateTime(2026, 10, 12, 10));
    expect(native.calls.take(2), ['writeWidgetState', 'reloadWidgets']);
    expect(native.current!['signedIn'], isTrue);
    expect(native.current!['hasSchedule'], isTrue);
    expect(native.current!['days'], hasLength(8));
    expect(today(), containsPair('weekday', 'Thứ 2'));
    expect(today()['groups'], ['Ngực', 'Tay sau']);
    expect(today()['time'], '18:00');
    expect(week(), {
      'total': 3,
      'done': 0,
      'extra': 0,
      'dots': [false, false, false],
    });
  });

  testWidgets('F24-AC2: "Đã tập" → ghi lại mark done, 1/3; không đổi gì thì '
      'không ghi thêm', (tester) async {
    await pump(tester, DateTime(2026, 10, 12, 19, 30));
    final before = native.written.length;
    await tester.pumpAndSettle();
    expect(native.written.length, before, reason: 'nội dung không đổi');
    await container.read(markSessionDoneProvider).call(monday, confirmed: true);
    await tester.pumpAndSettle();
    expect(native.written.length, before + 1);
    expect(today()['mark'], 'done');
    expect(week()['dots'], [true, false, false]);
    expect(native.calls.last, 'reloadWidgets');
  });

  testWidgets('"Không tập" → mark skipped', (tester) async {
    await pump(tester, DateTime(2026, 10, 12, 19, 30));
    await container.read(markSessionSkippedProvider).call(monday);
    await tester.pumpAndSettle();
    expect(today()['mark'], 'skipped');
  });

  testWidgets('F24-E3: buổi tập thêm ngày nghỉ → "+1 buổi thêm", +1', (
    tester,
  ) async {
    await pump(tester, DateTime(2026, 10, 13, 20));
    expect(today()['kind'], 'rest');
    await container.read(addExtraSessionProvider).call(tuesday, const [
      MuscleGroup.abs,
    ], confirmed: true);
    await tester.pumpAndSettle();
    expect(today()['extra'], isTrue);
    expect(week()['extra'], 1);
  });

  testWidgets('F24-E2: sửa riêng hôm nay sang Vai → "Vai"', (tester) async {
    await pump(tester, DateTime(2026, 10, 12, 10));
    await container
        .read(scheduleEditsProvider)
        .overrideDay(
          monday,
          time: LocalTime(17, 0),
          muscles: const [MuscleGroup.shoulders],
        );
    await tester.pumpAndSettle();
    expect(today()['groups'], ['Vai']);
    expect(today()['time'], '17:00');
  });

  testWidgets('TD3-15: dữ liệu pull về (bản ghi ngày đổi) → ghi lại', (
    tester,
  ) async {
    await pump(tester, DateTime(2026, 10, 12, 19, 30));
    final day = (await ScheduleRepository(db).day(monday))!;
    await ScheduleRepository(db).putDay(
      day.withMark(
        DayMark.done,
        actual: day.muscles,
        markedAt: DateTime(2026, 10, 12, 19),
      ),
    );
    await tester.pumpAndSettle();
    expect(today()['mark'], 'done');
  });

  testWidgets('F24-AC7: qua 00:00 lúc app đang mở → nội dung ngày mới', (
    tester,
  ) async {
    await pump(tester, DateTime(2026, 10, 12, 23, 59));
    clock.set(DateTime(2026, 10, 13, 0, 1));
    container.invalidate(nowProvider);
    await tester.pumpAndSettle();
    expect(today()['date'], '2026-10-13');
    expect(today()['kind'], 'rest');
  });

  testWidgets('quay lại foreground → ghi lại kể cả khi không đổi (F24-R5 "mở '
      'app")', (tester) async {
    await pump(tester, DateTime(2026, 10, 12, 10));
    final before = native.written.length;
    tester.binding
      ..handleAppLifecycleStateChanged(AppLifecycleState.inactive)
      ..handleAppLifecycleStateChanged(AppLifecycleState.hidden)
      ..handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    tester.binding
      ..handleAppLifecycleStateChanged(AppLifecycleState.hidden)
      ..handleAppLifecycleStateChanged(AppLifecycleState.inactive)
      ..handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(native.written.length, before + 1);
  });

  testWidgets(
    'F24-R6: phiên hết hạn → "Mở app để đăng nhập" (signedIn false)',
    (tester) async {
      await pump(tester, DateTime(2026, 10, 12, 10));
      server.routes['POST /v1/auth/refresh'] = (_) => (
        401,
        {
          'error': {'code': 'unauthorized'},
        },
      );
      // Gọi server giả thật sự (dio) cần thời gian thật.
      await tester.runAsync(
        () => expectLater(
          container.read(tokenManagerProvider).refresh(),
          throwsA(isA<SessionExpired>()),
        ),
      );
      await tester.pumpAndSettle();
      expect(native.current!['signedIn'], isFalse);
      expect(today()['groups'], isEmpty);
    },
  );

  testWidgets('IA3-09: tính và ghi nội dung widget dưới 200 ms', (
    tester,
  ) async {
    await pump(tester, DateTime(2026, 10, 12, 10));
    final watch = Stopwatch()..start();
    container.invalidate(widgetStateProvider);
    final state = container.read(widgetStateProvider)!;
    await container.read(widgetStateWriterProvider).write(state, force: true);
    watch.stop();
    expect(watch.elapsedMilliseconds, lessThan(200));
  });

  test('VS39-T05: đăng xuất — xóa App Group, ghi "Mở app để đăng nhập", làm '
      'mới widget', () async {
    final bridge = FakeNativeBridge();
    final hooks = NativeLogoutHooks(
      bridge,
      FixedClock(DateTime(2026, 10, 12, 10)),
    );
    await hooks.clearAppGroup();
    await hooks.reloadWidgets();
    expect(bridge.calls, [
      'appGroupClear',
      'writeWidgetState',
      'reloadWidgets',
    ]);
    expect(bridge.current!['signedIn'], isFalse);
  });

  test('ED3-06: channel dev.antonnguyen.ironly/native, tên method', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    const channel = MethodChannel('dev.antonnguyen.ironly/native');
    final calls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          return null;
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null),
    );
    const bridge = ChannelNativeBridge();
    final json = jsonEncode(
      WidgetState.signedOut(DateTime(2026, 10, 12)).toJson(),
    );
    await bridge.writeWidgetState(json);
    await bridge.reloadWidgets();
    await bridge.appGroupClear();
    expect(
      [for (final c in calls) c.method],
      ['writeWidgetState', 'reloadWidgets', 'appGroupClear'],
    );
    expect(calls.first.arguments, json);
  });

  test('tên tiếng Việt ngoài app trùng câu chữ của app', () {
    for (final m in MuscleGroup.values) {
      expect(VietnameseLabels.muscle(m), Fmt.muscle(m));
    }
    for (var i = 0; i < 7; i++) {
      final d = LocalDate(2026, 10, 12).addDays(i);
      expect(VietnameseLabels.weekday(d), Fmt.weekday(d));
    }
  });
}
