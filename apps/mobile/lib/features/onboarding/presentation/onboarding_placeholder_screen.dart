import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers.dart';
import '../../../app/strings_vi.dart';
import '../../../app/theme.dart';
import '../../../core/widgets/heading.dart';

/// S-02 giữ chỗ cho đến VS-03 (thiết lập lần đầu). Bản dev có nút tạm để vào
/// app thử các tab; nút này không có ở flavor prod và bị gỡ ở VS-03.
class OnboardingPlaceholderScreen extends ConsumerWidget {
  const OnboardingPlaceholderScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDev = ref.watch(envProvider).isDev;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 32),
              Heading(
                S.disclaimerTitle,
                style: context.text.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              if (isDev)
                OutlinedButton(
                  key: const ValueKey('dev-skip-onboarding'),
                  onPressed: () => context.go('/today'),
                  child: const Text('Skip onboarding (dev)'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
