import 'package:api_contract/api_contract.dart';
import 'package:domain/testing.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/data/api/api_client.dart';
import 'package:mobile/data/auth/session_store.dart';
import 'package:mobile/data/db/app_database.dart';
import 'package:mobile/data/local_marks.dart';
import 'package:mobile/data/logout_flag.dart';
import 'package:mobile/data/sync/sync_engine.dart';
import 'package:mobile/features/account/application/logout.dart';

import '../../support/app_harness.dart';
import '../../support/fake_logout.dart';
import '../../support/fake_notifications.dart';
import '../../support/fake_sync.dart';

/// Bị tắt app giữa chừng (06 Bản 3 ED3-10).
final class _Killed implements Exception {}

/// Một iPhone đang đăng nhập, có 2 thay đổi chưa đồng bộ, hình món ăn, nhắc.
final class _Phone {
  _Phone() {
    notifications.scheduled.add((
      id: 1,
      at: DateTime(2026, 10, 23, 17),
      body: '',
      payload: '',
    ));
  }

  final refreshToken = randomTestSecret();
  late final session = MemorySessionStore(
    StoredSession(
      userId: 'u1',
      phone: '0912345678',
      refreshToken: refreshToken,
    ),
  );
  final db = AppDatabase(NativeDatabase.memory());
  final files = FakeDeviceFiles();
  final marks = MemoryLocalMarks(2026);
  final notifications = FakeNotificationGateway();
  final hooks = FakeLogoutHooks();
  final flag = MemoryLogoutFlag();
  final reporter = RecordingReporter();
  final connectivity = FakeConnectivity();

  /// Thay đổi chưa gửi (outbox) và trên server.
  int unsynced = 2;
  int onServer = 0;
  final revoked = <String>[];

  SyncOutcome flushResult = SyncOutcome.synced;
  Object? revokeError;

  /// Bước bị cắt (một lần).
  LogoutStep? killAt;

  void _before(LogoutStep step) {
    if (step == killAt) {
      killAt = null;
      throw _Killed();
    }
  }

  LocalDataEraser eraser() => LocalDataEraser(
    files: files,
    session: session,
    marks: marks,
    notifications: notifications,
    device: hooks,
    flag: flag,
    reporter: reporter,
    beforeStep: _before,
  );

  /// Gốc app: xóa với database đang mở (05 Bản 3 §6.6.6 bước 5–6).
  Logout logout() => Logout(
    connectivity: connectivity,
    flush: () async {
      if (flushResult == SyncOutcome.synced) {
        onServer += unsynced;
        unsynced = 0;
      }
      return flushResult;
    },
    revoke: (token) async {
      if (revokeError case final e?) throw e;
      revoked.add(token);
    },
    session: session,
    device: hooks,
    flag: flag,
    finish: () => eraser().run(db),
    beforeStep: _before,
  );

  /// Mở app lại: cờ còn bật → xóa nốt khi chưa mở database (F27-E2).
  Future<void> reopen() async {
    if (await flag.isPending()) await eraser().run(null);
  }

  Future<void> expectErased() async {
    expect(onServer, 2, reason: 'đồng bộ hết trước khi xóa (F27-R3)');
    expect(unsynced, 0);
    // Bị cắt sau khi thu hồi thì lần chạy lại thu hồi thêm lần nữa (TD3-18).
    expect(revoked.toSet(), {
      refreshToken,
    }, reason: 'thu hồi phiên trên server');
    expect(files.database, isFalse);
    expect(files.dishImages, isFalse);
    expect(await session.read(), isNull);
    expect(await marks.lastAgeYear(), isNull);
    expect(hooks.activityToken, isFalse);
    expect(hooks.appGroup, isFalse);
    expect(hooks.activities, isFalse);
    expect(hooks.widgetReloads, greaterThan(0));
    expect(notifications.scheduled, isEmpty);
    expect(await flag.isPending(), isFalse);
  }

