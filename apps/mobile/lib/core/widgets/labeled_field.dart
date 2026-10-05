import 'package:flutter/material.dart';

import '../../app/theme.dart';

/// Liên kết đi kèm câu lỗi (ví dụ "Đăng nhập" khi số đã có tài khoản).
final class ErrorAction {
  const ErrorAction(this.label, this.onTap);
  final String label;
  final VoidCallback onTap;
}

/// Ô nhập có nhãn phía trên; dòng gợi ý hoặc câu lỗi phía dưới (P4, 04 §6.13.5).
/// Lỗi dùng chữ đỏ (màu đỏ chỉ cho lỗi nhập liệu, UX-AC17).
class LabeledField extends StatelessWidget {
  const LabeledField({
    super.key,
    required this.label,
    required this.controller,
    this.focusNode,
    this.error,
    this.errorAction,
    this.hint,
    this.keyboardType,
    this.textInputAction,
    this.obscureText = false,
    this.suffix,
    this.inputFormatters,
    this.autofillHints,
    this.onChanged,
    this.onSubmitted,
    this.textCapitalization = TextCapitalization.none,
  });

  final String label;
  final TextEditingController controller;
  final FocusNode? focusNode;
  final String? error;
  final ErrorAction? errorAction;

  /// Dòng gợi ý luôn hiện khi không có lỗi.
  final String? hint;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final bool obscureText;
  final Widget? suffix;
  final List<dynamic>? inputFormatters;
  final Iterable<String>? autofillHints;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final TextCapitalization textCapitalization;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final hasError = error != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          label,
          style: context.text.bodyLarge?.copyWith(
            color: context.palette.textSecondary,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          focusNode: focusNode,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          obscureText: obscureText,
          autocorrect: false,
          enableSuggestions: !obscureText,
          autofillHints: autofillHints,
          inputFormatters: inputFormatters?.cast(),
          onChanged: onChanged,
          onSubmitted: onSubmitted,
          textCapitalization: textCapitalization,
          style: context.text.bodyLarge?.copyWith(fontSize: 17),
          decoration: InputDecoration(
            suffixIcon: suffix,
            // Viền đỏ khi lỗi; câu lỗi tự vẽ bên dưới để kèm được liên kết.
            enabledBorder: hasError
                ? Theme.of(context).inputDecorationTheme.errorBorder
                : null,
            focusedBorder: hasError
                ? Theme.of(context).inputDecorationTheme.focusedErrorBorder
                : null,
          ),
        ),
        if (hasError)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Semantics(
              liveRegion: true,
              child: Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    '$error${errorAction == null ? '' : ' '}',
                    style: context.text.bodyMedium?.copyWith(
                      color: colors.error,
                    ),
                  ),
                  if (errorAction != null)
                    InkWell(
                      onTap: errorAction!.onTap,
                      child: Container(
                        constraints: const BoxConstraints(minHeight: 32),
                        alignment: Alignment.centerLeft,
                        child: Text(
                          errorAction!.label,
                          style: context.text.bodyMedium?.copyWith(
                            color: colors.error,
                            fontWeight: FontWeight.w700,
                            decoration: TextDecoration.underline,
                            decorationColor: colors.error,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          )
        else if (hint != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              hint!,
              style: context.text.bodyMedium?.copyWith(
                color: context.palette.textSecondary,
              ),
            ),
          ),
      ],
    );
  }
}
