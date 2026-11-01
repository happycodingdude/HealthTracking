import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/strings_vi.dart';
import '../../../ui/components/components.dart';
import '../../../ui/theme.dart';
import 'auth_scaffold.dart';
import 'member_card.dart';

/// S-01 — Chào mừng, style "Thẻ hội viên" (04 Bản 4 v1.7 §6.7): góc trên trái
/// "Ironly" 22 / 800; giữa màn hai tấm thẻ xếp chồng (thẻ sau nền thẻ chìm
/// nghiêng +6°, lệch (10, 18); thẻ trước "IRONLY" nghiêng −5°); đáy màn (cách
/// đáy 40) nút cam "Tạo thẻ" → S-01a, nút xám "Đã có thẻ" → S-01b, cách 10.
/// Không câu giá trị, không icon app rời. Cỡ chữ lớn: cả trang cuộn được.
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  static const _deg = math.pi / 180;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final padding = MediaQuery.paddingOf(context);
    final top = math.max(64.0, padding.top);
    final bottom = math.max(40.0, padding.bottom);
    return Scaffold(
      body: LayoutBuilder(
        builder: (context, viewport) => SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(authInset, top, authInset, bottom),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: viewport.maxHeight - top - bottom,
            ),
            child: IntrinsicHeight(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Semantics(
                    header: true,
                    child: Text(S.appName, style: IronlyText.authAppName),
                  ),
                  const Spacer(),
                  Padding(
                    // Chừa chỗ cho phần thẻ nghiêng và thẻ sau lệch xuống.
                    padding: const EdgeInsets.symmetric(vertical: 40),
                    child: Stack(
                      key: const ValueKey('welcome-cards'),
                      clipBehavior: Clip.none,
                      children: [
                        Positioned.fill(
                          child: Transform.translate(
                            offset: const Offset(10, 18),
                            child: Transform.rotate(
                              angle: 6 * _deg,
                              child: MemberCardFrame(
                                key: const ValueKey('welcome-card-back'),
                                color: t.surfaceSunken,
                              ),
                            ),
                          ),
                        ),
                        Transform.rotate(
                          angle: -5 * _deg,
                          child: const MemberCard.brand(
                            key: ValueKey('welcome-card-front'),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  IronlyButton.primary(
                    key: const ValueKey('welcome-register'),
                    label: S.createCard,
                    large: true,
                    onPressed: () => context.go('/welcome/register'),
                  ),
                  const SizedBox(height: TokenSpace.s3),
                  IronlyButton.gray(
                    key: const ValueKey('welcome-login'),
                    label: S.haveCard,
                    large: true,
                    onPressed: () => context.go('/welcome/login'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
