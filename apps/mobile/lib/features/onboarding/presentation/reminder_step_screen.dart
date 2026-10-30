import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/strings_vi.dart';
import '../../../core/formatters.dart';
import '../../../ui/components/components.dart';
import '../../../ui/theme.dart';
import '../../me/application/reminders.dart';
import '../../schedule/application/schedule_providers.dart';
import '../application/onboarding_steps.dart';
import 'onboarding_scaffold.dart';

/// Nhắc đầu tiên sẽ hẹn theo lịch Bạn vừa xếp (ví dụ ở S-06).
final firstReminderProvider = FutureProvider.autoDispose<Reminder?>((
  ref,
) async {
  final upcoming = await ref.watch(reminderSchedulerProvider).upcoming();
  return upcoming.firstOrNull;
});

/// S-06 — Nhắc đi tập (Bước 5/5, F-04, 04 Bản 4 S-06): icon chuông tròn,
/// "Nhắc Bạn trước giờ tập?"; thẻ ví dụ thật từ lịch ("Lúc 17:00 thứ 2, app
/// sẽ nhắc: Hôm nay tập ngực lúc 18:00" — dữ liệu của Bạn, giữ); nút cam "Bật
/// nhắc", nút xám "Để sau". "Bật nhắc" → iPhone hỏi quyền → vào Hôm nay dù
/// đồng ý hay từ chối (F04-E2). "Để sau" → công tắc tắt, vào Hôm nay (OB-4).
class ReminderStepScreen extends ConsumerStatefulWidget {
  const ReminderStepScreen({super.key});

  @override
  ConsumerState<ReminderStepScreen> createState() => _ReminderStepScreenState();
}

class _ReminderStepScreenState extends ConsumerState<ReminderStepScreen> {
  bool _busy = false;

  Future<void> _finish({required bool reminders}) async {
    if (_busy) return;
    setState(() => _busy = true);
    if (reminders) {
      await ref.read(notificationPermissionProvider.notifier).request();
    }
    final gateway = ref.read(notificationGatewayProvider);
    String? timezone;
    try {
      timezone = await gateway.timezone();
    } catch (_) {
      // Không đọc được múi giờ: vẫn hoàn tất, ghi ở lần sau.
    }
    await ref
        .read(onboardingStepsProvider)
        .complete(remindersEnabled: reminders, timezone: timezone);
    await ref.read(reminderSchedulerProvider).reschedule();
    if (mounted) context.go('/today');
  }

  @override
  Widget build(BuildContext context) {
    final first = ref.watch(firstReminderProvider).value;
    final noSchedule = ref.watch(scheduleStateProvider)?.hasSchedule == false;
    return OnboardingScaffold(
      step: 5,
      title: S.reminderStepTitle,
      bottom: [
        IronlyButton.primary(
          key: const ValueKey('turn-on-reminders'),
          label: S.turnOnReminders,
          loading: _busy,
          onPressed: () => _finish(reminders: true),
        ),
        const SizedBox(height: TokenSpace.s2),
        IronlyButton.gray(
          key: const ValueKey('reminders-later'),
          label: S.later,
          enabled: !_busy,
          onPressed: () => _finish(reminders: false),
        ),
      ],
      children: [
        const Center(child: CircleIcon(Icons.notifications_none, size: 72)),
        const SizedBox(height: TokenSpace.s5),
        // 04 Bản 2 S-06, UA2-04, F04-E21: đã "Để sau" lịch tuần → câu ví dụ
        // chung (giữ, là ví dụ); không dòng "Nhắc bắt đầu hoạt động khi…"
        // (FR4-04).
        if (noSchedule) const _GenericExample(),
        if (first != null) _Preview(reminder: first),
      ],
    );
  }
}

/// Câu ví dụ chung khi chưa có lịch (mock S-06-1 Bản 2): phần lời nhắc in
/// đậm.
class _GenericExample extends StatelessWidget {
  const _GenericExample();

  @override
  Widget build(BuildContext context) {
    const example = S.reminderGenericExample;
    // Phần sau "…sẽ nhắc: " là lời nhắc, in đậm.
    final split = example.lastIndexOf(': ') + 2;
    return IronlyCard(
      key: const ValueKey('reminder-generic-example'),
      child: Text.rich(
        TextSpan(
          text: example.substring(0, split),
          children: [
            TextSpan(
              text: example.substring(split),
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ],
        ),
        style: IronlyText.body,
      ),
    );
  }
}

/// Thẻ ví dụ thật từ lịch vừa xếp: "Lúc 17:00 thứ 2, app sẽ nhắc:" + lời nhắc
/// in đậm (04 Bản 4 S-06).
class _Preview extends StatelessWidget {
  const _Preview({required this.reminder});

  final Reminder reminder;

  @override
  Widget build(BuildContext context) {
    return IronlyCard(
      key: const ValueKey('reminder-preview'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            S.reminderExample(
              Fmt.clock(reminder.at),
              Fmt.weekday(LocalDate.fromDateTime(reminder.at)).toLowerCase(),
            ),
            style: IronlyText.caption,
          ),
          const SizedBox(height: TokenSpace.s2),
          Text(
            reminderBody(reminder),
            style: IronlyText.body.copyWith(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
