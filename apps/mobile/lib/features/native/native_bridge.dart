import 'package:domain/domain.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Một thẻ màn hình khóa đang có trên máy (ActivityKit).
typedef NativeLiveActivity = ({String id, LocalDate date, String? updateToken});

/// Sự kiện token của thẻ từ iOS (05 Bản 3 TA3-12, TA3-13).
sealed class LiveActivityEvent {
  const LiveActivityEvent();

  static LiveActivityEvent? fromMap(Object? raw) {
    if (raw is! Map) return null;
    final token = raw['token'];
    if (token is! String) return null;
    return switch (raw['type']) {
      'pushToStartToken' => PushToStartTokenEvent(token),
      'activityToken' => switch ((
        raw['id'],
        LocalDate.tryParse('${raw['date']}'),
      )) {
        (final String id, final LocalDate date) => ActivityTokenEvent(
          id,
          date,
          token,
        ),
        _ => null,
      },
      _ => null,
    };
  }
}

/// iOS cấp push-to-start token mới.
final class PushToStartTokenEvent extends LiveActivityEvent {
  const PushToStartTokenEvent(this.token);

  final String token;
}

/// Thẻ [id] của ngày [date] (do server bật) có token cập nhật [token].
final class ActivityTokenEvent extends LiveActivityEvent {
  const ActivityTokenEvent(this.id, this.date, this.token);

  final String id;
  final LocalDate date;
  final String token;
}

/// Cầu Flutter ↔ Swift (05 Bản 3 TD3-02, 06 Bản 3 ED3-06): một MethodChannel
/// tự viết, `NativeBridge.swift` ở phía iOS. Không có hàm bật thẻ: chỉ server
/// bật thẻ bằng push (TD3-14, ED3-09).
abstract interface class NativeBridge {
  /// Ghi `widget_state.json` vào App Group (05 Bản 3 §6.8.1).
  Future<void> writeWidgetState(String json);

  /// `WidgetCenter.reloadAllTimelines()`.
  Future<void> reloadWidgets();

  /// Xóa mọi file của app trong App Group (đăng xuất, TD3-17).
  Future<void> appGroupClear();

  /// Thẻ đang có (`Activity.activities`).
  Future<List<NativeLiveActivity>> liveActivities();

  /// Push-to-start token hiện tại (null khi iOS chưa cấp).
  Future<String?> pushToStartToken();

  /// Cập nhật nội dung thẻ [id] (`content-state`, 05 Bản 3 TD3-13).
  Future<void> updateLiveActivity(String id, String contentJson);

  /// Tắt ngay thẻ [id] (`dismissalPolicy: .immediate`).
  Future<void> endLiveActivity(String id);

  /// Tắt mọi thẻ (đăng xuất).
  Future<void> endAllLiveActivities();

  /// Token mới từ iOS.
  Stream<LiveActivityEvent> get liveActivityEvents;
}

final class ChannelNativeBridge implements NativeBridge {
  const ChannelNativeBridge([
    this._channel = const MethodChannel('dev.antonnguyen.ironly/native'),
  ]);

  final MethodChannel _channel;

  @override
  Future<void> writeWidgetState(String json) =>
      _channel.invokeMethod<void>('writeWidgetState', json);

  @override
  Future<void> reloadWidgets() => _channel.invokeMethod<void>('reloadWidgets');

  @override
  Future<void> appGroupClear() => _channel.invokeMethod<void>('appGroupClear');

  static const _events = EventChannel('dev.antonnguyen.ironly/native/events');

  @override
  Future<List<NativeLiveActivity>> liveActivities() async => [
    for (final a
        in await _channel.invokeListMethod<Map<Object?, Object?>>(
              'liveActivity.activities',
            ) ??
            const <Map<Object?, Object?>>[])
      if ((a['id'], LocalDate.tryParse('${a['date']}')) case (
        final String id,
        final LocalDate date,
      ))
        (id: id, date: date, updateToken: a['token'] as String?),
  ];

  @override
  Future<String?> pushToStartToken() =>
      _channel.invokeMethod<String>('liveActivity.pushToStartToken');

  @override
  Future<void> updateLiveActivity(String id, String contentJson) =>
      _channel.invokeMethod<void>('liveActivity.update', {
        'id': id,
        'content': contentJson,
      });

  @override
  Future<void> endLiveActivity(String id) =>
      _channel.invokeMethod<void>('liveActivity.end', {'id': id});

  @override
  Future<void> endAllLiveActivities() =>
      _channel.invokeMethod<void>('liveActivity.endAll');

  @override
  Stream<LiveActivityEvent> get liveActivityEvents => _events
      .receiveBroadcastStream()
      .map(LiveActivityEvent.fromMap)
      .where((e) => e != null)
      .cast<LiveActivityEvent>();
}

final nativeBridgeProvider = Provider<NativeBridge>(
  (ref) => const ChannelNativeBridge(),
);
