import 'package:domain/domain.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/sync/sync_providers.dart';
import '../features/schedule/application/schedule_providers.dart';
import 'providers.dart';

/// Thời điểm hiện tại cho giao diện (VS06-T05). Tự cập nhật ở mốc kế tiếp làm
/// trạng thái buổi tập đổi khi app đang mở: giờ tập hôm nay (Sắp tới → Chờ
/// đánh dấu) và 00:00 (sang ngày mới; 00:00 chủ nhật → Không tập (tự động);
/// hết hạn sửa 7 ngày). Quay lại foreground cũng đọc lại giờ.
final nowProvider = NotifierProvider<TimeTicker, DateTime>(TimeTicker.new);

class TimeTicker extends Notifier<DateTime> {
  @override
  DateTime build() {
    final now = ref.watch(clockProvider).now();
    final today = LocalDate.fromDateTime(now);
    final day = ref.watch(dayProvider(today)).value;
    final start = day != null && day.isWorkout
        ? SessionRules.startsAt(day)
        : null;
    final next = start != null && start.isAfter(now)
        ? start
        : today.addDays(1).startOfDay;
    final cancel = ref
        .watch(syncSchedulerProvider)
        .after(next.difference(now), ref.invalidateSelf);
    ref.onDispose(cancel);
    return now;
  }
}
