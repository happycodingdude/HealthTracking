import 'dart:async';
import 'dart:convert';

import 'package:api_contract/api_contract.dart';
import 'package:domain/domain.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../app/providers.dart';
import '../../core/error_reporting.dart';
import '../../data/api/api_client.dart';
import '../../data/sync/sync_providers.dart';
import '../auth/application/auth_controller.dart';
import '../library/data/exercise_repository.dart';
import '../schedule/data/schedule_repository.dart';
import '../today/application/mark_session.dart';
import '../workout/application/lift_log_edits.dart';
import '../workout/data/exercise_unit_repository.dart';
import '../workout/data/lift_log_repository.dart';
import 'native_bridge.dart';

/// Token thẻ đã gửi lên server lần gần nhất (TA3-12: chỉ gửi khi đổi hoặc
/// sau 24 giờ).
typedef SentLiveActivityTokens = ({
  String userId,
  String pushToStart,
  String? update,
  LocalDate? date,
  DateTime at,
});

/// Thứ tự lưu mức tạ trong một ngày (bài vừa ghi, F25-R4): máy không lưu thời
/// điểm lưu của bản ghi nên giữ riêng danh sách bài theo thứ tự lưu.
typedef SaveOrder = ({LocalDate date, List<String> exerciseIds});

/// Nơi giữ [SentLiveActivityTokens] và [SaveOrder] trên máy (UserDefaults).
abstract interface class LiveActivityStore {
  Future<SentLiveActivityTokens?> sent();
  Future<void> setSent(SentLiveActivityTokens value);
  Future<SaveOrder?> saveOrder();
  Future<void> setSaveOrder(SaveOrder value);

  /// Đăng xuất: tài khoản sau phải gửi lại token.
  Future<void> clear();
}

final class PrefsLiveActivityStore implements LiveActivityStore {
  PrefsLiveActivityStore([SharedPreferencesAsync? prefs])
    : _prefs = prefs ?? SharedPreferencesAsync();

  final SharedPreferencesAsync _prefs;
  static const _sentKey = 'live_activity_sent';
  static const _orderKey = 'live_activity_save_order';

  Future<Map<String, Object?>?> _json(String key) async {
    final raw = await _prefs.getString(key);
    if (raw == null) return null;
    try {
      return (jsonDecode(raw) as Map).cast<String, Object?>();
    } on Object {
      return null;
    }
  }

  @override
  Future<SentLiveActivityTokens?> sent() async {
    final j = await _json(_sentKey);
    if (j == null) return null;
    return (
      userId: j['userId']! as String,
      pushToStart: j['pushToStart']! as String,
      update: j['update'] as String?,
      date: LocalDate.tryParse('${j['date']}'),
      at: DateTime.parse(j['at']! as String),
    );
  }

  @override
  Future<void> setSent(SentLiveActivityTokens v) => _prefs.setString(
    _sentKey,
    jsonEncode({
      'userId': v.userId,
      'pushToStart': v.pushToStart,
      'update': v.update,
      'date': v.date?.toKey(),
      'at': v.at.toIso8601String(),
    }),
  );

  @override
  Future<SaveOrder?> saveOrder() async {
    final j = await _json(_orderKey);
    final date = LocalDate.tryParse('${j?['date']}');
    if (j == null || date == null) return null;
    return (date: date, exerciseIds: [...(j['ids']! as List).cast<String>()]);
  }

  @override
  Future<void> setSaveOrder(SaveOrder v) => _prefs.setString(
    _orderKey,
    jsonEncode({'date': v.date.toKey(), 'ids': v.exerciseIds}),
  );

  @override
  Future<void> clear() async {
    await _prefs.remove(_sentKey);
    await _prefs.remove(_orderKey);
  }
}

/// Bản trong bộ nhớ (test).
final class MemoryLiveActivityStore implements LiveActivityStore {
  SentLiveActivityTokens? sentTokens;
  SaveOrder? order;

  @override
  Future<SentLiveActivityTokens?> sent() async => sentTokens;

  @override
  Future<void> setSent(SentLiveActivityTokens value) async =>
      sentTokens = value;

  @override
  Future<SaveOrder?> saveOrder() async => order;

  @override
  Future<void> setSaveOrder(SaveOrder value) async => order = value;

  @override
  Future<void> clear() async {
    sentTokens = null;
    order = null;
  }
}

/// `PUT` / `DELETE /v1/me/live-activity-token` (05 Bản 3 §6.12).
final class LiveActivityApi {
  const LiveActivityApi(this._api);

  final ApiClient _api;

  Future<void> put(LiveActivityTokenRequest request) =>
      _api.putJson('/v1/me/live-activity-token', request.toJson());

