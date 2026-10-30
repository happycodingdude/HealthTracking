import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/strings_vi.dart';
import '../../../ui/components/components.dart';
import '../../../ui/keys.dart';
import '../../../ui/theme.dart';

/// Khung chung của các bước thiết lập lần đầu (OB-1, 04 Bản 4 S-02 → S-06):
/// đầu màn dải 5 vạch (bước đã qua và hiện tại cam, còn lại thẻ nổi) thay
/// "Bước n/5", nút quay lại từ bước 2; tiêu đề; nội dung cuộn; phần nút luôn
/// nằm trên bàn phím (04 §6.17). Thanh tab bị ẩn (NAV-7).
class OnboardingScaffold extends StatelessWidget {
  const OnboardingScaffold({
    super.key,
    required this.step,
    required this.title,
    required this.children,
    required this.bottom,
    this.scrollController,
  });

  final int step;
  final String title;
  final List<Widget> children;
  final List<Widget> bottom;
  final ScrollController? scrollController;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    const total = ProfileRules.onboardingSteps;
    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: 44,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Dải 5 vạch, VoiceOver đọc "Bước n/5".
                  Semantics(
                    container: true,
                    label: S.stepOf(step),
                    child: ExcludeSemantics(
                      child: Row(
                        key: const ValueKey('onboarding-steps'),
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          for (var i = 1; i <= total; i++) ...[
                            if (i > 1) const SizedBox(width: TokenSpace.s1),
                            Container(
                              key: ValueKey('onboarding-step-$i'),
                              width: 28,
                              height: 4,
                              decoration: BoxDecoration(
                                color: i <= step ? t.accent : t.surfaceRaised,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  if (step > 1)
                    Positioned(
                      left: TokenSpace.s1,
                      child: Semantics(
                        button: true,
                        label: S.back,
                        child: ExcludeSemantics(
                          child: GestureDetector(
                            key: K.pageBack,
                            behavior: HitTestBehavior.opaque,
                            // OB-2: quay lại không mất thông tin đã nhập.
                            onTap: () => context.go('/onboarding/${step - 1}'),
                            child: SizedBox(
                              width: 44,
                              height: 44,
                              child: Icon(
                                Icons.chevron_left,
                                color: t.accent,
                                size: 26,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              // Dựng đủ mọi ô (không lười như ListView) để cuộn được tới ô lỗi
              // đầu tiên (OB-5).
              child: SingleChildScrollView(
                controller: scrollController,
                padding: const EdgeInsets.fromLTRB(
                  pageInset,
                  TokenSpace.s3,
                  pageInset,
                  TokenSpace.s4,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Semantics(
                      header: true,
                      child: Text(title, style: IronlyText.title),
                    ),
                    const SizedBox(height: TokenSpace.s4),
                    ...children,
                  ],
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(
                pageInset,
                TokenSpace.s2,
                pageInset,
                MediaQuery.paddingOf(context).bottom > 0
                    ? TokenSpace.s2
                    : TokenSpace.s4,
              ),
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
