import 'dart:convert';

import 'package:mobile/features/native/native_bridge.dart';

/// Cầu Swift giả (06 Bản 3 VS39-T02): ghi lại nội dung widget và các lần gọi.
final class FakeNativeBridge implements NativeBridge {
  final calls = <String>[];
  final written = <Map<String, Object?>>[];
  bool appGroup = true;

  /// Nội dung widget ghi gần nhất (null: chưa ghi hoặc đã xóa App Group).
  Map<String, Object?>? get current =>
      appGroup && written.isNotEmpty ? written.last : null;

  @override
  Future<void> writeWidgetState(String json) async {
    calls.add('writeWidgetState');
    appGroup = true;
    written.add(jsonDecode(json) as Map<String, Object?>);
  }

  @override
  Future<void> reloadWidgets() async => calls.add('reloadWidgets');

  @override
  Future<void> appGroupClear() async {
    calls.add('appGroupClear');
    appGroup = false;
  }
}
