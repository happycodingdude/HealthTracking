import 'dart:async';
import 'dart:convert';

import 'package:domain/domain.dart';
import 'package:mobile/features/native/native_bridge.dart';

/// Cầu Swift giả (06 Bản 3 VS39-T02, VS41-T02): ghi lại nội dung widget, các
/// lần gọi và thẻ màn hình khóa đang có.
final class FakeNativeBridge implements NativeBridge {
  final calls = <String>[];
  final written = <Map<String, Object?>>[];
  bool appGroup = true;

  /// Thẻ đang hiện: id → (ngày, token cập nhật, nội dung gần nhất).
  final activities =
      <
        String,
        ({LocalDate date, String? token, Map<String, Object?>? content})
      >{};
  String? startToken;
  final _events = StreamController<LiveActivityEvent>.broadcast();

  /// Nội dung widget ghi gần nhất (null: chưa ghi hoặc đã xóa App Group).
  Map<String, Object?>? get current =>
      appGroup && written.isNotEmpty ? written.last : null;

  /// Server bật thẻ bằng push (giả lập iOS).
  void startActivity(String id, LocalDate date, {String? token}) =>
      activities[id] = (date: date, token: token, content: null);

  /// iOS báo token.
  void emit(LiveActivityEvent e) => _events.add(e);

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

  @override
  Future<List<NativeLiveActivity>> liveActivities() async => [
    for (final MapEntry(key: id, value: a) in activities.entries)
      (id: id, date: a.date, updateToken: a.token),
  ];

  @override
  Future<String?> pushToStartToken() async => startToken;

  @override
  Future<void> updateLiveActivity(String id, String contentJson) async {
    calls.add('liveActivity.update');
    final a = activities[id];
    if (a == null) return;
    activities[id] = (
      date: a.date,
      token: a.token,
      content: jsonDecode(contentJson) as Map<String, Object?>,
    );
  }

  @override
  Future<void> endLiveActivity(String id) async {
    calls.add('liveActivity.end');
    activities.remove(id);
  }

  @override
  Future<void> endAllLiveActivities() async {
    calls.add('liveActivity.endAll');
    activities.clear();
  }

  @override
  Stream<LiveActivityEvent> get liveActivityEvents => _events.stream;
}
