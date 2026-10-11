@Tags(['e2e'])
library;

import 'dart:io';

import 'package:api_contract/api_contract.dart';
import 'package:domain/domain.dart';
import 'package:flutter_test/flutter_test.dart' hide pumpEventQueue;
import 'package:mobile/data/api/api_client.dart';
import 'package:mobile/data/sync/sync_api.dart';
import 'package:mobile/data/sync/sync_engine.dart';
import 'package:mobile/features/onboarding/data/onboarding_draft_repository.dart';
import 'package:postgres/postgres.dart';
import 'package:uuid/uuid.dart';

import 'sync_e2e_harness.dart';

/// Lịch tuần thử: T2 Ngực 06:00, T4 Lưng 06:00, T6 Vai 06:00.
final _template = WeeklyTemplate({
  1: TemplateDay(
    enabled: true,
    time: LocalTime(6, 0),
    muscles: const [MuscleGroup.chest],
  ),
  3: TemplateDay(
    enabled: true,
    time: LocalTime(6, 0),
    muscles: const [MuscleGroup.back],
  ),
  5: TemplateDay(
    enabled: true,
    time: LocalTime(6, 0),
    muscles: const [MuscleGroup.shoulders],
  ),
});

/// SyncApi mô phỏng mạng di động: chờ [latency] mỗi lần gọi, trang nhỏ
/// [limit], và mất mạng ở lần pull thứ [failAt] (một lần).
final class _SlowFlakyApi implements SyncApi {
  _SlowFlakyApi(
    this._inner, {
    this.latency = Duration.zero,
    this.limit,
    this.failAt,
  });

  final SyncApi _inner;
  final Duration latency;
  final int? limit;
  int? failAt;
  final pulls = <int>[];

  @override
  Future<PushResponse> push(PushRequest request) async {
    await Future<void>.delayed(latency);
    return _inner.push(request);
  }

  @override
  Future<PullResponse> pull({
    required int cursor,
    int limit = PullResponse.maxLimit,
  }) async {
    await Future<void>.delayed(latency);
    pulls.add(cursor);
    if (failAt == pulls.length) {
      failAt = null;
      throw const NetworkFailure();
    }
    return _inner.pull(cursor: cursor, limit: this.limit ?? limit);
  }
}

