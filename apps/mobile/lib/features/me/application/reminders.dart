import 'package:api_contract/api_contract.dart';
import 'package:domain/domain.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../app/strings_vi.dart';
import '../../../core/formatters.dart';
import '../../../data/db/app_database.dart';
import '../../../data/notifications/notification_gateway.dart';
import '../../../data/sync/outbox_writer.dart';
import '../../../data/sync/sync_providers.dart';
import '../../schedule/data/schedule_repository.dart';
import '../data/profile_repository.dart';

/// Route mở khi Bạn chạm vào nhắc (NAV-2, UR-08).
const reminderPayload = '/today';

final notificationGatewayProvider = Provider<NotificationGateway>(
  (ref) => LocalNotificationGateway(),
);

/// Nội dung nhắc (F04-R3, F04-E1): "Hôm nay tập ngực và tay sau lúc 18:00".
String reminderBody(Reminder r) {
  final muscles = Fmt.muscles(r.muscles, capitalize: false);
  final time = Fmt.time(r.time);
  return r.isTomorrow
      ? S.reminderTomorrow(muscles, time)
      : S.reminderToday(muscles, time);
}

/// Lập và hẹn lại toàn bộ nhắc (05 §6.4.4, TR-10): hủy hết → công tắc tắt
/// hoặc chưa có quyền thì dừng → hẹn tối đa 60 nhắc của tháng này và tháng
/// sau.
final class ReminderScheduler {
  ReminderScheduler({
    required NotificationGateway gateway,
    required ProfileRepository profiles,
    required ScheduleRepository schedule,
    required Clock clock,
  }) : _gateway = gateway,
       _profiles = profiles,
       _schedule = schedule,
       _clock = clock;

  final NotificationGateway _gateway;
  final ProfileRepository _profiles;
  final ScheduleRepository _schedule;
  final Clock _clock;

  /// Các nhắc sẽ hẹn nếu công tắc bật (dùng cả cho ví dụ ở S-06).
  Future<List<Reminder>> upcoming() async {
    final now = _clock.now();
    final month = LocalDate.fromDateTime(now).yearMonth;
    final hasNext = await _schedule.plan(month.next) != null;
    return ReminderPlanner.plan(
      currentMonth: await _schedule.monthDays(month),
      nextMonth: hasNext ? await _schedule.monthDays(month.next) : null,
      template: await _schedule.template(),
      now: now,
    );
  }

  /// Trả số nhắc đã hẹn.
  Future<int> reschedule() async {
    await _gateway.cancelAll();
    final profile = await _profiles.get();
    if (profile == null || !profile.remindersEnabled) return 0;
    if (!await _gateway.isPermitted()) return 0;
    final reminders = await upcoming();
    for (final r in reminders) {
      await _gateway.schedule(
        id: r.id,
        at: r.at,
        body: reminderBody(r),
        payload: reminderPayload,
      );
    }
    return reminders.length;
  }
}

final reminderSchedulerProvider = Provider<ReminderScheduler>(
  (ref) => ReminderScheduler(
    gateway: ref.watch(notificationGatewayProvider),
    profiles: ref.watch(profileRepositoryProvider),
    schedule: ref.watch(scheduleRepositoryProvider),
    clock: ref.watch(clockProvider),
  ),
);

/// iPhone có đang cho phép thông báo không. null = chưa đọc. Đọc lại mỗi lần
/// app quay lại foreground (Bạn có thể vừa đổi trong Cài đặt).
final notificationPermissionProvider =
    NotifierProvider<NotificationPermission, bool?>(NotificationPermission.new);

class NotificationPermission extends Notifier<bool?> {
  @override
  bool? build() => null;

  Future<bool> refresh() async {
    final permitted = await ref.read(notificationGatewayProvider).isPermitted();
    state = permitted;
    return permitted;
  }

  /// Xin quyền (iPhone chỉ hỏi lần đầu).
  Future<bool> request() async {
    final permitted = await ref
        .read(notificationGatewayProvider)
        .requestPermission();
    state = permitted;
    return permitted;
  }
}

/// F04-E2: nhắc đang bật nhưng iPhone chặn thông báo → cảnh báo ở S-50 và
/// chấm ở tab Tôi.
final remindersBlockedProvider = Provider<bool>((ref) {
  final enabled = ref.watch(remindersEnabledProvider).value ?? false;
  return enabled && ref.watch(notificationPermissionProvider) == false;
});

final remindersEnabledProvider = StreamProvider<bool>(
  (ref) => ref
      .watch(profileRepositoryProvider)
      .watch()
      .map((p) => p?.remindersEnabled ?? false),
);

/// Công tắc nhắc ở S-50 (F04-R1, F04-R6): ghi hồ sơ + outbox trong một
/// transaction, rồi hẹn lại nhắc.
final class SetReminders {
  SetReminders({
    required AppDatabase db,
    required ProfileRepository profiles,
    required OutboxWriter outbox,
    required ReminderScheduler scheduler,
  }) : _db = db,
       _profiles = profiles,
       _outbox = outbox,
       _scheduler = scheduler;

  final AppDatabase _db;
  final ProfileRepository _profiles;
  final OutboxWriter _outbox;
  final ReminderScheduler _scheduler;

  Future<void> call(bool enabled) async {
    await _db.transaction(() async {
      final p = (await _profiles.get())!;
      final next = p.copyWith(remindersEnabled: enabled);
      await _profiles.put(next);
      await _outbox.enqueue(
        SyncEntities.profile,
        ProfileCodec.key,
        SyncOp.upsert,
        const ProfileCodec().encode(next),
      );
    });
    await _scheduler.reschedule();
  }
}

final setRemindersProvider = Provider<SetReminders>(
  (ref) => SetReminders(
    db: ref.watch(databaseProvider),
    profiles: ref.watch(profileRepositoryProvider),
    outbox: ref.watch(outboxWriterProvider),
    scheduler: ref.watch(reminderSchedulerProvider),
  ),
);
