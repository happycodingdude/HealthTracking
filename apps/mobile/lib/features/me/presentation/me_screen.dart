import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers.dart';
import '../../../app/shell/app_tab.dart';
import '../../../app/strings_vi.dart';
import '../../../app/theme.dart';
import '../../../core/formatters.dart';
import '../../../core/widgets/settings_card.dart';
import '../../../core/widgets/tab_page.dart';
import '../../../core/widgets/toast.dart';
import '../../../data/sync/sync_providers.dart';
import '../application/budget_view.dart';
import '../application/calorie_view.dart';
import '../application/reminders.dart';
import 'budget_screen.dart';
import 'dev_server_status.dart';

/// S-50 — Tôi: "Hồ sơ cơ thể", "Mức calo" (VS-11), "Nhắc đi tập" (VS-05),
/// "Ngân sách AI" (VS-13), "Tài khoản và dữ liệu" (VS-02).
class MeScreen extends ConsumerWidget {
  const MeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pending = ref.watch(syncStatusProvider).value?.hasPending;
    final profile = ref.watch(profileProvider).value;
    final view = ref.watch(calorieViewProvider);
    final budget = ref.watch(aiBudgetViewProvider);
    final year = ref.watch(clockProvider).now().year;
    return TabPage(
      tab: AppTab.me,
      title: S.tabMe,
      children: [
        SettingsCard(
          children: [
            SettingsRow(
              key: const ValueKey('row-profile'),
              label: S.bodyProfile,
              value: profile == null || !profile.hasBody
                  ? null
                  : S.profileSummary(
                      profile.heightCm!,
                      ProfileRules.age(profile.birthYear!, year),
                      profile.sex == Sex.male ? S.sexMale : S.sexFemale,
                    ),
              onTap: () => context.go('/me/profile'),
            ),
            SettingsRow(
              key: const ValueKey('row-calorie'),
              label: S.calorieLevel,
              value: view == null
                  ? null
                  : S.calorieSummary(
                      Fmt.kcal(view.kcal),
                      view.belowSafetyFloor
                          ? S.belowSafetyFloor
                          : view.mode == CalorieMode.auto
                          ? S.calorieAuto
                          : S.calorieManual,
                    ),
              // F02-E3: có chấm khi đang chờ đề xuất.
              dot: profile?.caloriePendingKcal != null,
              onTap: () => context.go('/me/calorie'),
            ),
            const _RemindersRow(),
            SettingsRow(
              key: const ValueKey('row-budget'),
              label: S.aiBudget,
              value: S.budgetSummary(
                Fmt.vnd(budget.usedVnd),
                Fmt.vnd(budget.capVnd),
              ),
              below: BudgetBar(view: budget, height: 8),
              onTap: () => context.go(budgetPath),
            ),
            SettingsRow(
              key: const ValueKey('row-account-data'),
              label: S.accountAndData,
              value: pending == null
                  ? null
                  : (pending ? S.syncPending : S.syncDone),
              onTap: () => context.go('/me/account'),
            ),
          ],
        ),
        const SizedBox(height: 24),
        const DevServerStatus(),
      ],
    );
  }
}

/// Công tắc nhắc ngay trên dòng (04 S-50, F-04). Chưa có quyền → cảnh báo kèm
/// "Mở Cài đặt" (F04-E2, UX-AC14).
class _RemindersRow extends ConsumerWidget {
  const _RemindersRow();

  Future<void> _toggle(BuildContext context, WidgetRef ref, bool on) async {
    if (on) {
      // Lần đầu iPhone hỏi quyền; đã từ chối thì công tắc vẫn bật kèm cảnh báo.
      await ref.read(notificationPermissionProvider.notifier).request();
    }
    await ref.read(setRemindersProvider).call(on);
    if (context.mounted) {
      showToast(context, on ? S.remindersTurnedOn : S.remindersTurnedOff);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enabled = ref.watch(remindersEnabledProvider).value ?? false;
    final blocked = ref.watch(remindersBlockedProvider);
    final palette = context.palette;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(S.remindersRow, style: context.text.bodyLarge),
                    Text(
                      S.remindersHint,
                      style: context.text.bodyMedium?.copyWith(
                        color: palette.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                key: const ValueKey('reminders-switch'),
                value: enabled,
                onChanged: (on) => _toggle(context, ref, on),
              ),
            ],
          ),
          if (blocked)
            Container(
              key: const ValueKey('notifications-blocked'),
              margin: const EdgeInsets.only(top: 8, right: 8, bottom: 8),
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              decoration: BoxDecoration(
                color: palette.attentionContainer,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Semantics(
                    liveRegion: true,
                    child: Text(
                      S.notificationsBlocked,
                      style: context.text.bodyLarge?.copyWith(
                        color: palette.attention,
                      ),
                    ),
                  ),
                  TextButton(
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      foregroundColor: palette.attention,
                    ),
                    onPressed: () =>
                        ref.read(notificationGatewayProvider).openSettings(),
                    child: const Text(S.openSettings),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
