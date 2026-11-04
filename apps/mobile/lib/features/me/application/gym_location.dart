import 'package:api_contract/api_contract.dart';
import 'package:domain/domain.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../data/db/app_database.dart';
import '../../../data/sync/outbox_writer.dart';
import '../../../data/sync/sync_providers.dart';
import '../../native/gym_region_bridge.dart';
import '../../schedule/data/schedule_pause_repository.dart';
import '../../schedule/data/schedule_repository.dart';
import '../data/gym_location_repository.dart';

/// Kết quả "Lưu vị trí này" (F32-R3).
enum GymSaveResult { saved, noFix }

/// Vị trí phòng gym (03 Bản 5 F-32; 05 Bản 5 §6.4.2 `SaveGymLocation`,
/// `ToggleGymLocation`, `DeleteGymLocation`): bản ghi + outbox `gym_location`
/// trong một transaction, rồi theo dõi / ngừng theo dõi vùng 150 m.
final class GymLocationEdits {
  GymLocationEdits({
    required AppDatabase db,
    required GymLocationRepository repo,
    required OutboxWriter outbox,
    required GymRegionBridge bridge,
    required Clock clock,
  }) : _db = db,
       _repo = repo,
       _outbox = outbox,
       _bridge = bridge,
       _clock = clock;

  final AppDatabase _db;
  final GymLocationRepository _repo;
  final OutboxWriter _outbox;
  final GymRegionBridge _bridge;
  final Clock _clock;

  static const _codec = GymLocationCodec();

  Future<void> _put(GymLocation g) => _db.transaction(() async {
    await _repo.put(g);
    await _outbox.enqueue(
      SyncEntities.gymLocation,
      GymLocation.key,
      SyncOp.upsert,
      _codec.encode(g),
    );
  });

  /// "Lưu vị trí này" / "Lưu lại vị trí này": vị trí hiện tại (xin quyền nếu
  /// cần), ghi đè, công tắc bật (F32-R1, R2; §6.4.2 `enabled = true`).
  Future<GymSaveResult> save() async {
    final fix = await _bridge.requestLocation();
    if (fix == null ||
        !GymLocation.validLat(fix.lat) ||
        !GymLocation.validLng(fix.lng)) {
      return GymSaveResult.noFix;
    }
    final g = GymLocation(lat: fix.lat, lng: fix.lng, savedAt: _clock.now());
    await _put(g);
    await _bridge.start(g.lat, g.lng);
    return GymSaveResult.saved;
  }

  /// Công tắc "Hiện thẻ khi tới phòng gym" (F32-R4): giữ vị trí, bật lại dùng
  /// tiếp.
  Future<void> setEnabled(bool on) async {
    final g = await _repo.get();
    if (g == null) return;
    await _put(g.withEnabled(on));
    on ? await _bridge.start(g.lat, g.lng) : await _bridge.stop();
  }

  /// "Xóa vị trí" (F32-R8): về chưa lưu, thẻ chỉ theo giờ.
  Future<void> delete() async {
    await _db.transaction(() async {
      await _repo.delete();
      await _outbox.enqueue(
        SyncEntities.gymLocation,
        GymLocation.key,
        SyncOp.delete,
        null,
      );
    });
    await _bridge.stop();
  }
}

/// Vùng iOS đang theo dõi đi theo bản ghi trên máy (05 Bản 5 §6.4.6): mở app,
/// đăng nhập / khôi phục, đồng bộ về từ máy khác (F32-AC6) → bật thì theo dõi,
/// không có hoặc tắt thì ngừng. Chỉ gọi iOS khi bản ghi đổi.
final class GymRegionSync {
  GymRegionSync(this._bridge);

  final GymRegionBridge _bridge;
  ({double lat, double lng})? _applied;
  bool _initialized = false;

  Future<void> apply(GymLocation? g) async {
    final want = g != null && g.enabled ? (lat: g.lat, lng: g.lng) : null;
    if (_initialized && want == _applied) return;
    _initialized = true;
    _applied = want;
    if (want == null) {
      await _bridge.stop();
    } else {
      await _bridge.start(want.lat, want.lng);
    }
  }
}

/// Báo server "tới phòng gym hôm nay" (`POST /v1/me/gym-arrival`, 05 Bản 5
/// TD5-14): chỉ ngày và giờ máy, không tọa độ (AP-18, TR5-04). Lỗi (mất
/// mạng, phiên hết hạn) ném ra để [GymArrivalUseCase] bỏ qua (F25-R66).
typedef GymArrivalReporter =
    Future<void> Function(LocalDate date, LocalTime localTime);

/// iOS báo "vào vùng phòng gym" (05 Bản 5 §6.4.2 `GymArrival`, §6.4.6; 06
/// Bản 5 VS58-T04, VS59-T03):
/// - ngày có buổi theo lịch, chưa đánh dấu, trước giờ tập → mở buổi từ lúc
///   vào vùng (`openedAt` + outbox `day`, FD5-01 = A, TD5-07): ghi tạ, "Đã
///   tập" được ngay, kể cả không mạng;
/// - một lần mỗi ngày, không tạm dừng, chưa đánh dấu / chưa có buổi thêm →
///   báo server ([GymArrivalReporter]) để server bật thẻ (TD5-02); lỗi mạng bỏ
///   qua (F25-R66). Gọi request trước, ghi SQLite sau (≤ 10 giây ở nền, §6.17).
final class GymArrivalUseCase {
  GymArrivalUseCase({
    required AppDatabase db,
    required GymLocationRepository repo,
    required ScheduleRepository schedule,
    required SchedulePauseRepository pauses,
    required OutboxWriter outbox,
    required GymRegionBridge bridge,
    required GymArrivalReporter report,
    required Clock clock,
  }) : _db = db,
       _repo = repo,
       _schedule = schedule,
       _pauses = pauses,
       _outbox = outbox,
       _bridge = bridge,
       _report = report,
       _clock = clock;

