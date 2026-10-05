import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/strings_vi.dart';
import '../../../app/theme.dart';
import '../../../core/widgets/heading.dart';

/// S-01 — Chào mừng. "Đăng ký" là nút chính vì người mở màn hình này phần lớn
/// là người mới (04 §6.6). Cỡ chữ lớn: cả trang cuộn được, không chữ nào bị che.
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, viewport) => SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: viewport.maxHeight - 32),
              child: IntrinsicHeight(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Spacer(),
                    Center(
                      child: Container(
                        width: 88,
                        height: 88,
                        decoration: BoxDecoration(
                          color: context.colors.primaryContainer,
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: Icon(
                          Icons.event_available_outlined,
                          size: 44,
                          color: context.colors.primary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Heading(
                      S.appName,
                      textAlign: TextAlign.center,
                      style: context.text.headlineLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      S.welcomeTagline,
                      textAlign: TextAlign.center,
                      style: context.text.titleMedium?.copyWith(
                        color: context.palette.textSecondary,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    const Spacer(),
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: () => context.go('/welcome/register'),
                      child: const Text(S.register),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton(
                      onPressed: () => context.go('/welcome/login'),
                      child: const Text(S.login),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      S.welcomeFootnote,
                      textAlign: TextAlign.center,
                      style: context.text.bodyMedium?.copyWith(
                        color: context.palette.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