  /// Server chưa có đường dẫn (404) → bỏ qua; đăng xuất ở server cũng xóa token.
  Future<void> delete() async {
    try {
      await _api.deleteJson('/v1/me/live-activity-token');
    } on ServerFailure catch (e) {
      if (e.status != 404) rethrow;
    }
  }
}

/// Thẻ màn hình khóa phía app (05 Bản 3 §6.4.4, TD3-13, TD3-14): **không bao
/// giờ bật thẻ** (chỉ server bật bằng push); đọc thẻ khi mở app, tắt thẻ ngày
/// cũ, gửi token, cập nhật nội dung tại chỗ sau mỗi lần lưu / sửa / xóa mức tạ
/// hoặc đổi đơn vị, tắt khi "Đã tập" / "Không tập". Lưu chỉ ghi chú: không làm
/// gì (UA3-02). Phiên hết hạn / chưa đăng nhập: không gửi token, không cập nhật.
final class LiveActivityController
    implements LiftChangeHooks, SessionMarkHooks {
  LiveActivityController({
    required NativeBridge bridge,
    required LiveActivityApi api,
    required LiveActivityStore store,
    required Clock clock,
    required ScheduleRepository schedule,
    required ExerciseRepository exercises,
    required LiftLogRepository liftLogs,
    required ExerciseUnitRepository units,
    required String? Function() signedInUser,
    required ApnsEnvironment environment,
    required String appVersion,
    required ErrorReporter reporter,
  }) : _bridge = bridge,
       _api = api,
       _store = store,
       _clock = clock,
       _schedule = schedule,
       _exercises = exercises,
       _liftLogs = liftLogs,
       _units = units,
       _signedInUser = signedInUser,
       _environment = environment,
       _appVersion = appVersion,
       _reporter = reporter;

  final NativeBridge _bridge;
  final LiveActivityApi _api;
  final LiveActivityStore _store;
  final Clock _clock;
  final ScheduleRepository _schedule;
  final ExerciseRepository _exercises;
  final LiftLogRepository _liftLogs;
  final ExerciseUnitRepository _units;
  final String? Function() _signedInUser;
  final ApnsEnvironment _environment;
  final String _appVersion;
  final ErrorReporter _reporter;
  StreamSubscription<LiveActivityEvent>? _events;

  static const resendAfter = Duration(hours: 24);

  LocalDate get _today => LocalDate.fromDateTime(_clock.now());

  /// Nghe token mới từ iOS (TA3-12, TA3-13).
  void start() => _events ??= _bridge.liveActivityEvents.listen(
    (e) => unawaited(_guard('live_activity_event', () => _onEvent(e))),
  );

  Future<void> dispose() async => _events?.cancel();

  /// Mở app, quay lại foreground, qua 00:00: tắt thẻ ngày cũ, gửi token.
  Future<void> refresh() => _guard('live_activity_refresh', () async {
    final today = _today;
    NativeLiveActivity? current;
    for (final a in await _bridge.liveActivities()) {
      if (a.date == today) {
        current = a;
      } else {
        await _bridge.endLiveActivity(a.id);
      }
    }
    await _register(update: current?.updateToken, date: current?.date);
  });

  Future<void> _onEvent(LiveActivityEvent e) async {
    switch (e) {
      case PushToStartTokenEvent(:final token):
        final current = await _current();
        await _register(
          pushToStart: token,
          update: current?.updateToken,
          date: current?.date,
        );
      case ActivityTokenEvent(:final date, :final token):
        if (date == _today) await _register(update: token, date: date);
    }
  }

  Future<NativeLiveActivity?> _current() async {
    final today = _today;
    for (final a in await _bridge.liveActivities()) {
      if (a.date == today) return a;
    }
    return null;
  }

  /// `RegisterLiveActivityTokens` (05 Bản 3 §6.4.1): chỉ khi token đổi hoặc
  /// đã quá 24 giờ kể từ lần gửi trước; lỗi mạng → lần sau gửi lại.
  Future<void> _register({
    String? pushToStart,
    String? update,
    LocalDate? date,
  }) async {
    final user = _signedInUser();
    if (user == null) return;
    final token = pushToStart ?? await _bridge.pushToStartToken();
    if (token == null) return;
    final now = _clock.now();
    final last = await _store.sent();
    if (last != null &&
        last.userId == user &&
        last.pushToStart == token &&
        last.update == update &&
        last.date == date &&
        now.difference(last.at) < resendAfter) {
      return;
    }
    try {
      await _api.put(
        LiveActivityTokenRequest(
          pushToStartToken: token,
          activityPushToken: update,
          activityDate: update == null ? null : date,
          environment: _environment,
          appVersion: _appVersion,
        ),
      );
    } on ApiFailure {
      return;
    }
    await _store.setSent((
      userId: user,
      pushToStart: token,
      update: update,
      date: date,
      at: now,
    ));
  }

  @override
  Future<void> liftChanged(
    LocalDate date,
    String exerciseId, {
    required bool deleted,
  }) => _guard('live_activity_update', () async {
    final order = await _store.saveOrder();
    final ids = [if (order != null && order.date == date) ...order.exerciseIds]
      ..remove(exerciseId);
    if (!deleted) ids.add(exerciseId);
    await _store.setSaveOrder((date: date, exerciseIds: ids));
    if (date == _today) await _update(date);
  });

  @override
  Future<void> unitChanged(String exerciseId) =>
      _guard('live_activity_update', () => _update(_today));

  /// "Đã tập" / "Không tập": tắt ngay thẻ của ngày đó (F25-R3).
  @override
  Future<void> sessionMarked(LocalDate date) =>
      _guard('live_activity_end', () async {
        for (final a in await _bridge.liveActivities()) {
          if (a.date == date) await _bridge.endLiveActivity(a.id);
        }
      });

  Future<void> _update(LocalDate date) async {
    if (_signedInUser() == null) return;
    final activity = await _current();
    if (activity == null || activity.date != date) return;
    final content = await contentOf(date);
    if (content == null) return;
    await _bridge.updateLiveActivity(activity.id, jsonEncode(content.toJson()));
  }

  /// Nội dung thẻ ngày [date] từ dữ liệu trên máy (dùng chung công thức với
  /// server, ED3-03).
  @visibleForTesting
  Future<LiveActivityContent?> contentOf(LocalDate date) async {
    final day = await _schedule.day(date);
    if (day == null || !day.isWorkout) return null;
    final library = await _exercises.watchAll().first;
    final logs = await _liftLogs.watchAll().first;
    final order = await _store.saveOrder();
    final saved = order != null && order.date == date
        ? order.exerciseIds
        : const <String>[];
    final todayLogs = [
      for (final l in logs)
        if (l.date == date) l,
    ];
    final sortOrder = {for (final e in library) e.id: e.sortOrder};
    // Bài lưu trên máy khác (không có trong thứ tự lưu) coi như lưu trước.
    todayLogs.sort((a, b) {
      final ia = saved.indexOf(a.exerciseId);
      final ib = saved.indexOf(b.exerciseId);
      if (ia != ib) return ia.compareTo(ib);
      return (sortOrder[a.exerciseId] ?? 0).compareTo(
        sortOrder[b.exerciseId] ?? 0,
      );
    });
    final previous = <String, LiftLog>{};
    for (final l in logs) {
      if (!l.date.isBefore(date)) continue;
      final p = previous[l.exerciseId];
      if (p == null || l.date.isAfter(p.date)) previous[l.exerciseId] = l;
    }
    return LiveActivityContent.of(
      groups: day.sessionMuscles,
      library: library,
      today: todayLogs,
      previous: previous,
      units: await _units.watchAll().first,
    );
  }

  /// Thẻ không bao giờ làm hỏng thao tác của Bạn: lỗi chỉ báo về Sentry.
  Future<void> _guard(String reason, Future<void> Function() action) async {
    try {
      await action();
    } on Object catch (e, st) {
      await _reporter.report(e, st, reason: reason);
    }
  }
}

