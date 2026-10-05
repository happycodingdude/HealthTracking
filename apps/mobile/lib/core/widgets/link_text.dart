import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../app/theme.dart';

/// Dòng "Câu hỏi? Liên kết" (ví dụ "Đã có tài khoản? Đăng nhập").
class LinkText extends StatelessWidget {
  const LinkText({
    super.key,
    required this.prefix,
    required this.link,
    required this.onTap,
  });

  final String prefix;
  final String link;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final base = context.text.bodyLarge?.copyWith(
      color: context.palette.textSecondary,
    );
    return Semantics(
      link: true,
      label: '$prefix $link',
      onTap: onTap,
      child: ExcludeSemantics(
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 44),
            child: Center(
              child: Text.rich(
                TextSpan(
                  style: base,
                  children: [
                    TextSpan(text: '$prefix '),
                    TextSpan(
                      text: link,
                      style: base?.copyWith(
                        color: context.colors.primary,
                        decoration: TextDecoration.underline,
                        decorationColor: context.colors.primary,
                      ),
                      recognizer: TapGestureRecognizer()..onTap = onTap,
                    ),
                  ],
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
