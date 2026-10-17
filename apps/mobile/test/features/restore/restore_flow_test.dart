import 'dart:async';

import 'package:api_contract/api_contract.dart';
import 'package:domain/domain.dart';
import 'package:domain/testing.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/app/app.dart';
import 'package:mobile/app/shell/app_tab_bar.dart';
import 'package:mobile/app/strings_vi.dart';
import 'package:mobile/core/widgets/labeled_field.dart';
import 'package:mobile/data/auth/session_store.dart';
import 'package:mobile/data/db/app_database.dart';
import 'package:mobile/data/sync/outbox_writer.dart';
import 'package:mobile/features/auth/application/auth_controller.dart';
import 'package:mobile/features/me/data/profile_repository.dart';
import 'package:mobile/features/onboarding/application/setup_state.dart';
import 'package:mobile/features/restore/presentation/restore_screen.dart';
import 'package:mobile/features/weight/data/weight_repository.dart';

import '../../support/app_harness.dart';
import '../../support/fake_notifications.dart';
import '../../support/fake_server.dart';
import '../../support/fake_sync.dart';
import '../../support/schedule_fixture.dart';

Map<String, Object?> _change(
  String entity,
  String key,
  int version,
  Map<String, Object?> data,
) => {
  'entity': entity,
  'key': key,
  'deleted': false,
  'serverVersion': version,
  'data': data,
};

Map<String, Object?> _page(
  List<Map<String, Object?>> changes, {
  required int next,
  required int remaining,
}) => {
  'changes': changes,
  'nextCursor': next,
  'hasMore': remaining > 0,
  'remaining': remaining,
  'meta': {'serverTime': '2026-10-07T11:42:00.000Z'},
};

