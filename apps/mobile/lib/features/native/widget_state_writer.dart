import 'dart:convert';

import 'package:domain/domain.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/error_reporting.dart';
import '../../data/sync/sync_providers.dart';
import '../auth/application/auth_controller.dart';
import '../schedule/application/schedule_providers.dart';
import '../today/application/today_view.dart';
import 'native_bridge.dart';

/// Bản ghi ngày cho widget: thứ 2 của tuần chứa hôm nay → hôm nay + 7.
final widgetDaysProvider = StreamProvider.family<List<PlanDay>, LocalDate>((
  ref,
  today,
) {
  final (from, to) = WidgetState.range(today);
  return ref.watch(scheduleRepositoryProvider).watchRange(from, to);
});

/// Nội dung widget hiện tại (05 Bản 3 §6.8.1). Tự tính lại khi đăng nhập /
/// đăng xuất / phiên hết hạn, lịch tuần, lịch tháng, bản ghi ngày (đánh dấu,
/// buổi tập thêm, sửa riêng, dữ liệu pull về) hoặc sang ngày mới đổi (F24-R5,
/// TD3-15). null khi dữ liệu chưa đọc xong hoặc đang khôi phục (S-07).
final widgetStateProvider = Provider<WidgetState?>((ref) {
  final auth = ref.watch(authControllerProvider);
  final now = ref.read(clockProvider).now();
  if (auth.status != AuthStatus.signedIn) return WidgetState.signedOut(now);
  if (auth.restoring) return null;
  final template = ref.watch(weeklyTemplateProvider);
  final plans = ref.watch(monthPlansProvider);
  final days = ref.watch(widgetDaysProvider(ref.watch(todayProvider)));
  if (!template.hasValue || !plans.hasValue || !days.hasValue) return null;
  return WidgetState.of(
    now: now,
    days: days.requireValue,
    planned: {for (final p in plans.requireValue) p.month},
    template: template.value,
  );
});

/// Ghi `widget_state.json` vào App Group rồi `reloadAllTimelines` (TD3-15).
/// Nội dung không đổi thì không ghi lại, trừ khi [write] với `force` (mở app,
/// quay lại foreground: F24-R5).
final class WidgetStateWriter {
  WidgetStateWriter(this._bridge, this._reporter);

  final NativeBridge _bridge;
  final ErrorReporter _reporter;
  String? _last;

  Future<void> write(WidgetState state, {bool force = false}) async {
    final json = state.toJson();
    final content = jsonEncode({...json, 'generatedAt': null});
    if (!force && content == _last) return;
    _last = content;
    try {
      await _bridge.writeWidgetState(jsonEncode(json));
      await _bridge.reloadWidgets();
    } on Object catch (e, st) {
      _last = null;
      await _reporter.report(e, st, reason: 'widget_state_write');
    }
  }
}

final widgetStateWriterProvider = Provider<WidgetStateWriter>(
  (ref) => WidgetStateWriter(
    ref.watch(nativeBridgeProvider),
    ref.watch(errorReporterProvider),
  ),
);
