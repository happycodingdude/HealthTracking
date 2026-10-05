import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/strings_vi.dart';
import '../../../app/theme.dart';
import '../../../core/widgets/heading.dart';

/// Khung chung của các bước thiết lập lần đầu (OB-1): "‹ Quay lại" (trừ bước
/// 1), "Bước n/5", thanh tiến độ, tiêu đề, nội dung cuộn và phần nút luôn nằm
/// trên bàn phím (04 §6.17). Thanh tab bị ẩn (NAV-7).
class OnboardingScaffold extends StatelessWidget {
  const OnboardingScaffold({
    super.key,
    required this.step,
    required this.title,
    this.subtitle,
    required this.children,
    required this.bottom,
    this.scrollController,
  });

  final int step;
  final String title;
  final String? subtitle;
  final List<Widget> children;
  final List<Widget> bottom;
  final ScrollController? scrollController;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 48),
                // Cỡ chữ lớn: "Bước n/5" xuống dòng, không tràn (UX-AC18).
                child: Wrap(
                  alignment: step > 1
                      ? WrapAlignment.spaceBetween
                      : WrapAlignment.end,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 12,
                  children: [
                    if (step > 1)
                      TextButton.icon(
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.only(right: 12),
                        ),
                        // OB-2: quay lại không mất thông tin đã nhập.
                        onPressed: () => context.go('/onboarding/${step - 1}'),
                        icon: const Icon(Icons.chevron_left),
                        label: const Text(S.back),
                      ),
                    Text(
                      S.stepOf(step),
                      style: context.text.bodyLarge?.copyWith(
                        color: context.palette.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: ExcludeSemantics(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: step / ProfileRules.onboardingSteps,
                    minHeight: 6,
                    color: colors.primary,
                    backgroundColor: context.palette.neutralContainer,
                  ),
                ),
              ),
            ),
            Expanded(
              // Dựng đủ mọi ô (không lười như ListView) để cuộn được tới ô lỗi
              // đầu tiên (OB-5).
              child: SingleChildScrollView(
                controller: scrollController,
                padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Heading(
                      title,
                      style: context.text.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        subtitle!,
                        style: context.text.bodyLarge?.copyWith(
                          color: context.palette.textSecondary,
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    ...children,
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: bottom,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