void main() {
  late AppDatabase db;
  late FakeServer server;
  late FakeNotificationGateway notifications;
  late Completer<void>? gate;
  late bool offlineOnPage2;
  final pullCursors = <String>[];

  /// Trên server: hồ sơ đã thiết lập (nhắc [reminders]), cân 2 tuần.
  void serverData({bool reminders = false}) {
    server.on('GET', '/v1/sync/pull', (req) async {
      final cursor = req.query['cursor'] as String? ?? '0';
      pullCursors.add(cursor);
      if (cursor == '0') {
        return (
          200,
          _page(
            [
              _change(
                'profile',
                'me',
                1,
                const ProfileCodec().encode(
                  completedProfile(remindersEnabled: reminders),
                ),
              ),
              _change('weight', '2026-10-05', 2, {'weightKgX10': 800}),
            ],
            next: 2,
            remaining: 2,
          ),
        );
      }
      final g = gate;
      if (g != null) await g.future;
      if (offlineOnPage2) throw FakeOffline();
      return (
        200,
        _page(
          [
            _change('weight', '2026-09-28', 3, {'weightKgX10': 810}),
            _change('account', 'me', 4, {'displayName': 'Minh Anh'}),
          ],
          next: 4,
          remaining: 0,
        ),
      );
    });
  }

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    server = FakeServer()
      ..on(
        'POST',
        '/v1/auth/login',
        (_) => (
          200,
          {
            'accessToken': randomTestSecret(),
            'refreshToken': randomTestSecret(),
            'accessTokenExpiresAt': '2099-01-01T00:00:00.000Z',
          },
        ),
      );
    notifications = FakeNotificationGateway();
    gate = null;
    offlineOnPage2 = false;
    pullCursors.clear();
  });

  Future<ProviderContainer> pump(
    WidgetTester tester, {
    StoredSession? session,
    bool restoreAtStart = false,
  }) async {
    tester.view
      ..physicalSize = const Size(390 * 3, 844 * 3)
      ..devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final container = ProviderContainer(
      retry: (_, _) => null,
      overrides: [
        ...appOverrides(
          db: db,
          server: server,
          session: session,
          onboarded: false,
          notifications: notifications,
          scheduler: FakeScheduler(),
          // Như `main.dart`: trạng thái thiết lập đọc từ máy lúc khởi động.
          initialSetup: SetupState.of(await ProfileRepository(db).get()),
        ),
        initialRestoreProvider.overrideWithValue(restoreAtStart),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const IronlyApp()),
    );
    await tester.pumpAndSettle();
    return container;
  }

  void me(String userId) => server.on(
    'GET',
    '/v1/me',
    (_) => (
      200,
      {
        'userId': userId,
        'phone': '0912345678',
        'displayName': 'Minh',
        'onboardingState': 'completed',
      },
    ),
  );

  Future<void> login(WidgetTester tester) async {
    Finder input(String label) => find.descendant(
      of: find.byWidgetPredicate((w) => w is LabeledField && w.label == label),
      matching: find.byType(TextField),
    );
    await tester.enterText(input(S.fieldPhone), '0912345678');
    await tester.enterText(input(S.fieldPassword), randomTestPassword());
    await tester.tap(find.widgetWithText(FilledButton, S.login));
    await tester.pumpAndSettle();
  }

  final session = StoredSession(
    userId: 'u1',
    phone: '0912345678',
    refreshToken: randomTestSecret(),
  );

  testWidgets('UX-AC4, 05 §6.6.5: có phiên mà máy chưa có dữ liệu (cài lại '
      'app) → S-07 "Đang khôi phục dữ liệu của Bạn…", tiến trình theo '
      'remaining → Hôm nay kèm "Đã khôi phục dữ liệu"', (tester) async {
    serverData();
    final g = gate = Completer<void>();
    me('u1');
    await pump(tester, session: session, restoreAtStart: true);
    expect(find.byType(RestoreScreen), findsOneWidget);
    expect(find.text(S.restoreTitle), findsOneWidget);
    expect(find.text(S.restoreSubtitle), findsOneWidget);
    expect(find.byType(AppTabBar), findsNothing, reason: 'chưa vào app');
    final bar = tester.widget<LinearProgressIndicator>(
      find.byKey(const ValueKey('restore-progress')),
    );
    expect(bar.value, 0.5, reason: 'đã nhận 2, còn 2');
    g.complete();
    await tester.pumpAndSettle();
    expect(find.byType(AppTabBar), findsOneWidget);
    expect(find.text(S.restored), findsOneWidget);
    expect(find.textContaining('Minh Anh'), findsOneWidget);
    expect(
      await WeightRepository(db).all(),
      hasLength(2),
      reason: 'đủ dữ liệu cả 2 trang',
    );
  });

  testWidgets('05 §6.6.5: mất mạng giữa chừng → "Chưa khôi phục xong vì mất '
      'kết nối. Thử lại.", không vào app; "Thử lại" tiếp tục từ cursor đã '
      'nhận', (tester) async {
    serverData();
    offlineOnPage2 = true;
    me('u1');
    await pump(tester, session: session, restoreAtStart: true);
    expect(find.text(S.restoreFailed), findsOneWidget);
    expect(find.byType(AppTabBar), findsNothing);
    expect(pullCursors, ['0', '2']);

    offlineOnPage2 = false;
    await tester.tap(find.byKey(const ValueKey('restore-retry')));
    await tester.pumpAndSettle();
    expect(pullCursors.sublist(2).first, '2', reason: 'không pull lại từ 0');
    expect(find.byType(AppTabBar), findsOneWidget);
    expect(find.text(S.restored), findsOneWidget);
  });

  testWidgets('F09-E2: nhắc đang bật → iPhone hỏi lại quyền thông báo rồi mới '
      'vào Hôm nay; nhắc được hẹn', (tester) async {
    serverData(reminders: true);
    me('u1');
    await pump(tester, session: session, restoreAtStart: true);
    expect(notifications.requests, 1);
    expect(find.byType(AppTabBar), findsOneWidget);
  });

  testWidgets('F09-AC23, F03-E22: tài khoản Chưa có lịch, nhắc bật → khôi '
      'phục trên máy mới → vẫn Chưa có lịch ("Chưa có lịch tập", không có thẻ '
      'tiến độ), công tắc vẫn bật, iPhone hỏi lại quyền, không hẹn nhắc nào', (
    tester,
  ) async {
    serverData(reminders: true);
    me('u1');
    await pump(tester, session: session, restoreAtStart: true);
    expect(notifications.requests, 1);
    expect(find.byKey(const ValueKey('no-schedule-card')), findsOneWidget);
    expect(find.byKey(const ValueKey('progress-card')), findsNothing);
    expect(notifications.scheduled, isEmpty);
    expect((await ProfileRepository(db).get())!.remindersEnabled, isTrue);
  });

  testWidgets(
    'J-06: máy mới đăng nhập tài khoản đã thiết lập → S-07 → Hôm nay, '
    'không phải thiết lập lại',
    (tester) async {
      serverData();
      me('u1');
      await pump(tester);
      await tester.tap(find.widgetWithText(OutlinedButton, S.login));
      await tester.pumpAndSettle();
      await login(tester);
      expect(find.byType(AppTabBar), findsOneWidget);
      expect(find.text(S.restored), findsOneWidget);
      expect(find.text(S.stepOf(1)), findsNothing);
    },
  );

  testWidgets('05 §6.6.6: phiên cũ của tài khoản khác hết hạn, đăng nhập tài '
      'khoản mới → xóa dữ liệu của tài khoản cũ (cả thay đổi chưa gửi) rồi '
      'khôi phục', (tester) async {
    await seedSetUp(db);
    await WeightRepository(db).put(LocalDate(2026, 9, 21), 900);
    await OutboxWriter(
      db,
      FixedClock(DateTime(2026, 10, 7)),
    ).enqueue('weight', '2026-09-21', SyncOp.upsert, {'weightKgX10': 900});
    serverData();
    me('u2');
    await pump(
      tester,
      session: const StoredSession(userId: 'u1', phone: '0912345678'),
    );
    await login(tester);
    expect(find.byType(AppTabBar), findsOneWidget);
    final weeks = [
      for (final w in await WeightRepository(db).all()) w.week.toKey(),
    ];
    expect(weeks, ['2026-09-28', '2026-10-05']);
    expect(await db.select(db.outbox).get(), isEmpty);
    expect(
      server.calls('POST', '/v1/sync/push'),
      isEmpty,
      reason: 'không gửi dữ liệu của tài khoản cũ lên tài khoản mới',
    );
  });

  testWidgets(
    'TA-10: phiên hết hạn, đăng nhập lại cùng tài khoản → giữ dữ liệu '
    'và thay đổi chưa gửi, vào thẳng Hôm nay, đồng bộ tiếp',
    (tester) async {
      await seedSetUp(db);
      await OutboxWriter(
        db,
        FixedClock(DateTime(2026, 10, 7)),
      ).enqueue('weight', '2026-10-05', SyncOp.upsert, {'weightKgX10': 790});
      serverData();
      me('u1');
      await pump(
        tester,
        session: const StoredSession(userId: 'u1', phone: '0912345678'),
      );
      await login(tester);
      expect(find.byType(RestoreScreen), findsNothing);
      expect(find.byType(AppTabBar), findsOneWidget);
      expect(find.text(S.restored), findsNothing);
      final pushed = server.calls('POST', '/v1/sync/push');
      expect(pushed, isNotEmpty, reason: 'thay đổi chưa gửi được đồng bộ tiếp');
      expect(
        ((pushed.first.body! as Map)['mutations']! as List).single,
        containsPair('key', '2026-10-05'),
      );
    },
  );
}
