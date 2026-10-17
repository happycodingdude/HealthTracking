import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/app/app.dart';
import 'package:mobile/data/db/app_database.dart';
import 'package:mobile/data/notifications/notification_gateway.dart';

import '../support/app_harness.dart';
import '../support/fake_server.dart';
import '../support/fake_sync.dart';
import '../support/schedule_fixture.dart';

/// Gateway giả: hỏi quyền thông báo phải chờ [gate] (giữ tác vụ nền đang chạy
/// dở).
final class _GatedGateway implements NotificationGateway {
  _GatedGateway(this.gate);

  final Future<bool> gate;
  int waiting = 0;
  int scheduled = 0;

  @override
  Future<void> init({required void Function(String payload) onTap}) async {}

  @override
  Future<bool> isPermitted() {
    waiting++;
    return gate;
  }

  @override
  Future<bool> requestPermission() => gate;

  @override
  Future<void> cancelAll() async {}

  @override
  Future<void> schedule({
    required int id,
    required DateTime at,
    required String body,
    required String payload,
  }) async => scheduled++;

  @override
  Future<String> timezone() async => 'Asia/Ho_Chi_Minh';

  @override
  Future<void> openSettings() async {}
}

void main() {
  testWidgets('05 §6.4.4: app bị đóng khi tác vụ nền (lịch tháng, nhắc) đang '
      'chạy dở → dừng êm, không dùng lại widget đã gỡ, không hẹn nhắc', (
    tester,
  ) async {
    final db = AppDatabase(NativeDatabase.memory());
    await seedSetUp(db, profile: completedProfile(remindersEnabled: true));
    final gate = Completer<bool>();
    final gateway = _GatedGateway(gate.future);
    final container = ProviderContainer(
      retry: (_, _) => null,
      overrides: appOverrides(
        db: db,
        server: FakeServer(),
        scheduler: FakeScheduler(),
        notifications: gateway,
      ),
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const IronlyApp()),
    );
    for (var i = 0; i < 20 && gateway.waiting == 0; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(gateway.waiting, greaterThan(0), reason: 'tác vụ nền đang chờ');

    await tester.pumpWidget(const SizedBox());
    gate.complete(true);
    await tester.pump(const Duration(seconds: 1));

    expect(tester.takeException(), isNull);
    expect(gateway.scheduled, 0);
  });
}