final liveActivityStoreProvider = Provider<LiveActivityStore>(
  (ref) => PrefsLiveActivityStore(),
);

final liveActivityApiProvider = Provider<LiveActivityApi>(
  (ref) => LiveActivityApi(ref.watch(apiClientProvider)),
);

final liveActivityControllerProvider = Provider<LiveActivityController>((ref) {
  final env = ref.watch(envProvider);
  final controller = LiveActivityController(
    bridge: ref.watch(nativeBridgeProvider),
    api: ref.watch(liveActivityApiProvider),
    store: ref.watch(liveActivityStoreProvider),
    clock: ref.watch(clockProvider),
    schedule: ref.watch(scheduleRepositoryProvider),
    exercises: ref.watch(exerciseRepositoryProvider),
    liftLogs: ref.watch(liftLogRepositoryProvider),
    units: ref.watch(exerciseUnitRepositoryProvider),
    signedInUser: () {
      final auth = ref.read(authControllerProvider);
      return auth.status == AuthStatus.signedIn ? auth.userId : null;
    },
    // Bản dev và bản chạy từ Xcode dùng APNs sandbox (TA3-14).
    environment: env.flavor == 'prod' && kReleaseMode
        ? ApnsEnvironment.production
        : ApnsEnvironment.sandbox,
    appVersion: ref.watch(appVersionProvider).toString(),
    reporter: ref.watch(errorReporterProvider),
  );
  ref.onDispose(controller.dispose);
  return controller;
});