  Future<void> expectUntouched() async {
    expect(unsynced + onServer, 2);
    expect(files.database, isTrue);
    expect(files.dishImages, isTrue);
    expect((await session.read())?.refreshToken, refreshToken);
    expect(await marks.lastAgeYear(), 2026);
    expect(notifications.scheduled, hasLength(1));
    expect(await flag.isPending(), isFalse);
  }
}

void main() {
  late _Phone phone;

  setUp(() => phone = _Phone());
  tearDown(() => phone.db.close());

  test('chạy liền: đồng bộ → thu hồi → xóa hết theo TD3-17 (TAC3-10 phần '
      'app)', () async {
    expect(await phone.logout()(), LogoutOutcome.done);
    await phone.expectErased();
  });

  test('F27-R2: không có mạng → không làm gì, không gọi đồng bộ', () async {
    phone.connectivity.setOnline(false);
    var syncing = false;
    final outcome = await phone.logout()(onSyncing: () => syncing = true);
    expect(outcome, LogoutOutcome.offline);
    expect(syncing, isFalse);
    expect(phone.unsynced, 2);
    await phone.expectUntouched();
  });

  test('F27-R3, F27-E1: đồng bộ lỗi → không đăng xuất, dữ liệu còn', () async {
    phone.flushResult = SyncOutcome.failed;
    var syncing = false;
    final outcome = await phone.logout()(onSyncing: () => syncing = true);
    expect(outcome, LogoutOutcome.syncFailed);
    expect(syncing, isTrue);
    expect(phone.revoked, isEmpty);
    await phone.expectUntouched();
  });

  test(
    'phiên hết hạn lúc đồng bộ → không xóa (còn dữ liệu chưa gửi)',
    () async {
      phone.flushResult = SyncOutcome.sessionExpired;
      expect(await phone.logout()(), LogoutOutcome.syncFailed);
      await phone.expectUntouched();
    },
  );

  test('thu hồi phiên mất mạng → như đồng bộ lỗi', () async {
    phone.revokeError = const NetworkFailure();
    expect(await phone.logout()(), LogoutOutcome.syncFailed);
    expect(phone.files.database, isTrue);
    expect(await phone.flag.isPending(), isFalse);
  });

  test('thu hồi phiên 401 (phiên đã hết hạn) → coi như đã thu hồi', () async {
    phone.revokeError = const ServerFailure(
      ApiError(ErrorCode.unauthorized),
      401,
    );
    expect(await phone.logout()(), LogoutOutcome.done);
    expect(phone.files.database, isFalse);
    expect(await phone.flag.isPending(), isFalse);
  });

  group('ED3-10, F27-E2: cắt giữa chừng tại từng bước rồi chạy lại → như '
      'chạy liền', () {
    for (final step in LogoutStep.values) {
      test(step.name, () async {
        phone.killAt = step;
        await expectLater(phone.logout()(), throwsA(isA<_Killed>()));
        final pending = await phone.flag.isPending();
        expect(
          pending,
          step.index > LogoutStep.setPending.index,
          reason: 'cờ bật trước bước xóa đầu tiên',
        );
        if (!pending) {
          // Chưa xóa gì: vẫn đăng nhập, Bạn bấm đăng xuất lại.
          expect(phone.files.database, isTrue);
          expect((await phone.session.read())?.refreshToken, isNotNull);
          await phone.reopen();
          expect(await phone.logout()(), LogoutOutcome.done);
        } else {
          await phone.reopen();
        }
        await phone.expectErased();
      });
    }
  });

  test('một bước xóa lỗi → các bước sau vẫn chạy, giữ cờ, lần mở sau xóa '
      'nốt', () async {
    phone.files.failNextDatabaseDelete = true;
    expect(await phone.logout()(), LogoutOutcome.done);
    expect(phone.files.database, isTrue);
    expect(await phone.session.read(), isNull);
    expect(await phone.flag.isPending(), isTrue);
    expect(phone.reporter.reasons, contains('logout_deleteSqlite'));
    await phone.reopen();
    await phone.expectErased();
  });
}
