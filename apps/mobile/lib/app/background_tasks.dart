import 'dart:async';

import 'package:domain/domain.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/sync/sync_providers.dart';
import '../data/sync/sync_scheduler.dart';
import '../features/auth/application/auth_controller.dart';
import '../features/me/application/calorie_updates.dart';
import '../features/me/application/reminders.dart';
import '../features/native/live_activity_controller.dart';
import '../features/native/widget_state_writer.dart';
import '../features/schedule/application/month_materializer.dart';
import 'providers.dart';
import 'router.dart';
import 'time_ticker.dart';

/// Chạy các thành phần nền của app (05 §6.4.4) khi khởi động, khi quay lại
/// foreground và khi qua 00:00 lúc app đang mở: [MonthMaterializer] (F03-R6),
/// kiểm tra sang năm mới cho mức calo (F01-E2), rồi [ReminderScheduler]
/// (TR-10). Chạm vào nhắc → Hôm nay (NAV-2). Bản 3: ghi nội dung widget mỗi
/// khi đổi và mỗi lần mở app / quay lại foreground (F24-R5, TD3-15); thẻ màn
/// hình khóa: tắt thẻ ngày cũ, gửi token (05 Bản 3 §6.4.4).
class BackgroundTasks extends ConsumerStatefulWidget {
  const BackgroundTasks({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<BackgroundTasks> createState() => _BackgroundTasksState();
}

class _BackgroundTasksState extends ConsumerState<BackgroundTasks> {
  late final AppLifecycleListener _lifecycle;
  CancelSchedule? _midnight;

  @override
  void initState() {
    super.initState();
    ref.listenManual(widgetStateProvider, (_, next) {
      if (next != null) {
        unawaited(ref.read(widgetStateWriterProvider).write(next));
      }
    });
    _lifecycle = AppLifecycleListener(
      onResume: _run,
      onHide: () {
        _midnight?.call();
        _midnight = null;
      },
    );
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      // Đọc trước bước chờ: sau đó widget có thể đã bị gỡ (thoát app).
      final reporter = ref.read(errorReporterProvider);
      try {
        await ref
            .read(notificationGatewayProvider)
            .init(
              onTap: (payload) {
                if (!mounted) return;
                ref
                    .read(routerProvider)
                    .go(payload.isEmpty ? reminderPayload : payload);
              },
            );
      } catch (e, st) {
        await reporter.report(e, st, reason: 'notifications_init');
      }
      // Token thẻ màn hình khóa từ iOS (TA3-12, TA3-13).
      ref.read(liveActivityControllerProvider).start();
      _run();
    });
  }

  void _run() {
    if (!mounted) return;
    // Đồng hồ giao diện đọc lại giờ (VS06-T05): có thể vừa qua giờ tập, 00:00.
    ref.invalidate(nowProvider);
    if (ref.read(widgetStateProvider) case final widget?) {
      unawaited(ref.read(widgetStateWriterProvider).write(widget, force: true));
    }
    // Thẻ ngày cũ tắt, token gửi lại khi cần (05 Bản 3 §6.4.4).
    unawaited(ref.read(liveActivityControllerProvider).refresh());
    unawaited(_tasks());
    _scheduleMidnight();
  }

  Future<void> _tasks() async {
    // Đang khôi phục (S-07): chưa đủ dữ liệu, tạo lịch tháng lúc này sẽ đè
    // lịch đang về; RestoreController tự chạy các việc này khi xong.
    if (ref.read(authControllerProvider).restoring) return;
    // Widget có thể bị gỡ giữa các bước chờ (thoát app): khi đó dừng, không
    // dùng `ref` nữa.
    final reporter = ref.read(errorReporterProvider);
    try {
      await ref.read(monthMaterializerProvider).run();
      if (!mounted) return;
      // F01-E2, ED-07: sang năm mới → tính lại mức calo (đề xuất ở S-52).
      await ref.read(calorieUpdatesProvider).checkNewYear();
      if (!mounted) return;
      await ref.read(notificationPermissionProvider.notifier).refresh();
      if (!mounted) return;
      await ref.read(reminderSchedulerProvider).reschedule();
    } catch (e, st) {
      await reporter.report(e, st, reason: 'background_tasks');
    }
  }

  /// Hẹn lần chạy kế tiếp ngay sau 00:00 theo giờ trên máy.
  void _scheduleMidnight() {
    _midnight?.call();
    final now = ref.read(clockProvider).now();
    final next = LocalDate.fromDateTime(now).addDays(1).startOfDay;
    _midnight = ref
        .read(syncSchedulerProvider)
        .after(next.difference(now) + const Duration(seconds: 1), _run);
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    _midnight?.call();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
