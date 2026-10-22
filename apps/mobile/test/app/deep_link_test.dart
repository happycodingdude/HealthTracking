import 'package:domain/domain.dart';
import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/app/app.dart';
import 'package:mobile/app/router.dart';
import 'package:mobile/app/shell/app_tab.dart';
import 'package:mobile/data/db/app_database.dart';
import 'package:mobile/features/auth/presentation/login_screen.dart';
import 'package:mobile/features/me/presentation/account_data_screen.dart';
import 'package:mobile/features/today/presentation/today_screen.dart';
import 'package:mobile/features/workout/presentation/session_screen.dart';

import '../support/app_harness.dart';
import '../support/schedule_fixture.dart';

/// 06 Bản 3 VS39-T06: chạm widget / thẻ mở app qua `ironly://…` (TD3-16,
/// NAV-15): đúng màn, đang ở màn khác thì chuyển thẳng.
void main() {
  final monday = LocalDate(2026, 10, 12);

  test('deepLinkLocation', () {
    expect(deepLinkLocation(Uri.parse('ironly://today'), monday), '/today');
    expect(
      deepLinkLocation(Uri.parse('ironly://session/today'), monday),
      sessionPath(AppTab.today, monday),
    );
    expect(deepLinkLocation(Uri.parse('ironly://login'), monday), loginPath);
    expect(deepLinkLocation(Uri.parse('ironly://login/'), monday), loginPath);
    expect(deepLinkLocation(Uri.parse('/today'), monday), isNull);
  });

  /// iOS gửi URL vào app như khi chạm widget (FlutterDeepLinkingEnabled).
  Future<void> open(WidgetTester tester, String url) async {
    await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
      'flutter/navigation',
      const JSONMethodCodec().encodeMethodCall(
        MethodCall('pushRouteInformation', {'location': url, 'state': null}),
      ),
      (_) {},
    );
    await tester.pumpAndSettle();
  }

  Future<ProviderContainer> pump(
    WidgetTester tester, {
    bool signedIn = true,
  }) async {
    tester.view
      ..physicalSize = const Size(390 * 3, 844 * 3)
      ..devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final db = AppDatabase(NativeDatabase.memory());
    await seedSetUp(db);
    final container = ProviderContainer(
      retry: (_, _) => null,
      overrides: appOverrides(
        db: db,
        session: signedIn ? signedInSession : null,
        clock: FixedClock(DateTime(2026, 10, 12, 10)),
      ),
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const IronlyApp()),
    );
    await tester.pumpAndSettle();
    return container;
  }

  testWidgets('NAV-15: có buổi hôm nay → S-63; đang ở màn khác thì chuyển '
      'thẳng', (tester) async {
    final c = await pump(tester);
    c.read(routerProvider).go('/me/account');
    await tester.pumpAndSettle();
    expect(find.byType(AccountDataScreen), findsOneWidget);
    await open(tester, 'ironly://session/today');
    expect(find.byType(SessionScreen), findsOneWidget);
    expect(
      c.read(routerProvider).state.matchedLocation,
      sessionPath(AppTab.today, monday),
    );
  });

  testWidgets('NAV-15: ngày nghỉ / chưa có lịch → Hôm nay', (tester) async {
    final c = await pump(tester);
    c.read(routerProvider).go('/me');
    await tester.pumpAndSettle();
    await open(tester, 'ironly://today');
    expect(find.byType(TodayScreen), findsOneWidget);
  });

  testWidgets('F24-AC5: chưa đăng nhập → ironly://login → màn Đăng nhập', (
    tester,
  ) async {
    await pump(tester, signedIn: false);
    await open(tester, 'ironly://login');
    expect(find.byType(LoginScreen), findsOneWidget);
  });

  testWidgets('chưa đăng nhập mà chạm link buổi tập (widget cũ) → về màn '
      'Chào mừng, không vào app', (tester) async {
    await pump(tester, signedIn: false);
    await open(tester, 'ironly://session/today');
    expect(find.byType(SessionScreen), findsNothing);
  });
}
