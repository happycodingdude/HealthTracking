import 'dart:io';

import 'package:api_contract/api_contract.dart';

/// Phiên bản app Bản 5 (05 Bản 5 TD5-18), dùng trong test.
const appVersionV5 = AppVersion.v5;

/// `version:` trong pubspec.yaml của app.
AppVersion pubspecVersion() {
  final line = File(
    'pubspec.yaml',
  ).readAsLinesSync().firstWhere((l) => l.startsWith('version:'));
  return AppVersion.parse(line.split(':').last.trim());
}
