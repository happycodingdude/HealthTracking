import 'package:flutter/material.dart';

import '../../../app/strings_vi.dart';
import '../../../ui/components/components.dart';
import '../../../ui/theme.dart';

/// Ô mật khẩu của S-01a / S-01b (04 Bản 4 v1.7 §6.7): chữ 17 / 500, gợi ý
/// trong ô là tên trường, nút mắt 44 × 44 (icon 22 chữ phụ) bên phải để hiện /
/// ẩn. Mật khẩu không bao giờ hiện trên tấm thẻ.
class PasswordField extends StatefulWidget {
  const PasswordField({
    super.key,
    required this.name,
    required this.label,
    required this.controller,
    this.focusNode,
    this.error,
    this.onChanged,
    this.onSubmitted,
    this.textInputAction,
    this.autofillHints,
  });

  final String name;
  final String label;
  final TextEditingController controller;
  final FocusNode? focusNode;
  final String? error;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final TextInputAction? textInputAction;
  final Iterable<String>? autofillHints;

  @override
  State<PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<PasswordField> {
  bool _visible = false;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return IronlyTextField(
      name: widget.name,
      hint: widget.label,
      controller: widget.controller,
      focusNode: widget.focusNode,
      error: widget.error,
      obscureText: !_visible,
      style: IronlyText.authField,
      onChanged: widget.onChanged,
      onSubmitted: widget.onSubmitted,
      textInputAction: widget.textInputAction,
      autofillHints: widget.autofillHints,
      suffix: Semantics(
        container: true,
        button: true,
        label: _visible ? S.hidePassword : S.showPassword,
        child: ExcludeSemantics(
          child: GestureDetector(
            key: ValueKey('${widget.name}-toggle'),
            behavior: HitTestBehavior.opaque,
            onTap: () => setState(() => _visible = !_visible),
            child: SizedBox(
              width: 44,
              height: 44,
              child: Icon(
                _visible
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                size: 22,
                color: t.textSecondary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
