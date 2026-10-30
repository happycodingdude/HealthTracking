import 'dart:io';

import 'package:api_contract/api_contract.dart';

/// Phiên bản app Bản 4 (05 Bản 4 TD4-11), dùng trong test thay `AppVersion.v3`.
final appVersionV4 = AppVersion.parse('4.0.0');

/// `version:` trong pubspec.yaml của app.
AppVersion pubspecVersion() {
  final line = File(
    'pubspec.yaml',
  ).readAsLinesSync().firstWhere((l) => l.startsWith('version:'));
  return AppVersion.parse(line.split(':').last.trim());
}
