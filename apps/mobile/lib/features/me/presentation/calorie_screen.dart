import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/strings_vi.dart';
import '../../../app/theme.dart';
import '../../../core/formatters.dart';
import '../../../core/widgets/heading.dart';
import '../application/calorie_updates.dart';
import '../application/calorie_view.dart';
import 'calorie_card.dart';
import 'calorie_proposal_sheet.dart';
import 'set_calorie_sheet.dart';

/// S-52 — Mức calo (04 S-52): thẻ mức calo (dùng chung với S-04), banner đề
/// xuất đang chờ (F02-E3), "Đặt mức khác", ở chế độ Bạn tự đặt có "Dùng lại
/// ước tính của app ({Y} kcal)" (F02-AC6).
class CalorieScreen extends ConsumerWidget {
  const CalorieScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final view = ref.watch(calorieViewProvider);
    final profile = ref.watch(profileProvider).value;
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: EdgeInsets.fromLTRB(
            16,
            8,
            16,
            MediaQuery.paddingOf(context).bottom + 24,
          ),
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.only(right: 12),
                ),
                onPressed: () => context.pop(),
                icon: const Icon(Icons.chevron_left),
                label: const Text(S.tabMe),
              ),
            ),
            const SizedBox(height: 16),
            Heading(
              S.calorieLevel,
              style: context.text.headlineMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 16),
            if (view != null && profile != null) ...[
              CalorieCard(view: view),
              if (profile.caloriePendingKcal != null) ...[
                const SizedBox(height: 16),
                CalorieProposalBanner(profile: profile),
              ],
              const SizedBox(height: 16),
              OutlinedButton(
                key: const ValueKey('set-other-level'),
                onPressed: () async {
                  final kcal = await showSetCalorieSheet(
                    context,
                    sex: view.sex,
                    initial: view.kcal,
                  );
                  if (kcal != null) {
                    await ref.read(calorieUpdatesProvider).setManual(kcal);
                  }
                },
                child: const Text(S.setOtherLevel),
              ),
              if (view.mode == CalorieMode.manual)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    key: const ValueKey('use-app-estimate'),
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      textStyle: context.text.titleMedium,
                    ),
                    onPressed: () =>
                        ref.read(calorieUpdatesProvider).useAppEstimate(),
                    child: Text(S.useAppEstimate(Fmt.kcal(view.estimate.kcal))),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}
