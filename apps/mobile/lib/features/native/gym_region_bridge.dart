import 'dart:async';

import 'package:domain/domain.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

/// Quyền vị trí iOS đang cấp cho app (S-77 dòng "Quyền vị trí", F32-R5).
enum LocationAccess { always, whenInUse, denied, notDetermined }

/// Một điểm lấy lúc "Lưu vị trí này" (F32-R2). Chỉ để lưu, không hiện (F32-AC5).
typedef GymFix = ({double lat, double lng});

/// Một lần vào vùng phòng gym: ngày và giờ trên máy, không tọa độ (AP-18).
typedef GymArrivalEvent = ({LocalDate date, LocalTime localTime});

/// Bán kính vùng phòng gym (05 Bản 5 TA5-01; OQ5-22).
const gymRegionRadiusMeters = 150.0;

/// Cầu Dart ↔ `GymRegionMonitor` Swift (05 Bản 5 TD5-01, §6.4.6; 06 Bản 5
/// VS58-T04): cùng channel `dev.antonnguyen.ironly/native`, method `gym.*`;
/// iOS báo vào vùng bằng `gymArrival`, Dart lấy hàng chờ bằng [takeArrivals].
abstract interface class GymRegionBridge {
  /// Xin quyền nếu cần (hai bước, FC5-11) rồi lấy vị trí hiện tại ≤ 50 m trong
  /// 15 giây; null = không lấy được (F32-R3).
  Future<GymFix?> requestLocation();

  /// Theo dõi vùng tròn 150 m quanh điểm đã lưu (thay vùng cũ).
  Future<void> start(double lat, double lng);

  /// Ngừng theo dõi và bỏ hàng chờ.
  Future<void> stop();

  Future<LocationAccess> authorizationStatus();

  /// Mở trang Cài đặt của app ("Mở Cài đặt", dòng "Quyền vị trí").
  Future<void> openSettings();

  /// Lấy và xóa các lần vào vùng iOS đã xếp hàng.
  Future<List<GymArrivalEvent>> takeArrivals();

  /// Đã xử lý xong hàng chờ: iOS trả thời gian chạy nền, tắt engine nền nếu
  /// app được mở ở nền vì sự kiện vùng (05 Bản 5 §6.4.6, VS59-T03).
  Future<void> arrivalHandled();

  /// Có lần vào vùng mới (nghe rồi gọi [takeArrivals]).
  Stream<void> get arrivals;
}

final class ChannelGymRegionBridge implements GymRegionBridge {
  ChannelGymRegionBridge([
    this._channel = const MethodChannel('dev.antonnguyen.ironly/native'),
  ]);

  final MethodChannel _channel;
  final _arrivals = StreamController<void>.broadcast();
  bool _listening = false;

  /// Không có cầu iOS (test widget, máy không phải iPhone): coi như không có
  /// gì, không lỗi.
  Future<T?> _call<T>(String method, [Object? args]) async {
    try {
      return await _channel.invokeMethod<T>(method, args);
    } on MissingPluginException {
      return null;
    }
  }

  @override
  Future<GymFix?> requestLocation() async {
    final r = await _call<Map<Object?, Object?>>('gym.requestLocation');
    return switch ((r?['lat'], r?['lng'])) {
      (final num lat, final num lng) => (
        lat: lat.toDouble(),
        lng: lng.toDouble(),
      ),
      _ => null,
    };
  }

  @override
  Future<void> start(double lat, double lng) => _call<void>('gym.start', {
    'lat': lat,
    'lng': lng,
    'radius': gymRegionRadiusMeters,
  });

  @override
  Future<void> stop() => _call<void>('gym.stop');

  @override
  Future<LocationAccess> authorizationStatus() async =>
      switch (await _call<String>('gym.authorizationStatus')) {
        'always' => LocationAccess.always,
        'whenInUse' => LocationAccess.whenInUse,
        'denied' => LocationAccess.denied,
        _ => LocationAccess.notDetermined,
      };

  @override
  Future<void> openSettings() async {
    await launchUrl(Uri.parse('app-settings:'));
  }

  @override
  Future<List<GymArrivalEvent>> takeArrivals() async => [
    for (final a
        in await _call<List<Object?>>('gym.takeArrivals') ?? const <Object?>[])
      if (a is Map &&
          LocalDate.tryParse('${a['date']}') != null &&
          LocalTime.tryParse('${a['localTime']}') != null)
        (
          date: LocalDate.tryParse('${a['date']}')!,
          localTime: LocalTime.tryParse('${a['localTime']}')!,
        ),
  ];

  @override
  Future<void> arrivalHandled() => _call<void>('gym.arrivalHandled');

  /// Nhận `gymArrival` từ iOS: chỉ bản đang được nghe (gốc app) đặt handler,
  /// bản dùng một lần lúc đăng xuất thì không.
  @override
  Stream<void> get arrivals {
    if (!_listening) {
      _listening = true;
      _channel.setMethodCallHandler((call) async {
        if (call.method == 'gymArrival') _arrivals.add(null);
      });
    }
    return _arrivals.stream;
  }

  Future<void> dispose() => _arrivals.close();
}

final gymRegionBridgeProvider = Provider<GymRegionBridge>((ref) {
  final bridge = ChannelGymRegionBridge();
  ref.onDispose(bridge.dispose);
  return bridge;
});
