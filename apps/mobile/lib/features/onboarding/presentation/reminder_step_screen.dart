import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/strings_vi.dart';
import '../../../app/theme.dart';
import '../../../core/formatters.dart';
import '../../../core/widgets/primary_button.dart';
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

/// S-06 — Nhắc đi tập (Bước 5/5, F-04). Ví dụ thật từ lịch vừa xếp. "Bật nhắc"
/// → iPhone hỏi quyền → vào Hôm nay dù Bạn đồng ý hay từ chối (công tắc vẫn
/// bật, F04-E2). "Để sau" → công tắc tắt, vào Hôm nay (OB-4).
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
        PrimaryButton(
          label: S.turnOnReminders,
          loading: _busy,
          onPressed: () => _finish(reminders: true),
        ),
        const SizedBox(height: 12),
        OutlinedButton(
          onPressed: _busy ? null : () => _finish(reminders: false),
          child: const Text(S.later),
        ),
      ],
      children: [
        // 04 Bản 2 S-06, UA2-04, F04-E21: đã "Để sau" lịch tuần → câu ví dụ
        // chung.
        if (noSchedule) const _GenericExample(),
        if (first != null) ...[
          _Preview(reminder: first),
          const SizedBox(height: 20),
          Text(
            S.reminderExample(
              Fmt.clock(first.at),
              Fmt.weekday(LocalDate.fromDateTime(first.at)).toLowerCase(),
            ),
            style: context.text.bodyLarge?.copyWith(
              color: context.palette.textSecondary,
            ),
          ),
        ],
      ],
    );
  }
}

/// Câu ví dụ chung khi chưa có lịch (mock S-06-1 Bản 2): phần lời nhắc in
/// đậm, kèm dòng "Nhắc bắt đầu hoạt động khi Bạn xếp lịch tuần."
class _GenericExample extends StatelessWidget {
  const _GenericExample();

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    const example = S.reminderGenericExample;
    // Phần sau "…sẽ nhắc: " là lời nhắc, in đậm.
    final split = example.lastIndexOf(': ') + 2;
    return Container(
      key: const ValueKey('reminder-generic-example'),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      decoration: BoxDecoration(
        color: palette.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text.rich(
            TextSpan(
              text: example.substring(0, split),
              children: [
                TextSpan(
                  text: example.substring(split),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ],
            ),
            style: context.text.bodyLarge,
          ),
          const SizedBox(height: 12),
          Text(
            S.remindersStartWhenScheduled,
            style: context.text.bodyMedium?.copyWith(
              color: palette.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

/// Thẻ giống một thông báo trên iPhone (mock S-06).
class _Preview extends StatelessWidget {
  const _Preview({required this.reminder});

  final Reminder reminder;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      key: const ValueKey('reminder-preview'),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      decoration: BoxDecoration(
        color: palette.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            spacing: 12,
            children: [
              Text(
                S.appName,
                style: context.text.bodyMedium?.copyWith(
                  color: palette.textSecondary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                Fmt.clock(reminder.at),
                style: context.text.bodyMedium?.copyWith(
                  color: palette.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            reminderBody(reminder),
            style: context.text.bodyLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
