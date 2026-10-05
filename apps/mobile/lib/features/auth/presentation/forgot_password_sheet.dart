import 'package:flutter/material.dart';

import '../../../app/strings_vi.dart';
import '../../../app/theme.dart';
import '../../../core/widgets/app_sheet.dart';

/// S-01c — Quên mật khẩu (bảng trượt, Bản 1, UA-22).
Future<void> showForgotPasswordSheet(BuildContext context) =>
    showAppSheet<void>(context, builder: (_) => const ForgotPasswordSheet());

class ForgotPasswordSheet extends StatelessWidget {
  const ForgotPasswordSheet({super.key});

  @override
  Widget build(BuildContext context) {
    // Cuộn được khi cỡ chữ lớn (UX-AC18).
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            header: true,
            child: Text(
              S.forgotPassword,
              style: context.text.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(S.forgotPasswordBody, style: context.text.bodyLarge),
          const SizedBox(height: 16),
          Text(
            S.forgotPasswordNote,
            style: context.text.bodyMedium?.copyWith(
              color: context.palette.textSecondary,
            ),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(S.understood),
          ),
        ],
      ),
    );
  }
}
