import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/strings_vi.dart';
import '../../../ui/components/components.dart';
import '../../../ui/theme.dart';

/// S-01 — Chào mừng (04 Bản 4 S-01): giữa màn icon app 80 bo 22 (thanh tạ cam
/// trên than) + "Ironly" 26 / 600; dưới: nút cam "Đăng ký", nút xám "Đăng
/// nhập". Không câu giá trị, không dòng "Tài khoản giúp…" (FR4-04). Cỡ chữ
/// lớn: cả trang cuộn được.
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, viewport) => SingleChildScrollView(
            padding: const EdgeInsets.all(pageInset),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: viewport.maxHeight - pageInset * 2,
              ),
              child: IntrinsicHeight(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Spacer(),
                    Center(
                      child: Container(
                        key: const ValueKey('welcome-icon'),
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: TokenColor.iconBg,
                          borderRadius: BorderRadius.circular(
                            TokenRadius.sheet,
                          ),
                        ),
                        child: DumbbellIcon(size: 40, color: t.accent),
                      ),
                    ),
                    const SizedBox(height: TokenSpace.s4),
                    Semantics(
                      header: true,
                      child: Text(
                        S.appName,
                        textAlign: TextAlign.center,
                        style: IronlyText.appName,
                      ),
                    ),
                    const Spacer(),
                    const SizedBox(height: TokenSpace.s4),
                    IronlyButton.primary(
                      key: const ValueKey('welcome-register'),
                      label: S.register,
                      onPressed: () => context.go('/welcome/register'),
                    ),
                    const SizedBox(height: TokenSpace.s2),
                    IronlyButton.gray(
                      key: const ValueKey('welcome-login'),
                      label: S.login,
                      onPressed: () => context.go('/welcome/login'),
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
