import 'dart:async';

import 'package:domain/domain.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/sync/sync_providers.dart';
import '../data/sync/sync_scheduler.dart';
import '../features/schedule/application/month_materializer.dart';
import 'providers.dart';

/// Chạy các thành phần nền của app (05 §6.4.4) khi khởi động, khi quay lại
/// foreground và khi qua 00:00 lúc app đang mở: [MonthMaterializer] (F03-R6).
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
    WidgetsBinding.instance.addPostFrameCallback((_) => _run());
  }

  void _run() {
    if (!mounted) return;
    unawaited(
      ref
          .read(monthMaterializerProvider)
          .run()
          .catchError(
            (Object e, StackTrace st) => ref
                .read(errorReporterProvider)
                .report(e, st, reason: 'month_materializer')
                .then((_) => false),
          ),
    );
    _scheduleMidnight();
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
