import 'dart:convert';

import 'package:domain/domain.dart';

import '../account/application/logout.dart';
import 'gym_region_bridge.dart';
import 'live_activity_controller.dart';
import 'native_bridge.dart';

/// Bước đăng xuất của widget, App Group và thẻ màn hình khóa (05 Bản 3
/// TD3-17, §6.4.4, F24-R6, F25-E7): xóa token thẻ trên server, xóa App Group,
/// tắt mọi thẻ, ghi trạng thái "Mở app để đăng nhập" và làm mới widget. Bản 5:
/// ngừng theo dõi vùng phòng gym (05 Bản 5 §6.4.2 `Logout`, F32-E3).
final class NativeLogoutHooks implements LogoutDeviceHooks {
  const NativeLogoutHooks(
    this._bridge,
    this._clock, {
    required LiveActivityStore store,
    Future<void> Function()? deleteToken,
    GymRegionBridge? gym,
  }) : _store = store,
       _deleteToken = deleteToken,
       _gym = gym;

  final NativeBridge _bridge;
  final Clock _clock;
  final LiveActivityStore _store;

  /// `DELETE /v1/me/live-activity-token`; null khi chạy ở gốc app (bước xóa
  /// dữ liệu không gọi mạng).
  final Future<void> Function()? _deleteToken;

  /// Vùng phòng gym iOS đang theo dõi (null: chưa có, ví dụ test cũ).
  final GymRegionBridge? _gym;

  @override
  Future<void> deleteActivityToken() async => _deleteToken?.call();

  @override
  Future<void> clearAppGroup() => _bridge.appGroupClear();

  /// Tắt mọi thẻ; tài khoản đăng nhập sau phải gửi lại token. Ngừng theo dõi
  /// vùng phòng gym và bỏ hàng chờ vào vùng (F32-E3; `gym_arrivals` đi cùng
  /// file SQLite).
  @override
  Future<void> endActivities() async {
    await _bridge.endAllLiveActivities();
    await _store.clear();
    await _gym?.stop();
  }

  @override
  Future<void> reloadWidgets() async {
    await _bridge.writeWidgetState(
      jsonEncode(WidgetState.signedOut(_clock.now()).toJson()),
    );
    await _bridge.reloadWidgets();
  }
}
