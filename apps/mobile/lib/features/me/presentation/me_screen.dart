import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/shell/app_tab.dart';
import '../../../app/strings_vi.dart';
import '../../../core/formatters.dart';
import '../../../core/widgets/phone_input_formatter.dart';
import '../../../core/widgets/reference_tag.dart';
import '../../../data/sync/sync_providers.dart';
import '../../../ui/components/components.dart';
import '../../../ui/theme.dart';
import '../../auth/application/auth_controller.dart';
import '../../schedule/application/schedule_providers.dart';
import '../application/budget_view.dart';
import '../application/calorie_view.dart';
import '../application/reminders.dart';
import '../application/update_display_name.dart';
import 'budget_screen.dart';
import 'dev_server_status.dart';

/// S-50 — Tôi (04 Bản 4 S-50): thẻ hồ sơ (vòng tròn cam chữ cái đầu · tên ·
/// số điện thoại); thẻ danh sách mục icon tròn + tên + giá trị tóm tắt + ›:
/// Hồ sơ cơ thể · Mức calo (chấm cam khi có đề xuất chờ) · Nhắc đi tập +
/// công tắc; banner "iPhone đang chặn thông báo…" + "Mở Cài đặt"; thẻ tiếp:
/// Ngân sách AI + thanh nhỏ · Tài khoản và dữ liệu (icon đồng bộ xám xoay
/// vòng cạnh tên chỉ khi chưa đồng bộ) · Về gợi ý tham khảo.
class MeScreen extends ConsumerWidget {
  const MeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final pending = ref.watch(syncStatusProvider).value?.hasPending ?? false;
    final profile = ref.watch(profileProvider).value;
    final view = ref.watch(calorieViewProvider);
    final budget = ref.watch(aiBudgetViewProvider);
    final name = ref.watch(displayNameProvider).value ?? '';
    final phone = ref.watch(authControllerProvider).phone;
    return IronlyTabPage(
      tab: AppTab.me,
      title: S.tabMe,
      children: [
        IronlyCard(
          key: const ValueKey('me-profile-card'),
          child: Row(
            children: [
              Container(
                width: TokenSize.avatarLarge,
                height: TokenSize.avatarLarge,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: t.accent,
                  shape: BoxShape.circle,
                ),
                child: ExcludeSemantics(
                  child: Text(
                    name.isEmpty ? '' : name.characters.first.toUpperCase(),
                    style: IronlyText.subtitle.copyWith(color: t.textPrimary),
                  ),
                ),
              ),
              const SizedBox(width: TokenSpace.s3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      key: const ValueKey('me-display-name'),
                      style: IronlyText.subtitle,
                    ),
                    if (phone != null)
                      Text(
                        PhoneInputFormatter.format(phone),
                        style: IronlyText.caption,
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const CardGap(),
        IronlyListCard(
          children: [
            IronlyRow(
              key: const ValueKey('row-profile'),
              leading: const CircleIcon(Icons.person_outline),
              title: S.bodyProfile,
              subtitle: profile == null || !profile.hasBody
                  ? null
                  : S.profileSummary(
                      profile.heightCm!,
                      profile.sex == Sex.male ? S.sexMale : S.sexFemale,
                    ),
              chevron: true,
              onTap: () => context.go('/me/profile'),
            ),
            IronlyRow(
              key: const ValueKey('row-calorie'),
              leading: const CircleIcon(Icons.local_fire_department_outlined),
              title: S.calorieLevel,
              subtitle: view == null
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
              chevron: true,
              onTap: () => context.go('/me/calorie'),
            ),
            const _RemindersRow(),
          ],
        ),
        const _BlockedBanner(),
        const CardGap(),
        IronlyListCard(
          children: [
            IronlyRow(
              key: const ValueKey('row-budget'),
              leading: const CircleIcon(Icons.account_balance_wallet_outlined),
              title: S.aiBudget,
              value: Fmt.vnd(budget.usedVnd),
              below: Padding(
                padding: const EdgeInsets.only(top: TokenSpace.s1),
                child: SizedBox(
                  width: 72,
                  child: BudgetBar(view: budget, height: 4),
                ),
              ),
              chevron: true,
              onTap: () => context.go(budgetPath),
            ),
            IronlyRow(
              key: const ValueKey('row-account-data'),
              leading: const CircleIcon(Icons.cloud_outlined),
              title: S.accountAndData,
              // Chưa đồng bộ = icon cùng dòng với tên, không thêm dòng chữ
              // phụ: dòng giữ nguyên chiều cao khi đồng bộ xong.
              titleWidget: Row(
                children: [
                  Flexible(
                    child: Text(S.accountAndData, style: IronlyText.body),
                  ),
                  if (pending) ...[
                    const SizedBox(width: TokenSpace.s2),
                    // Bạn yêu cầu 01/11/2026: icon xoay vòng để thấy đang chạy.
                    SpinningIcon(
                      Icons.sync,
                      key: const ValueKey('sync-pending-icon'),
                      size: 16,
                      color: t.textSecondary,
                      semanticLabel: S.syncPending,
                    ),
                  ],
                ],
              ),
              chevron: true,
              onTap: () => context.go('/me/account'),
            ),
            // F10-R4: xem lại nội dung thông báo tham khảo bất cứ lúc nào.
            IronlyRow(
              key: const ValueKey('row-about-reference'),
              leading: const CircleIcon(Icons.visibility_outlined),
              title: S.aboutReferenceTitle,
              chevron: true,
              onTap: () => context.push(aboutReferencePath),
            ),
          ],
        ),
        const CardGap(),
        const DevServerStatus(),
      ],
    );
  }
}

/// Dòng "Nhắc đi tập" + công tắc tại chỗ (04 Bản 4 S-50, F-04).
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
    return IronlyRow(
      key: const ValueKey('row-reminders'),
      leading: const CircleIcon(Icons.notifications_none),
      title: S.remindersRow,
      // 04 Bản 2 UA2-15: chưa có lịch thì nói rõ vì sao bật mà chưa có nhắc.
      subtitle: ref.watch(scheduleStateProvider)?.hasSchedule == false
          ? S.remindersHintNoSchedule
          : S.remindersHint,
      trailing: IronlySwitch(
        key: const ValueKey('reminders-switch'),
        value: enabled,
        label: S.remindersRow,
        onChanged: (on) => _toggle(context, ref, on),
      ),
    );
  }
}

/// Banner viền cam "iPhone đang chặn thông báo của app." + "Mở Cài đặt" khi
/// bị chặn (F04-E2, UX-AC14).
class _BlockedBanner extends ConsumerWidget {
  const _BlockedBanner();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(remindersBlockedProvider)) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: TokenSpace.s3),
      child: IronlyBanner(
        key: const ValueKey('notifications-blocked'),
        text: S.notificationsBlocked,
        actionLabel: S.openSettings,
        actionKey: const ValueKey('open-settings'),
        onAction: () => ref.read(notificationGatewayProvider).openSettings(),
      ),
    );
  }
}
