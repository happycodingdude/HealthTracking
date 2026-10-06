import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/strings_vi.dart';
import '../../../app/theme.dart';
import '../../../core/formatters.dart';
import '../../../core/widgets/app_sheet.dart';
import '../../../core/widgets/heading.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/toast.dart';
import '../application/calorie_updates.dart';
import '../application/calorie_view.dart';

/// Báo kết quả tính lại mức calo sau khi ghi cân hoặc lưu hồ sơ (04 S-41
/// "Sau khi lưu", S-51): Tự động → thông báo nhanh tiếp theo (F02-R8); Bạn
/// tự đặt → S-53 (F02-R9); chênh dưới 10 kcal → không gì (F02-R10).
void showCalorieOutcome(BuildContext context, CalorieOutcome outcome) {
  if (!context.mounted) return;
  switch (outcome) {
    case CalorieAutoUpdated(:final from, :final to):
      showToast(
        context,
        S.calorieUpdated(Fmt.integer(from), Fmt.integer(to)),
        next: true,
      );
    case CalorieProposed():
      showCalorieProposalSheet(context);
    case CalorieUnchanged():
      break;
  }
}

/// S-53 — Đề xuất mức calo. Vuốt đóng mà không chọn → đề xuất nằm lại ở S-52,
/// tab Tôi có chấm (UA-14, F02-E3).
Future<void> showCalorieProposalSheet(BuildContext context) =>
    showAppSheet<void>(context, builder: (_) => const CalorieProposalSheet());

class CalorieProposalSheet extends ConsumerWidget {
  const CalorieProposalSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider).value;
    final pending = profile?.caloriePendingKcal;
    if (profile == null || pending == null) {
      return const SizedBox(height: 120);
    }
    final kcal = Fmt.kcal(pending);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Heading(
            S.updateCalorieTitle,
            style: context.text.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            S.calorieProposal(
              kcal,
              byWeight:
                  profile.caloriePendingReason == CaloriePendingReason.weight,
            ),
            style: context.text.bodyLarge,
          ),
          const SizedBox(height: 12),
          Text(
            S.currentlyUsing(Fmt.kcal(profile.calorieKcal!)),
            style: context.text.bodyLarge?.copyWith(
              color: context.palette.textSecondary,
            ),
          ),
          const SizedBox(height: 24),
          PrimaryButton(
            key: const ValueKey('proposal-accept'),
            label: S.useKcal(kcal),
            onPressed: () async {
              await ref.read(calorieUpdatesProvider).acceptProposal();
              if (context.mounted) Navigator.of(context).pop();
            },
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            key: const ValueKey('proposal-keep'),
            onPressed: () async {
              await ref.read(calorieUpdatesProvider).keepManual();
              if (context.mounted) Navigator.of(context).pop();
            },
            child: const Text(S.keepCurrent),
          ),
        ],
      ),
    );
  }
}

/// Banner đề xuất đang chờ ở S-52 (F02-E3, mock S-52-1): nội dung F02-R9 kèm
/// "Dùng {Y} kcal" · "Giữ nguyên".
class CalorieProposalBanner extends ConsumerWidget {
  const CalorieProposalBanner({super.key, required this.profile});

  final Profile profile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final kcal = Fmt.kcal(profile.caloriePendingKcal!);
    final stacked = MediaQuery.textScalerOf(context).scale(1) >= 1.6;
    final accept = FilledButton(
      key: const ValueKey('banner-accept'),
      onPressed: () => ref.read(calorieUpdatesProvider).acceptProposal(),
      child: Text(S.useKcal(kcal), textAlign: TextAlign.center),
    );
    final keep = OutlinedButton(
      key: const ValueKey('banner-keep'),
      style: OutlinedButton.styleFrom(
        foregroundColor: palette.attention,
        side: BorderSide(color: palette.attention),
      ),
      onPressed: () => ref.read(calorieUpdatesProvider).keepManual(),
      child: const Text(S.keepCurrent, textAlign: TextAlign.center),
    );
    return Container(
      key: const ValueKey('proposal-banner'),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      decoration: BoxDecoration(
        color: palette.attentionContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            S.calorieProposal(
              kcal,
              byWeight:
                  profile.caloriePendingReason == CaloriePendingReason.weight,
            ),
            style: context.text.bodyLarge?.copyWith(color: palette.attention),
          ),
          const SizedBox(height: 12),
          if (stacked) ...[
            accept,
            const SizedBox(height: 8),
            keep,
          ] else
            Row(
              children: [
                Expanded(child: accept),
                const SizedBox(width: 12),
                Expanded(child: keep),
              ],
            ),
        ],
      ),
    );
  }
}
