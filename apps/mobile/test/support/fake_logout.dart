import 'package:mobile/data/device_files.dart';
import 'package:mobile/features/account/application/logout.dart';

/// File SQLite và thư mục `dish_images` giả (đăng xuất, 05 Bản 3 TD3-17).
final class FakeDeviceFiles implements DeviceFiles {
  bool database = true;
  bool dishImages = true;

  /// Lần gọi tới bị lỗi (một lần).
  bool failNextDatabaseDelete = false;

  @override
  Future<void> deleteDatabase() async {
    if (failNextDatabaseDelete) {
      failNextDatabaseDelete = false;
      throw StateError('file đang bị khóa');
    }
    database = false;
  }

  @override
  Future<void> deleteDishImages() async => dishImages = false;
}

/// Widget, App Group, thẻ màn hình khóa giả: ghi lại các lần gọi.
final class FakeLogoutHooks implements LogoutDeviceHooks {
  bool activityToken = true;
  bool appGroup = true;
  bool activities = true;
  int widgetReloads = 0;

  @override
  Future<void> deleteActivityToken() async => activityToken = false;

  @override
  Future<void> clearAppGroup() async => appGroup = false;

  @override
  Future<void> endActivities() async => activities = false;

  @override
  Future<void> reloadWidgets() async => widgetReloads++;
}
