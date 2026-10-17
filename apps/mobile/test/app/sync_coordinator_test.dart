import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/app/app.dart';
import 'package:mobile/data/sync/sync_providers.dart';

import '../support/app_harness.dart';
import '../support/fake_server.dart';

void main() {
  Future<ProviderContainer> pump(
    WidgetTester tester, {
    bool signedIn = true,
    FakeConnectivity? net,
    required FakeServer server,
  }) async {
    final container = ProviderContainer(
      retry: (_, _) => null,
      overrides: appOverrides(
        session: signedIn ? signedInSession : null,
        connectivity: net,
        server: server,
      ),
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const IronlyApp()),
    );
    await tester.pumpAndSettle();
    return container;
  }

  testWidgets(
    '05 §6.6.4: mở app khi đã đăng nhập → làm mới token rồi đồng bộ ngay',
    (tester) async {
      final server = FakeServer();
      final c = await pump(tester, server: server);
      expect(c.read(syncEngineProvider).isStarted, isTrue);
      expect(server.calls('POST', '/v1/auth/refresh'), hasLength(1));
      expect(server.calls('GET', '/v1/sync/pull'), hasLength(1));
      expect(
        server.calls('GET', '/v1/sync/pull').single.authorization,
        'Bearer $refreshedAccessToken',
      );
    },
  );

  testWidgets('chưa đăng nhập → không đồng bộ', (tester) async {
    final server = FakeServer();
    final c = await pump(tester, signedIn: false, server: server);
    expect(c.read(syncEngineProvider).isStarted, isFalse);
    expect(server.calls('GET', '/v1/sync/pull'), isEmpty);
  });

  testWidgets('05 §6.6.4: chạy nền → dừng; quay lại foreground → đồng bộ lại', (
    tester,
  ) async {
    final server = FakeServer();
    final c = await pump(tester, server: server);
    final engine = c.read(syncEngineProvider);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    await tester.pumpAndSettle();
    expect(engine.isStarted, isFalse);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(engine.isStarted, isTrue);
    expect(server.calls('GET', '/v1/sync/pull'), hasLength(2));
  });

  testWidgets('05 §6.6.4: có mạng trở lại → đồng bộ ngay', (tester) async {
    final server = FakeServer();
    final net = FakeConnectivity();
    await pump(tester, net: net, server: server);
    net.setOnline(false);
    net.setOnline(true);
    await tester.pumpAndSettle();
    expect(server.calls('GET', '/v1/sync/pull'), hasLength(2));
  });
}
