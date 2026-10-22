import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// File của app trên máy cần xóa khi đăng xuất (05 Bản 3 TD3-17). Mỗi hàm
/// gọi lại được khi file đã không còn.
abstract interface class DeviceFiles {
  /// File SQLite của Drift (đã đóng database trước đó), kể cả `-wal`, `-shm`.
  Future<void> deleteDatabase();

  /// Thư mục hình món ăn đã tải (05 Bản 2 §6.4.8).
  Future<void> deleteDishImages();
}

final class AppDeviceFiles implements DeviceFiles {
  const AppDeviceFiles({this.databaseName = 'ironly'});

  /// Tên đã dùng ở `openAppDatabase` (drift_flutter lưu
  /// `{Documents}/{tên}.sqlite`).
  final String databaseName;

  @override
  Future<void> deleteDatabase() async {
    final dir = await getApplicationDocumentsDirectory();
    for (final suffix in ['', '-wal', '-shm', '-journal']) {
      final file = File('${dir.path}/$databaseName.sqlite$suffix');
      if (file.existsSync()) await file.delete();
    }
  }

  @override
  Future<void> deleteDishImages() async {
    final dir = Directory(
      '${(await getApplicationSupportDirectory()).path}/dish_images',
    );
    if (dir.existsSync()) await dir.delete(recursive: true);
  }
}
