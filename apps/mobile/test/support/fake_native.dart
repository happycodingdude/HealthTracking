import 'dart:async';
import 'dart:convert';

import 'package:domain/domain.dart';
import 'package:mobile/features/native/gym_region_bridge.dart';
import 'package:mobile/features/native/native_bridge.dart';

/// Cầu Swift giả (06 Bản 3 VS39-T02, VS41-T02): ghi lại nội dung widget, các
/// lần gọi và thẻ màn hình khóa đang có.
final class FakeNativeBridge implements NativeBridge {
  final calls = <String>[];
  final written = <Map<String, Object?>>[];
  bool appGroup = true;

  /// Thẻ đang hiện: id → (ngày, token cập nhật, nội dung gần nhất).
  final activities =
      <
        String,
        ({LocalDate date, String? token, Map<String, Object?>? content})
      >{};
  String? startToken;
  final _events = StreamController<LiveActivityEvent>.broadcast();

  /// Nội dung widget ghi gần nhất (null: chưa ghi hoặc đã xóa App Group).
  Map<String, Object?>? get current =>
      appGroup && written.isNotEmpty ? written.last : null;

  /// Server bật thẻ bằng push (giả lập iOS).
  void startActivity(String id, LocalDate date, {String? token}) =>
      activities[id] = (date: date, token: token, content: null);

  /// iOS báo token.
  void emit(LiveActivityEvent e) => _events.add(e);

  @override
  Future<void> writeWidgetState(String json) async {
    calls.add('writeWidgetState');
    appGroup = true;
    written.add(jsonDecode(json) as Map<String, Object?>);
  }

  @override
  Future<void> reloadWidgets() async => calls.add('reloadWidgets');

  @override
  Future<void> appGroupClear() async {
    calls.add('appGroupClear');
    appGroup = false;
  }

  @override
  Future<List<NativeLiveActivity>> liveActivities() async => [
    for (final MapEntry(key: id, value: a) in activities.entries)
      (id: id, date: a.date, updateToken: a.token),
  ];

  @override
  Future<String?> pushToStartToken() async => startToken;

  @override
  Future<void> updateLiveActivity(String id, String contentJson) async {
    calls.add('liveActivity.update');
    final a = activities[id];
    if (a == null) return;
    activities[id] = (
      date: a.date,
      token: a.token,
      content: jsonDecode(contentJson) as Map<String, Object?>,
    );
  }

  @override
  Future<void> endLiveActivity(String id) async {
    calls.add('liveActivity.end');
    activities.remove(id);
  }

  @override
  Future<void> endAllLiveActivities() async {
    calls.add('liveActivity.endAll');
    activities.clear();
  }

  @override
  Stream<LiveActivityEvent> get liveActivityEvents => _events.stream;
}

/// `GymRegionMonitor` Swift giả (06 Bản 5 VS58-T06): vị trí trả về khi "Lưu vị
/// trí này", vùng đang theo dõi, hàng chờ vào vùng, quyền.
final class FakeGymRegionBridge implements GymRegionBridge {
  /// Vị trí iOS trả (null: không lấy được — F32-R3).
  GymFix? fix = (lat: 10.7701234, lng: 106.6904567);
  LocationAccess access = LocationAccess.always;
  final calls = <String>[];

  /// Vùng đang theo dõi (null: không theo dõi).
  ({double lat, double lng})? region;
  final queue = <GymArrivalEvent>[];
  int settingsOpened = 0;
  final _arrivals = StreamController<void>.broadcast();

  /// Đặt để "Lưu vị trí này" chờ (S-77 đang lấy vị trí).
  Completer<GymFix?>? hold;

  /// iOS báo vào vùng (xếp hàng rồi gửi `gymArrival`).
  void enter(LocalDate date, LocalTime time) {
    queue.add((date: date, localTime: time));
    _arrivals.add(null);
  }

  @override
  Future<GymFix?> requestLocation() async {
    calls.add('requestLocation');
    return hold == null ? fix : hold!.future;
  }

  @override
  Future<void> start(double lat, double lng) async {
    calls.add('start');
    region = (lat: lat, lng: lng);
  }

  @override
  Future<void> stop() async {
    calls.add('stop');
    region = null;
    queue.clear();
  }

  @override
  Future<LocationAccess> authorizationStatus() async => access;

  @override
  Future<void> openSettings() async => settingsOpened++;

  @override
  Future<List<GymArrivalEvent>> takeArrivals() async {
    final taken = [...queue];
    queue.clear();
    return taken;
  }

  /// Số lần Dart báo xử lý xong hàng chờ (`gym.arrivalHandled`).
  int handled = 0;

  @override
  Future<void> arrivalHandled() async => handled++;

  @override
  Stream<void> get arrivals => _arrivals.stream;
}
