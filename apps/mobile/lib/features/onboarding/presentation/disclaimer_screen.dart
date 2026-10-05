import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/strings_vi.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/reference_tag.dart';
import '../application/onboarding_steps.dart';
import 'onboarding_scaffold.dart';

/// S-02 — Thông báo tham khảo (Bước 1/5, F10-R1). Không có nút bỏ qua
/// (F10-AC1).
class DisclaimerScreen extends ConsumerWidget {
  const DisclaimerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return OnboardingScaffold(
      step: 1,
      title: S.disclaimerTitle,
      bottom: [
        PrimaryButton(
          label: S.iUnderstand,
          onPressed: () async {
            await ref.read(onboardingStepsProvider).acceptDisclaimer();
            if (context.mounted) context.go('/onboarding/2');
          },
        ),
      ],
      children: const [DisclaimerPoints()],
    );
  }
}
