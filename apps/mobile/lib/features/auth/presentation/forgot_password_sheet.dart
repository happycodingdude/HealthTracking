import 'package:flutter/material.dart';

import '../../../app/strings_vi.dart';
import '../../../ui/components/components.dart';
import '../../../ui/theme.dart';

/// S-01c — Quên mật khẩu (bảng trượt, 04 Bản 4 S-01c): câu nguyên văn Bản 1 +
/// nút cam "Đã hiểu".
Future<void> showForgotPasswordSheet(BuildContext context) =>
    showIronlySheet<void>(context, builder: (_) => const ForgotPasswordSheet());

class ForgotPasswordSheet extends StatelessWidget {
  const ForgotPasswordSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return IronlySheet(
      title: S.forgotPassword,
      footer: IronlyButton.primary(
        key: const ValueKey('forgot-password-ok'),
        label: S.understood,
        onPressed: () => Navigator.of(context).pop(),
      ),
      children: [
        Text(S.forgotPasswordBody, style: IronlyText.body),
        const SizedBox(height: TokenSpace.s3),
        Text(S.forgotPasswordNote, style: IronlyText.caption),
      ],
    );
  }
}
