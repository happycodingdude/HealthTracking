import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Cầu Flutter ↔ Swift (05 Bản 3 TD3-02, 06 Bản 3 ED3-06): một MethodChannel
/// tự viết, `NativeBridge.swift` ở phía iOS. `liveActivity.*` thêm ở VS-41.
abstract interface class NativeBridge {
  /// Ghi `widget_state.json` vào App Group (05 Bản 3 §6.8.1).
  Future<void> writeWidgetState(String json);

  /// `WidgetCenter.reloadAllTimelines()`.
  Future<void> reloadWidgets();

  /// Xóa mọi file của app trong App Group (đăng xuất, TD3-17).
  Future<void> appGroupClear();
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
}

final nativeBridgeProvider = Provider<NativeBridge>(
  (ref) => const ChannelNativeBridge(),
);