  final AppDatabase _db;
  final GymLocationRepository _repo;
  final ScheduleRepository _schedule;
  final SchedulePauseRepository _pauses;
  final OutboxWriter _outbox;
  final GymRegionBridge _bridge;
  final GymArrivalReporter _report;
  final Clock _clock;

  static const _dayCodec = DayCodec();

  /// Xử lý một lần vào vùng; true khi là lần báo của ngày (FC5-10, A5-09).
  Future<bool> call(GymArrivalEvent e) async {
    final location = await _repo.get();
    final today = LocalDate.fromDateTime(_clock.now());
    if (location == null || !location.enabled || e.date != today) return false;
    final day = await _schedule.day(e.date);
    final state = GymArrivalAppState(
      today: today,
      location: location,
      alreadyCalled: await _repo.arrived(e.date),
      paused: PauseRules.isPaused(e.date, await _pauses.all()),
      day: day,
    );
    final call = GymArrivalRules.shouldCall(e.date, state);
    if (call) {
      try {
        await _report(e.date, e.localTime);
      } catch (_) {
        // Không mạng / lỗi server: thẻ có thể không hiện, app không báo.
      }
    }
    final at = e.date.atTime(e.localTime);
    final open =
        GymArrivalRules.opensEarly(day, at) &&
        (day!.openedAt == null || at.isBefore(SessionRules.opensAt(day)));
    if (open || call) {
      await _db.transaction(() async {
        if (open) {
          final opened = day.withOpenedAt(at);
          await _schedule.putDay(opened);
          await _outbox.enqueue(
            SyncEntities.day,
            e.date.toKey(),
            SyncOp.upsert,
            _dayCodec.encode(opened),
          );
        }
        if (call) await _repo.markArrived(e.date);
      });
    }
    // Chỉ ngày, không giờ chính xác, không tọa độ (05 Bản 5 §6.14, AP-18).
    if (call) debugPrint('gymArrival ${e.date.toKey()}');
    return call;
  }

  /// Lấy hàng chờ iOS (kể cả khi app vừa được mở ở nền) và xử lý lần lượt;
  /// xong báo iOS để trả thời gian chạy nền ([GymRegionBridge.arrivalHandled]).
  /// [notify] = false: người gọi tự báo (engine nền đẩy outbox trước, xem
  /// `gymArrivalMain`).
  Future<void> drain({bool notify = true}) async {
    try {
      for (final e in await _bridge.takeArrivals()) {
        await call(e);
      }
    } finally {
      if (notify) await _bridge.arrivalHandled();
    }
  }
}

/// Vị trí đã lưu trên máy (S-50, S-77).
final gymLocationProvider = StreamProvider<GymLocation?>(
  (ref) => ref.watch(gymLocationRepositoryProvider).watch(),
);

/// Quyền vị trí iOS (S-77 "Quyền vị trí"); đọc lại khi mở S-77 và khi app
/// quay lại foreground (§6.4.6).
final locationAccessProvider = FutureProvider<LocationAccess>(
  (ref) => ref.watch(gymRegionBridgeProvider).authorizationStatus(),
);

final gymLocationEditsProvider = Provider<GymLocationEdits>(
  (ref) => GymLocationEdits(
    db: ref.watch(databaseProvider),
    repo: ref.watch(gymLocationRepositoryProvider),
    outbox: ref.watch(outboxWriterProvider),
    bridge: ref.watch(gymRegionBridgeProvider),
    clock: ref.watch(clockProvider),
  ),
);

final gymRegionSyncProvider = Provider<GymRegionSync>(
  (ref) => GymRegionSync(ref.watch(gymRegionBridgeProvider)),
);

/// `POST /v1/me/gym-arrival` qua ApiClient có token (tự làm mới phiên).
final gymArrivalReporterProvider = Provider<GymArrivalReporter>((ref) {
  final api = ref.watch(apiClientProvider);
  final version = ref.watch(appVersionProvider);
  return (date, localTime) => api.postJson('/v1/me/gym-arrival', {
    'date': date.toKey(),
    'localTime': localTime.toKey(),
    'appVersion': '$version',
  });
});

final gymArrivalUseCaseProvider = Provider<GymArrivalUseCase>(
  (ref) => GymArrivalUseCase(
    db: ref.watch(databaseProvider),
    repo: ref.watch(gymLocationRepositoryProvider),
    schedule: ref.watch(scheduleRepositoryProvider),
    pauses: ref.watch(schedulePauseRepositoryProvider),
    outbox: ref.watch(outboxWriterProvider),
    bridge: ref.watch(gymRegionBridgeProvider),
    report: ref.watch(gymArrivalReporterProvider),
    clock: ref.watch(clockProvider),
  ),
);
