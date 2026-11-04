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

/// iOS báo "vào vùng phòng gym" (05 Bản 5 §6.4.2 `GymArrival`; 06 Bản 5
/// VS58-T04 phần trên máy): một lần mỗi ngày ghi `gym_arrivals(date)` và log
/// "gymArrival". Mở cửa sổ sớm (`opened_at`) và báo server làm ở VS-59.
final class GymArrivalUseCase {
  GymArrivalUseCase({
    required GymLocationRepository repo,
    required ScheduleRepository schedule,
    required SchedulePauseRepository pauses,
    required GymRegionBridge bridge,
    required Clock clock,
  }) : _repo = repo,
       _schedule = schedule,
       _pauses = pauses,
       _bridge = bridge,
       _clock = clock;

  final GymLocationRepository _repo;
  final ScheduleRepository _schedule;
  final SchedulePauseRepository _pauses;
  final GymRegionBridge _bridge;
  final Clock _clock;

  /// Xử lý một lần vào vùng; true khi là lần báo của ngày (FC5-10, A5-09).
  Future<bool> call(GymArrivalEvent e) async {
    final state = GymArrivalAppState(
      today: LocalDate.fromDateTime(_clock.now()),
      location: await _repo.get(),
      alreadyCalled: await _repo.arrived(e.date),
      paused: PauseRules.isPaused(e.date, await _pauses.all()),
      day: await _schedule.day(e.date),
    );
    if (!GymArrivalRules.shouldCall(e.date, state)) return false;
    await _repo.markArrived(e.date);
    // Chỉ ngày, không giờ chính xác, không tọa độ (05 Bản 5 §6.14, AP-18).
    debugPrint('gymArrival ${e.date.toKey()}');
    return true;
  }

  /// Lấy hàng chờ iOS (kể cả khi app vừa được mở ở nền) và xử lý lần lượt.
  Future<void> drain() async {
    for (final e in await _bridge.takeArrivals()) {
      await call(e);
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

final gymArrivalUseCaseProvider = Provider<GymArrivalUseCase>(
  (ref) => GymArrivalUseCase(
    repo: ref.watch(gymLocationRepositoryProvider),
    schedule: ref.watch(scheduleRepositoryProvider),
    pauses: ref.watch(schedulePauseRepositoryProvider),
    bridge: ref.watch(gymRegionBridgeProvider),
    clock: ref.watch(clockProvider),
  ),
);
