// Driver cho `flutter drive` (06 Bản 4 ED4-04, tool/capture_screens.sh): lưu
// ảnh chụp từ `binding.takeScreenshot(name)` vào build/review/<name>.png.
import 'dart:io';

import 'package:integration_test/integration_test_driver_extended.dart';

Future<void> main() => integrationDriver(
  onScreenshot: (name, bytes, [args]) async {
    final file = File('build/review/$name.png');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes);
    return true;
  },
);
