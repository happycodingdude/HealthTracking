import 'dart:convert';

import 'package:domain/domain.dart';

import '../account/application/logout.dart';
import 'native_bridge.dart';

/// Bước đăng xuất của widget và App Group (05 Bản 3 TD3-17, F24-R6): xóa App
/// Group, rồi ghi trạng thái "Mở app để đăng nhập" và làm mới widget. Thẻ màn
/// hình khóa thêm ở VS-41.
final class NativeLogoutHooks implements LogoutDeviceHooks {
  const NativeLogoutHooks(this._bridge, this._clock);

  final NativeBridge _bridge;
  final Clock _clock;

  @override
  Future<void> deleteActivityToken() async {}

  @override
  Future<void> clearAppGroup() => _bridge.appGroupClear();

  @override
  Future<void> endActivities() async {}

  @override
  Future<void> reloadWidgets() async {
    await _bridge.writeWidgetState(
      jsonEncode(WidgetState.signedOut(_clock.now()).toJson()),
    );
    await _bridge.reloadWidgets();
  }
}
