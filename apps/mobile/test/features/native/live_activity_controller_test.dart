import 'dart:io';

import 'package:api_contract/api_contract.dart';
import 'package:domain/domain.dart';
import 'package:domain/testing.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/app/strings_vi.dart';
import 'package:mobile/data/auth/session_store.dart';
import 'package:mobile/data/db/app_database.dart';
import 'package:mobile/features/native/live_activity_controller.dart';
import 'package:mobile/features/native/native_bridge.dart';
import 'package:mobile/features/today/application/mark_session.dart';
import 'package:mobile/features/workout/application/lift_log_edits.dart';
import 'package:mobile/features/workout/data/exercise_unit_repository.dart';
import 'package:mobile/features/workout/data/lift_log_repository.dart';

import '../../support/app_harness.dart';
import '../../support/fake_native.dart';
import '../../support/fake_server.dart';
import '../../support/library_fixture.dart';
import '../../support/schedule_fixture.dart';

/// 06 Bản 3 VS41-T06 (Dart): `LiveActivityController` với cầu giả — mọi đường
/// của bảng 05 Bản 3 §6.4.4; gửi token chỉ khi đổi hoặc sau 24 giờ (TA3-12);
/// cập nhật sau ghi tạ (F25-AC2, F25-R4), chỉ lưu ghi chú → không (UA3-02);
/// "Đã tập" → tắt + `liveActivityEnded` (F25-AC3); không bật thẻ (ED3-09).
void main() {
  final monday = LocalDate(2026, 10, 12);
  const pecDeck = 'chest-mid-machine-pec-deck';
  const bench = 'chest-mid-free-weight-flat-barbell-bench-press';
  late AppDatabase db;
  late FakeNativeBridge native;
  late FakeServer server;
  late FixedClock clock;
  late ProviderContainer container;
  late List<Map<Object?, Object?>> puts;
  late String startToken;

  Future<LiveActivityController> setUpPhone({
    DateTime? now,
    StoredSession? session = const StoredSession(userId: '', phone: ''),
  }) async {
    db = AppDatabase(NativeDatabase.memory());
    await seedSetUp(db);
    await seedLibrary(db, realLibraryV3());
    final units = ExerciseUnitRepository(db);
    for (final id in [pecDeck, bench]) {
      await units.put(
        ExerciseUnit(
          exerciseId: id,
          unit: LiftUnit.kg,
          changedOn: LocalDate(2026, 10, 5),
        ),
      );
    }
    // Buổi trước (thứ 4 07/10): Máy ép ngực 40 → 45 kg.
    await LiftLogRepository(db).put(
      LiftLog(
        date: LocalDate(2026, 10, 7),
        exerciseId: pecDeck,
        startKgX10: 400,
        endKgX10: 450,
      ),
    );
    native = FakeNativeBridge();
    startToken = randomTestSecret();
    native.startToken = startToken;
    server = FakeServer();
    puts = [];
    server.routes['PUT /v1/me/live-activity-token'] = (req) {
      puts.add(req.body! as Map<Object?, Object?>);
      return (204, null);
    };
    clock = FixedClock(now ?? DateTime(2026, 10, 12, 18, 30));
    container = ProviderContainer(
      retry: (_, _) => null,
      overrides: [
        ...appOverrides(
          db: db,
          server: server,
          native: native,
          clock: clock,
          session:
              identical(session, const StoredSession(userId: '', phone: ''))
              ? signedInSession
              : session,
        ),
        liftChangeHooksProvider.overrideWith(
          (ref) => ref.watch(liveActivityControllerProvider),
        ),
        sessionMarkHooksProvider.overrideWith(
          (ref) => ref.watch(liveActivityControllerProvider),
        ),
      ],
    );
    addTearDown(container.dispose);
    return container.read(liveActivityControllerProvider);
  }

  Map<String, Object?>? content(String id) => native.activities[id]?.content;

  test('mở app: thẻ ngày cũ → tắt ngay; thẻ hôm nay giữ; gửi push-to-start và '
      'token cập nhật của thẻ hôm nay (TA3-12, TA3-13)', () async {
    final c = await setUpPhone();
    final update = randomTestSecret();
    native
      ..startActivity('old', LocalDate(2026, 10, 9))
      ..startActivity('today', monday, token: update);
    await c.refresh();
    expect(native.activities.keys, ['today']);
    expect(puts.single, {
      'pushToStartToken': startToken,
      'activityPushToken': update,
      'activityDate': '2026-10-12',
      'environment': 'sandbox',
      'appVersion': AppVersion.v3.toString(),
    });
  });

  test('TA3-12: token không đổi trong 24 giờ → không gửi lại; quá 24 giờ hoặc '
      'token đổi → gửi', () async {
    final c = await setUpPhone();
    await c.refresh();
    await c.refresh();
    expect(puts, hasLength(1));
    clock.advance(const Duration(hours: 24));
    await c.refresh();
    expect(puts, hasLength(2));
    native.startToken = randomTestSecret();
    await c.refresh();
    expect(puts, hasLength(3));
    expect(puts.last['pushToStartToken'], native.startToken);
  });

  test('sự kiện token từ iOS: push-to-start mới → gửi; token cập nhật của thẻ '
      'hôm nay → gửi kèm ngày; của ngày khác → bỏ qua', () async {
    final c = await setUpPhone();
    c.start();
    final fresh = randomTestSecret();
    native.emit(PushToStartTokenEvent(fresh));
    await pumpEventQueue();
    expect(puts.single['pushToStartToken'], fresh);
    native.startToken = fresh;
    final update = randomTestSecret();
    native.emit(ActivityTokenEvent('x', LocalDate(2026, 10, 9), update));
    await pumpEventQueue();
    expect(puts, hasLength(1));
    native.startActivity('today', monday, token: update);
    native.emit(ActivityTokenEvent('today', monday, update));
    await pumpEventQueue();
    expect(puts.last['activityPushToken'], update);
    expect(puts.last['activityDate'], '2026-10-12');
  });

  test(
    'F25-AC2, F25-R4: ghi tạ → "Vừa ghi" / "Kế tiếp" đổi; xóa bản vừa ghi '
    '→ lùi về bản lưu trước đó; F25-R10: đổi đơn vị → con số cũ, đơn vị mới',
    () async {
      await setUpPhone();
      native.startActivity('today', monday);
      final save = container.read(saveLiftLogProvider);
      await save(monday, pecDeck, start: '40', end: '47,5');
      expect(content('today'), {
        'lastLogged': {'name': 'Máy ép ngực', 'lift': '40 → 47,5 kg'},
        'next': {'name': 'Nằm ghế ngang đẩy thanh tạ', 'prev': null},
        'allLogged': false,
        'absOnly': false,
      });
      await save(monday, bench, start: '50', end: '55');
      expect(
        (content('today')!['lastLogged']! as Map)['name'],
        'Nằm ghế ngang đẩy thanh tạ',
      );
      await container.read(deleteLiftLogProvider).call(monday, bench);
      expect(content('today')!['lastLogged'], {
        'name': 'Máy ép ngực',
        'lift': '40 → 47,5 kg',
      });
      await container
          .read(changeExerciseUnitProvider)
          .call(pecDeck, LiftUnit.steps);
      expect(content('today')!['lastLogged'], {
        'name': 'Máy ép ngực',
        'lift': '40 → 47,5 nấc',
      });
    },
  );

  test('UA3-02: chỉ lưu ghi chú → thẻ không cập nhật', () async {
    await setUpPhone();
    native.startActivity('today', monday);
    await container
        .read(saveLiftEntryProvider)
        .call(monday, pecDeck, start: '', end: '', note: 'máy 2 hỏng');
    expect(native.calls, isNot(contains('liveActivity.update')));
  });

  test('F25-AC3: "Đã tập" → thẻ tắt ngay, mutation day kèm '
      'liveActivityEnded; ghi thêm sau đó → thẻ không hiện lại', () async {
    await setUpPhone();
    native.startActivity('today', monday);
    await container.read(markSessionDoneProvider).call(monday, confirmed: true);
    expect(native.activities, isEmpty);
    final outbox = await db.select(db.outbox).get();
    expect(
      outbox.where((o) => o.entity == 'day').single.payload,
      contains('"liveActivityEnded":true'),
    );
    await container
        .read(saveLiftLogProvider)
        .call(monday, pecDeck, start: '40', end: '45');
    expect(native.activities, isEmpty);
  });

  test('"Không tập" → thẻ tắt ngay', () async {
    await setUpPhone();
    native.startActivity('today', monday);
    await container.read(markSessionSkippedProvider).call(monday);
    expect(native.activities, isEmpty);
  });

  test('phiên hết hạn / chưa đăng nhập → không gửi token, không cập nhật (thẻ '
      'vẫn tự tắt lúc 00:00)', () async {
    final c = await setUpPhone(session: null);
    native.startActivity('today', monday);
    await c.refresh();
    await c.liftChanged(monday, pecDeck, deleted: false);
    expect(puts, isEmpty);
    expect(native.calls, isNot(contains('liveActivity.update')));
    expect(native.activities.keys, ['today']);
  });

  test('F25-AC5: qua 00:00 lúc app mở → thẻ hôm qua tắt', () async {
    final c = await setUpPhone(now: DateTime(2026, 10, 13, 0, 1));
    native.startActivity('today', monday);
    await c.refresh();
    expect(native.activities, isEmpty);
  });

  test('ED3-09, TD3-14: app không bao giờ bật thẻ — không có Activity.request '
      'trong Swift, cầu Dart không có hàm bật thẻ', () {
    final swift = [
      ...Directory('ios/Runner').listSync(),
      ...Directory('ios/IronlyWidgets').listSync(),
    ].whereType<File>().where((f) => f.path.endsWith('.swift'));
    for (final f in swift) {
      expect(
        f.readAsStringSync(),
        isNot(matches(RegExp(r'\.request\s*\('))),
        reason: f.path,
      );
    }
    final dart = File(
      'lib/features/native/native_bridge.dart',
    ).readAsStringSync();
    expect(dart, isNot(contains('request')));
    expect(NativeBridge, isNotNull);
  });

  /// Mã Swift của extension (widget, thẻ) và cầu trong Runner.
  Iterable<File> swiftSources() => [
    ...Directory('ios/Runner').listSync(),
    ...Directory('ios/IronlyWidgets').listSync(),
  ].whereType<File>().where((f) => f.path.endsWith('.swift'));

  test('F25-AC6, F25-R6, F24-R1: thẻ và widget không có nút nào (không '
      'Button, Toggle, Link, AppIntent); chạm thẻ mở buổi hôm nay', () {
    final widgets = Directory(
      'ios/IronlyWidgets',
    ).listSync().whereType<File>().where((f) => f.path.endsWith('.swift'));
    for (final f in widgets) {
      expect(
        f.readAsStringSync(),
        isNot(matches(RegExp(r'\b(Button|Toggle|Link)\s*[({]|AppIntent'))),
        reason: f.path,
      );
    }
    final activity = File(
      'ios/IronlyWidgets/IronlySessionActivity.swift',
    ).readAsStringSync();
    expect(activity, contains('"ironly://session/today"'));
    expect(RegExp(r'\.widgetURL\(').allMatches(activity), hasLength(2));
  });

  test('F25-AC8, F25-R7, A3-10: app không đọc quyền thẻ và không có câu nào '
      'nhắc về quyền thẻ; tắt quyền thì iOS không hiện thẻ, app không báo', () {
    for (final f in swiftSources()) {
      expect(
        f.readAsStringSync(),
        isNot(
          matches(
            RegExp(
              'ActivityAuthorizationInfo|areActivitiesEnabled|'
              'activityEnablementUpdates',
            ),
          ),
        ),
        reason: f.path,
      );
    }
    final dart = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'));
    for (final f in dart) {
      expect(
        f.readAsStringSync(),
        isNot(matches(RegExp('areActivitiesEnabled|activitiesEnabled'))),
        reason: f.path,
      );
    }
    for (final MapEntry(:key, :value) in S.catalog.entries) {
      expect(value, isNot(contains('màn hình khóa')), reason: key);
    }
  });
}
