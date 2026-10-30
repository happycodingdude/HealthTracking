import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/strings_vi.dart';
import '../../../ui/components/components.dart';
import '../../../ui/theme.dart';
import '../../me/application/calorie_view.dart';
import '../../me/presentation/calorie_card.dart';
import '../../me/presentation/set_calorie_sheet.dart';
import '../application/onboarding_steps.dart';
import 'onboarding_scaffold.dart';

/// S-04 — Mức calo (Bước 3/5, F-02, 04 Bản 4 S-04): số lớn + "kcal"; nút cam
/// "Giữ mức này" (Tự động, F02-R3), nút xám "Đặt mức khác" (Bạn tự đặt,
/// F02-R4). Không câu "Dùng làm mốc cho thực đơn gợi ý" (FR4-04).
class CalorieStepScreen extends ConsumerWidget {
  const CalorieStepScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final view = ref.watch(calorieViewProvider);
    final steps = ref.read(onboardingStepsProvider);
    Future<void> next(int? manualKcal) async {
      await steps.saveCalorie(manualKcal: manualKcal);
      if (context.mounted) context.go('/onboarding/4');
    }

    return OnboardingScaffold(
      step: 3,
      title: S.calorieTitle,
      bottom: [
        IronlyButton.primary(
          key: const ValueKey('keep-this-level'),
          label: S.keepThisLevel,
          onPressed: () {
            if (view == null) return;
            // Quay lại bước này sau khi đã tự đặt: giữ đúng mức đang hiện (OB-2).
            next(view.mode == CalorieMode.manual ? view.kcal : null);
          },
        ),
        const SizedBox(height: TokenSpace.s2),
        IronlyButton.gray(
          key: const ValueKey('set-other-level'),
          label: S.setOtherLevel,
          onPressed: () async {
            if (view == null) return;
            final kcal = await showSetCalorieSheet(context, sex: view.sex);
            if (kcal != null) await next(kcal);
          },
        ),
      ],
      // Dữ liệu trên máy đọc tức thì; chưa có thì để trống, không vòng xoay.
      children: [if (view != null) CalorieCard(view: view)],
    );
  }
}
