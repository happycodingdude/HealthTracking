import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/app/app_root.dart';
import 'package:mobile/app/router.dart';
import 'package:mobile/app/shell/app_tab_bar.dart';
import 'package:mobile/app/strings_vi.dart';
import 'package:mobile/data/auth/session_store.dart';
import 'package:mobile/data/db/app_database.dart';
import 'package:mobile/data/device_files.dart';
import 'package:mobile/data/local_marks.dart';
import 'package:mobile/data/logout_flag.dart';
import 'package:mobile/features/account/application/logout.dart';
import 'package:mobile/features/auth/presentation/login_screen.dart';
import 'package:mobile/features/me/presentation/account_data_screen.dart';

import '../support/app_harness.dart';
import '../support/fake_logout.dart';
import '../support/fake_notifications.dart';
import '../support/fake_server.dart';
import '../support/fake_sync.dart';

/// Xóa giữ lại ở bước xóa file SQLite tới khi test cho phép.
final class _GatedFiles implements DeviceFiles {
  final inner = FakeDeviceFiles();
  final gate = Completer<void>();

  @override
  Future<void> deleteDatabase() async {
    await gate.future;
    await inner.deleteDatabase();
  }

  @override
  Future<void> deleteDishImages() => inner.deleteDishImages();
}

/// 06 Bản 3 VS38-T02, T05: gốc app — đăng xuất xong dựng lại app ở màn Đăng
/// nhập, không quay lại màn cũ (NAV-19); mở app khi cờ `logout_pending` còn
/// bật → "Đang hoàn tất đăng xuất…" → xóa nốt → màn Đăng nhập (F27-E2).
void main() {
  late FakeServer server;
  late MemoryLogoutFlag flag;
  late MemorySessionStore keychain;
  late _GatedFiles files;
  late FakeNotificationGateway notifications;
  final dbs = <AppDatabase>[];

  setUp(() {
    server = FakeServer();
    server.routes['POST /v1/auth/logout'] = (_) => (204, null);
    flag = MemoryLogoutFlag();
    keychain = MemorySessionStore(signedInSession);
    notifications = FakeNotificationGateway();
    dbs.clear();
  });

  LocalDataEraser eraser() => LocalDataEraser(
    files: files,
    session: keychain,
    marks: MemoryLocalMarks(2026),
    notifications: notifications,
    device: const NoLogoutDeviceHooks(),
    flag: flag,
    reporter: RecordingReporter(),
  );

  AppStart start({required bool afterLogout}) {
    final db = AppDatabase(NativeDatabase.memory());
    dbs.add(db);
    return (
      db: db,
      overrides: [
        ...appOverrides(
          session: afterLogout ? null : signedInSession,
          server: server,
          db: db,
          logoutFlag: flag,
          notifications: notifications,
        ),
        if (afterLogout) initialLocationProvider.overrideWithValue(loginPath),
      ],
    );
  }

  /// Khởi động lại sau đăng xuất: dựng sẵn trong thân test ([appOverrides]
  /// đăng ký dọn dẹp của test).
  AppBoot bootAfterLogout() {
    final next = start(afterLogout: true);
    return ({required afterLogout}) async => next;
  }

  /// Chờ gốc app xóa xong và dựng lại; vòng quay của màn chờ không bao giờ
  /// "settle" nên không dùng pumpAndSettle khi màn chờ còn.
  Future<void> untilLogin(WidgetTester tester) async {
    for (
      var i = 0;
      i < 40 && find.byType(LoginScreen).evaluate().isEmpty;
      i++
    ) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.pumpAndSettle();
  }

  /// Dựng trong thân test: Completer tạo ngoài vùng thời gian giả của
  /// testWidgets không chạy tiếp được khi pump.
  /// Cuối test: gỡ app (ProviderScope bị hủy) và chờ hẹn giờ dọn dẹp của
  /// database chạy xong.
  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
  }

  void phone(WidgetTester tester) {
    files = _GatedFiles();
    tester.view
      ..physicalSize = const Size(390 * 3, 844 * 3)
      ..devicePixelRatio = 3;
    addTearDown(tester.view.reset);
  }

  testWidgets('F27-E2: mở app khi cờ còn bật → "Đang hoàn tất đăng xuất…" → '
      'xóa nốt → màn Đăng nhập như lần cài mới', (tester) async {
    phone(tester);
    await flag.set();
    await tester.pumpWidget(
      AppRoot(boot: bootAfterLogout(), eraser: eraser, initial: null),
    );
    await tester.pump();
    expect(find.byKey(const ValueKey('logout-finishing')), findsOneWidget);
    expect(find.text(S.logoutFinishing), findsOneWidget);
    files.gate.complete();
    await untilLogin(tester);
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(files.inner.database, isFalse);
    expect(await keychain.read(), isNull);
    expect(await flag.isPending(), isFalse);
    await unmount(tester);
  });

  testWidgets('NAV-19, F27-AC4 (phần app): đăng xuất từ S-56 → màn Đăng nhập, '
      'không còn màn cũ để quay lại; nhắc bị hủy', (tester) async {
    phone(tester);
    notifications.scheduled.add((
      id: 1,
      at: DateTime(2026, 10, 8, 17),
      body: '',
      payload: '',
    ));
    final initial = start(afterLogout: false);
    await tester.pumpWidget(
      AppRoot(boot: bootAfterLogout(), eraser: eraser, initial: initial),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(of: find.byType(AppTabBar), matching: find.text(S.tabMe)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('row-account-data')));
    await tester.pumpAndSettle();
    final row = find.byKey(const ValueKey('row-logout'));
    await tester.ensureVisible(row);
    await tester.pumpAndSettle();
    await tester.tap(row);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('logout-confirm')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byKey(const ValueKey('logout-finishing')), findsOneWidget);
    files.gate.complete();
    await untilLogin(tester);

    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.byType(AccountDataScreen), findsNothing);
    expect(find.byType(AppTabBar), findsNothing);
    // Lùi từ màn Đăng nhập chỉ về màn Chào mừng, không về app cũ.
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(AccountDataScreen), findsNothing);
    expect(find.byType(AppTabBar), findsNothing);

    expect(server.calls('POST', '/v1/auth/logout'), hasLength(1));
    expect(notifications.scheduled, isEmpty);
    expect(await flag.isPending(), isFalse);
    await unmount(tester);
  });
}
