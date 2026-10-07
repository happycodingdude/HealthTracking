import 'dart:async';

import 'package:domain/domain.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/sync/sync_providers.dart';
import '../data/sync/sync_scheduler.dart';
import '../features/auth/application/auth_controller.dart';
import '../features/me/application/calorie_updates.dart';
import '../features/me/application/reminders.dart';
import '../features/schedule/application/month_materializer.dart';
import 'providers.dart';
import 'router.dart';
import 'time_ticker.dart';

/// Chạy các thành phần nền của app (05 §6.4.4) khi khởi động, khi quay lại
/// foreground và khi qua 00:00 lúc app đang mở: [MonthMaterializer] (F03-R6),
/// kiểm tra sang năm mới cho mức calo (F01-E2), rồi [ReminderScheduler]
/// (TR-10). Chạm vào nhắc → Hôm nay (NAV-2).
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
    _lifecycle = AppLifecycleListener(
      onResume: _run,
      onHide: () {
        _midnight?.call();
        _midnight = null;
      },
    );
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        await ref
            .read(notificationGatewayProvider)
            .init(
              onTap: (payload) => ref
                  .read(routerProvider)
                  .go(payload.isEmpty ? reminderPayload : payload),
            );
      } catch (e, st) {
        await ref
            .read(errorReporterProvider)
            .report(e, st, reason: 'notifications_init');
      }
      _run();
    });
  }

  void _run() {
    if (!mounted) return;
    // Đồng hồ giao diện đọc lại giờ (VS06-T05): có thể vừa qua giờ tập, 00:00.
    ref.invalidate(nowProvider);
    unawaited(_tasks());
    _scheduleMidnight();
  }

  Future<void> _tasks() async {
    // Đang khôi phục (S-07): chưa đủ dữ liệu, tạo lịch tháng lúc này sẽ đè
    // lịch đang về; RestoreController tự chạy các việc này khi xong.
    if (ref.read(authControllerProvider).restoring) return;
    try {
      await ref.read(monthMaterializerProvider).run();
      // F01-E2, ED-07: sang năm mới → tính lại mức calo (đề xuất ở S-52).
      await ref.read(calorieUpdatesProvider).checkNewYear();
      await ref.read(notificationPermissionProvider.notifier).refresh();
      await ref.read(reminderSchedulerProvider).reschedule();
    } catch (e, st) {
      await ref
          .read(errorReporterProvider)
          .report(e, st, reason: 'background_tasks');
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
