import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/strings_vi.dart';
import '../../../core/formatters.dart';
import '../../../ui/components/components.dart';
import '../../../ui/theme.dart';
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

/// S-53 — Đề xuất mức calo (04 Bản 4 S-53): câu nguyên văn 15 / 600 + "Hiện
/// tại Bạn đang dùng…" chữ phụ; nút cam "Dùng 2.180 kcal", xám "Giữ nguyên".
/// Vuốt đóng mà không chọn → đề xuất nằm lại ở S-52, tab Tôi có chấm (UA-14).
Future<void> showCalorieProposalSheet(BuildContext context) =>
    showIronlySheet<void>(
      context,
      builder: (_) => const CalorieProposalSheet(),
    );

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
    return IronlySheet(
      footer: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          IronlyButton.primary(
            key: const ValueKey('proposal-accept'),
            label: S.useKcal(kcal),
            onPressed: () async {
              await ref.read(calorieUpdatesProvider).acceptProposal();
              if (context.mounted) Navigator.of(context).pop();
            },
          ),
          const SizedBox(height: TokenSpace.s2),
          IronlyButton.gray(
            key: const ValueKey('proposal-keep'),
            label: S.keepCurrent,
            onPressed: () async {
              await ref.read(calorieUpdatesProvider).keepManual();
              if (context.mounted) Navigator.of(context).pop();
            },
          ),
        ],
      ),
      children: [
        Text(
          S.calorieProposal(
            kcal,
            byWeight:
                profile.caloriePendingReason == CaloriePendingReason.weight,
          ),
          style: IronlyText.subtitle,
        ),
        const SizedBox(height: TokenSpace.s2),
        Text(
          S.currentlyUsing(Fmt.kcal(profile.calorieKcal!)),
          style: IronlyText.caption,
        ),
      ],
    );
  }
}

/// Banner viền cam đề xuất đang chờ ở S-52 (F02-E3, 04 Bản 4 S-52): câu
/// nguyên văn + nút xám "Giữ nguyên", cam "Dùng 2.180".
class CalorieProposalBanner extends ConsumerWidget {
  const CalorieProposalBanner({super.key, required this.profile});

  final Profile profile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final kcal = Fmt.kcal(profile.caloriePendingKcal!);
    final stacked =
        MediaQuery.textScalerOf(context).scale(1) >= IronlyRow.stackedScale;
    final accept = IronlyButton.primary(
      key: const ValueKey('banner-accept'),
      label: S.useKcal(Fmt.integer(profile.caloriePendingKcal!)),
      small: true,
      onPressed: () => ref.read(calorieUpdatesProvider).acceptProposal(),
    );
    final keep = IronlyButton.gray(
      key: const ValueKey('banner-keep'),
      label: S.keepCurrent,
      small: true,
      onPressed: () => ref.read(calorieUpdatesProvider).keepManual(),
    );
    return Container(
      key: const ValueKey('proposal-banner'),
      padding: const EdgeInsets.all(TokenSize.cardPadding),
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(TokenRadius.banner),
        border: Border.all(color: t.accent, width: TokenSize.fieldStroke),
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
            style: IronlyText.body,
          ),
          const SizedBox(height: TokenSpace.s3),
          if (stacked) ...[
            keep,
            const SizedBox(height: TokenSpace.s2),
            accept,
          ] else
            Row(
              children: [
                Expanded(child: keep),
                const SizedBox(width: TokenSpace.s3),
                Expanded(child: accept),
              ],
            ),
        ],
      ),
    );
  }
}
