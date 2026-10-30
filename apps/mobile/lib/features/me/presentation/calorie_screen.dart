import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/strings_vi.dart';
import '../../../ui/components/components.dart';
import '../application/calorie_updates.dart';
import '../application/calorie_view.dart';
import 'calorie_card.dart';
import 'calorie_proposal_sheet.dart';
import 'set_calorie_sheet.dart';

/// S-52 — Mức calo (04 Bản 4 S-52): thẻ số lớn + thanh chọn Tự động | Tự đặt
/// (dùng chung với S-04); đề xuất chờ: banner viền cam câu nguyên văn + "Giữ
/// nguyên" / "Dùng 2.180" (F02-E3). Không nhãn "tham khảo".
class CalorieScreen extends ConsumerWidget {
  const CalorieScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final view = ref.watch(calorieViewProvider);
    final profile = ref.watch(profileProvider).value;
    return IronlySubPage(
      title: S.calorieLevel,
      children: [
        if (view != null && profile != null) ...[
          CalorieCard(
            view: view,
            onAuto: () => ref.read(calorieUpdatesProvider).useAppEstimate(),
            onManual: () async {
              final kcal = await showSetCalorieSheet(
                context,
                sex: view.sex,
                initial: view.kcal,
              );
              if (kcal != null) {
                await ref.read(calorieUpdatesProvider).setManual(kcal);
              }
            },
          ),
          if (profile.caloriePendingKcal != null) ...[
            const CardGap(),
            CalorieProposalBanner(profile: profile),
          ],
        ],
      ],
    );
  }
}