void main() {
  late E2eServer server;
  final devices = <E2eDevice>[];

  setUpAll(() => HttpOverrides.global = null);
  setUp(() async => server = await E2eServer.start());
  tearDown(() async {
    for (final d in devices) {
      await d.close();
    }
    devices.clear();
    await server.stop();
  });

  E2eDevice device({DateTime? now, SyncApi Function(SyncApi)? wrap}) {
    final d = E2eDevice(server, now: now, wrapSyncApi: wrap);
    devices.add(d);
    return d;
  }

  /// Thiết lập đủ 5 bước lúc [at] qua use case thật; Bạn tự đặt 1.900 kcal,
  /// bật nhắc.
  Future<void> setUp5Steps(E2eDevice d, DateTime at) async {
    d.clock.set(at);
    await d.onboarding.acceptDisclaimer();
    expect(
      await d.onboarding.saveProfile(
        const ProfileDraft(
          height: '175',
          birthYear: 1996,
          sex: Sex.male,
          activityLevel: ActivityLevel.moderate,
          weight: '80',
        ),
      ),
      isEmpty,
    );
    expect(await d.onboarding.saveCalorie(manualKcal: 1900), isTrue);
    expect(await d.onboarding.saveSchedule(_template), isEmpty);
    await d.onboarding.complete(
      remindersEnabled: true,
      timezone: 'Asia/Ho_Chi_Minh',
    );
  }

  test('TAC-04, F09-AC1, F09-AC3: máy A có đủ hồ sơ, mức calo và đề xuất, lịch '
      'tuần, lịch tháng, buổi đã đánh dấu, buổi tập thêm, cân nặng, nhắc, thực '
      'đơn hôm nay, lượt và chi phí AI → máy B đăng nhập, khôi phục → mọi bảng '
      'khớp máy A', () async {
    final a = device();
    await a.register();
    await setUp5Steps(a, DateTime(2026, 9, 14, 5));
    // T2 14/09 sau 06:00: "Đã tập" (qua S-65).
    a.clock.set(DateTime(2026, 9, 14, 7));
    await a.markDone(LocalDate(2026, 9, 14), confirmed: true);
    // T3 15/09 nghỉ: buổi tập thêm.
    a.clock.set(DateTime(2026, 9, 15, 20));
    await a.addExtra(LocalDate(2026, 9, 15), const [
      MuscleGroup.abs,
    ], confirmed: true);
    // T4 16/09: "Không tập".
    a.clock.set(DateTime(2026, 9, 16, 8));
    await a.markSkipped(LocalDate(2026, 9, 16));
    // Tuần 21/09: cân 78 kg → Bạn tự đặt: đề xuất mức calo mới.
    a.clock.set(DateTime(2026, 9, 21, 7));
    await a.weightEdits.log(LocalDate(2026, 9, 21), 780);
    expect(await a.sync(), SyncOutcome.synced);
    // Thực đơn hôm nay (giờ thật của server) → lượt, chi phí AI.
    await a.menuApi.generate(
      GenerateMenuRequest(
        localDate: LocalDate.fromDateTime(DateTime.now()),
        requestId: const Uuid().v4(),
        targetKcal: 1900,
      ),
    );
    expect(await a.sync(), SyncOutcome.synced);
    final onA = await a.snapshot();

    final b = device();
    final me = await b.login();
    expect(me.onboardingState, OnboardingState.completed);
    final progress = <double>[];
    await b.restore(onProgress: progress.add);
    expect(progress.last, 1);
    expect(await b.snapshot(), onA);

    // Kiểm vài giá trị cụ thể.
    final p = (await b.profiles.get())!;
    expect(
      (p.calorieMode, p.calorieKcal, p.remindersEnabled),
      (CalorieMode.manual, 1900, true),
    );
    expect(p.caloriePendingKcal, isNotNull, reason: 'đề xuất đang chờ');
    final mon = (await b.schedule.day(LocalDate(2026, 9, 14)))!;
    expect(mon.mark, DayMark.done);
    expect(mon.actualMuscles, const [MuscleGroup.chest]);
    expect((await b.schedule.day(LocalDate(2026, 9, 15)))!.extraMuscles, const [
      MuscleGroup.abs,
    ]);
    expect(await b.weights.all(), hasLength(2));
    final menu = await b.menus.get(LocalDate.fromDateTime(DateTime.now()));
    expect(menu?.payload, isNotNull);
    expect(
      onA['aiBudget'],
      isNotNull,
      reason: 'F09-AC3: chi phí AI giữ nguyên',
    );
  });

  test('05 §6.6.5: khôi phục bị mất mạng giữa chừng → lần sau tiếp tục từ '
      'cursor đã nhận, kết quả đủ', () async {
    final a = device();
    await a.register();
    await setUp5Steps(a, DateTime(2026, 9, 14, 5));
    expect(await a.sync(), SyncOutcome.synced);

    late _SlowFlakyApi api;
    final b = device(
      wrap: (inner) => api = _SlowFlakyApi(inner, limit: 5, failAt: 3),
    );
    await b.login();
    await expectLater(b.restore(), throwsA(isA<NetworkFailure>()));
    final cursorAtFailure = api.pulls.last;
    expect(cursorAtFailure, greaterThan(0));
    await b.restore();
    expect(api.pulls[3], cursorAtFailure, reason: 'không pull lại từ 0');
    expect(await b.snapshot(), await a.snapshot());
  });

  test('05 §6.6.6: đăng nhập tài khoản khác trên máy đã có dữ liệu → xóa dữ '
      'liệu cũ rồi khôi phục: chỉ còn dữ liệu của tài khoản mới', () async {
    final a = device();
    await a.register();
    await setUp5Steps(a, DateTime(2026, 9, 14, 5));
    expect(await a.sync(), SyncOutcome.synced);
    final c = device();
    await c.register(phone: '0987654321', name: 'Lan');
    await setUp5Steps(c, DateTime(2026, 9, 21, 5));
    expect(await c.sync(), SyncOutcome.synced);

    final b = device();
    await b.login();
    await b.restore();
    expect(await b.snapshot(), await a.snapshot());
    await b.login(phone: '0987654321');
    await b.db.wipe();
    await b.restore();
    expect(await b.snapshot(), await c.snapshot());
    expect(await b.weights.all(), [(week: LocalDate(2026, 9, 21), kgX10: 800)]);
  });

  test(
    'TA-10: phiên hết hạn → dữ liệu và thay đổi chưa gửi được giữ; đăng nhập '
    'lại cùng tài khoản → gửi tiếp, server nhận',
    () async {
      final a = device();
      await a.register();
      await setUp5Steps(a, DateTime(2026, 9, 14, 5));
      expect(await a.sync(), SyncOutcome.synced);
      a.clock.set(DateTime(2026, 9, 21, 7));
      await a.weightEdits.log(LocalDate(2026, 9, 21), 790);
      // Server thu hồi phiên; access token trên máy cũng hết hạn.
      await server.tdb.pool.execute('DELETE FROM refresh_tokens');
      a.tokens.setPair(
        TokenPair(
          accessToken: 'expired',
          refreshToken: (await a.store.read())!.refreshToken!,
          accessTokenExpiresAt: DateTime.utc(2020),
        ),
      );
      expect(await a.sync(), SyncOutcome.sessionExpired);
      // Số cân và đề xuất mức calo (Bạn tự đặt) chờ gửi, vẫn còn.
      expect(await a.db.select(a.db.outbox).get(), hasLength(2));

      await a.login();
      expect(await a.sync(), SyncOutcome.synced);
      expect(await a.db.select(a.db.outbox).get(), isEmpty);
      final rows = await server.tdb.pool.execute(
        Sql.named(
          "SELECT weight_kg_x10 FROM weights WHERE week_start = '2026-09-21'",
        ),
      );
      expect(rows.single[0], 790);
    },
  );

  test('VS14-T06: khôi phục dữ liệu 1 năm (≈ 310 ngày, 52 số cân) trên mạng di '
      'động mô phỏng (300 ms mỗi lần gọi) dưới 10 giây', () async {
    final a = device();
    await a.register();
    final start = DateTime(2025, 10, 6, 5);
    await setUp5Steps(a, start);
    // Lịch các tháng sau (F03-R6) và một số cân mỗi tuần.
    var day = LocalDate.fromDateTime(start);
    final end = day.addDays(364);
    while (!day.isAfter(end)) {
      a.clock.set(day.atTime(LocalTime(4, 0)));
      if (day.day == 1) await a.materializer.run();
      if (day.weekday == DateTime.monday &&
          day != LocalDate.fromDateTime(start)) {
        await a.weightEdits.log(
          day,
          800 - LocalDate.fromDateTime(start).daysUntil(day) ~/ 30,
        );
      }
      day = day.addDays(1);
    }
    expect(await a.sync(), SyncOutcome.synced);
    final days = (await a.db.select(a.db.days).get()).length;
    expect(days, greaterThan(300));
    // Cân lúc thiết lập + 52 tuần sau.
    expect((await a.weights.all()).length, 53);

    final b = device(
      wrap: (inner) =>
          _SlowFlakyApi(inner, latency: const Duration(milliseconds: 300)),
    );
    await b.login();
    final watch = Stopwatch()..start();
    await b.restore();
    watch.stop();
    expect(watch.elapsed, lessThan(const Duration(seconds: 10)));
    expect(await b.snapshot(), await a.snapshot());
    // ignore: avoid_print
    print('Khôi phục ${days + 52} bản ghi: ${watch.elapsedMilliseconds} ms');
  });
}
