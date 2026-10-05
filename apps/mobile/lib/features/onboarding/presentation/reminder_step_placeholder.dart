import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers.dart';
import '../../../app/strings_vi.dart';
import '../application/setup_state.dart';
import 'onboarding_scaffold.dart';

/// S-06 giữ chỗ đến VS-05 (Bước 5/5). Bản dev có nút tạm để vào app thử các
/// tab; nút này không có ở flavor prod và bị gỡ khi đủ 5 bước.
class ReminderStepPlaceholder extends ConsumerWidget {
  const ReminderStepPlaceholder({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDev = ref.watch(envProvider).isDev;
    return OnboardingScaffold(
      step: 5,
      title: S.reminderStepTitle,
      bottom: [
        if (isDev)
          OutlinedButton(
            key: const ValueKey('dev-skip-onboarding'),
            onPressed: () {
              ref.read(devSkipSetupProvider.notifier).skip();
              context.go('/today');
            },
            child: const Text('Skip onboarding (dev)'),
          ),
      ],
      children: const [],
    );
  }
}
