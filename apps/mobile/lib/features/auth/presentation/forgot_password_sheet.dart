import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../app/strings_vi.dart';
import '../../../ui/components/components.dart';
import '../../../ui/keys.dart';
import '../../../ui/theme.dart';
import 'auth_scaffold.dart';

/// S-01c — Quên mật khẩu (bảng trượt trên S-01b, 04 Bản 4 v1.7 §6.7): bo 22
/// trên, thanh kéo, lề 24, đáy 40; tiêu đề 17 / 700; câu nguyên văn Bản 1
/// (14 trắng, dãn dòng 1,5; 13 chữ phụ); nút cam "Đã hiểu" cao 52 bo 16 → đóng
/// bảng. Vuốt xuống cũng đóng.
Future<void> showForgotPasswordSheet(BuildContext context) {
  // Đáy 40 tính từ mép màn; bảng đã chừa vùng an toàn dưới (thanh vuốt).
  final bottomGap = math.max(
    TokenSpace.s2,
    40 - MediaQuery.paddingOf(context).bottom,
  );
  return showIronlySheet<void>(
    context,
    builder: (_) => ForgotPasswordSheet(bottomGap: bottomGap),
  );
}

class ForgotPasswordSheet extends StatelessWidget {
  const ForgotPasswordSheet({super.key, this.bottomGap = TokenSpace.s2});

  final double bottomGap;

  @override
  Widget build(BuildContext context) {
    return Column(
      key: K.sheet,
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const IronlySheetHandle(),
        Flexible(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(authInset, 0, authInset, bottomGap),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Semantics(
                  header: true,
                  child: Text(S.forgotPassword, style: IronlyText.authTitle),
                ),
                const SizedBox(height: TokenSpace.s3),
                Text(
                  S.forgotPasswordBody,
                  style: IronlyText.bodyRegular.copyWith(height: 1.5),
                ),
                const SizedBox(height: TokenSpace.s2),
                Text(S.forgotPasswordNote, style: IronlyText.dialogBody),
                const SizedBox(height: 20),
                IronlyButton.primary(
                  key: const ValueKey('forgot-password-ok'),
                  label: S.understood,
                  large: true,
                  height: TokenSize.authSheetButton,
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
