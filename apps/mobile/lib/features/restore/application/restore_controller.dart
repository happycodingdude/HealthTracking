import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/api/api_client.dart';
import '../../../data/sync/sync_providers.dart';
import '../../me/application/reminders.dart';
import '../../onboarding/application/setup_state.dart';
import '../../schedule/application/month_materializer.dart';

/// Trạng thái S-07: tiến trình 0–1, hoặc mất kết nối giữa chừng.
final class RestoreState {
  const RestoreState({this.progress = 0, this.failed = false});

  final double progress;
  final bool failed;
}

/// Khôi phục trên máy mới (06 VS14-T01, VS14-T02, 05 §6.6.5).
class RestoreController extends Notifier<RestoreState> {
  bool _running = false;

  @override
  RestoreState build() => const RestoreState();

  /// Pull đến hết rồi chuẩn bị app: lịch tháng (F03-R6), xin lại quyền thông
  /// báo nếu nhắc đang bật (F09-E2), hẹn nhắc. Trả trạng thái thiết lập trên
  /// máy sau khi khôi phục; null khi mất kết nối (thử lại tiếp tục từ cursor
  /// đã nhận) hoặc đang chạy.
  Future<SetupState?> run() async {
    if (_running) return null;
    _running = true;
    state = RestoreState(progress: state.progress);
    try {
      await ref
          .read(syncEngineProvider)
          .restore(onProgress: (p) => state = RestoreState(progress: p));
      await ref.read(monthMaterializerProvider).run();
      final profile = await ref.read(profileRepositoryProvider).get();
      final permission = ref.read(notificationPermissionProvider.notifier);
      if (profile?.remindersEnabled ?? false) {
        await permission.request();
      } else {
        await permission.refresh();
      }
      await ref.read(reminderSchedulerProvider).reschedule();
      state = const RestoreState(progress: 1);
      return SetupState.of(profile);
    } on ApiFailure {
      state = RestoreState(progress: state.progress, failed: true);
      return null;
    } finally {
      _running = false;
    }
  }
}

final restoreControllerProvider =
    NotifierProvider<RestoreController, RestoreState>(RestoreController.new);
