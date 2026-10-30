import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../keys.dart';
import '../theme.dart';

/// Liên kết đi kèm câu lỗi (ví dụ "Đăng nhập" khi số đã có tài khoản).
final class ErrorAction {
  const ErrorAction(this.label, this.onTap);
  final String label;
  final VoidCallback onTap;
}

/// Ô nhập chữ dạng thẻ (04 Bản 4 §6.1): gợi ý trong ô là tên trường, không
/// nhãn trên; đang nhập viền 1,5 cam; lỗi viền 1,5 đỏ + câu đỏ 11 dưới ô (câu
/// giữ nguyên). [unit] = chữ phụ cố định bên phải ("cm", "kg"). [name] đặt
/// `Key` chuẩn `field-<name>` (IA4-08).
class IronlyTextField extends StatelessWidget {
  const IronlyTextField({
    super.key,
    required this.name,
    required this.hint,
    required this.controller,
    this.focusNode,
    this.error,
    this.errorAction,
    this.unit,
    this.keyboardType,
    this.textInputAction,
    this.obscureText = false,
    this.suffix,
    this.inputFormatters,
    this.autofillHints,
    this.onChanged,
    this.onSubmitted,
    this.textCapitalization = TextCapitalization.none,
    this.semanticsLabel,
    this.readOnly = false,
    this.onTap,
    this.textAlign = TextAlign.start,
    this.style,
    this.maxLines = 1,
    this.minLines,
    this.contentPadding,
  });

  final String name;
  final String hint;
  final TextEditingController controller;
  final FocusNode? focusNode;
  final String? error;
  final ErrorAction? errorAction;
  final String? unit;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final bool obscureText;
  final Widget? suffix;
  final List<TextInputFormatter>? inputFormatters;
  final Iterable<String>? autofillHints;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final TextCapitalization textCapitalization;
  final String? semanticsLabel;
  final bool readOnly;
  final VoidCallback? onTap;
  final TextAlign textAlign;
  final TextStyle? style;
  final int? maxLines;
  final int? minLines;
  final EdgeInsets? contentPadding;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final hasError = error != null;
    final theme = Theme.of(context).inputDecorationTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          label: semanticsLabel ?? hint,
          textField: true,
          child: TextField(
            key: K.field(name),
            controller: controller,
            focusNode: focusNode,
            keyboardType: keyboardType,
            textInputAction: textInputAction,
            obscureText: obscureText,
            autocorrect: false,
            enableSuggestions: !obscureText,
            autofillHints: autofillHints,
            inputFormatters: inputFormatters,
            onChanged: onChanged,
            onSubmitted: onSubmitted,
            onTap: onTap,
            readOnly: readOnly,
            textAlign: textAlign,
            maxLines: maxLines,
            minLines: minLines,
            textCapitalization: textCapitalization,
            style: style ?? IronlyText.body,
            cursorColor: t.accent,
            decoration: InputDecoration(
              hintText: hint,
              contentPadding: contentPadding,
              suffixIcon: suffix,
              suffixText: unit,
              suffixStyle: IronlyText.caption,
              enabledBorder: hasError ? theme.errorBorder : null,
              focusedBorder: hasError ? theme.focusedErrorBorder : null,
            ),
          ),
        ),
        if (hasError)
          Padding(
            padding: const EdgeInsets.only(top: 6, left: 2),
            child: Semantics(
              liveRegion: true,
              child: Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    '$error${errorAction == null ? '' : ' '}',
                    key: K.fieldError(name),
                    style: IronlyText.error,
                  ),
                  if (errorAction != null)
                    InkWell(
                      onTap: errorAction!.onTap,
                      child: Container(
                        constraints: const BoxConstraints(minHeight: 28),
                        alignment: Alignment.centerLeft,
                        child: Text(
                          errorAction!.label,
                          style: IronlyText.error.copyWith(
                            fontWeight: FontWeight.w600,
                            decoration: TextDecoration.underline,
                            decorationColor: t.danger,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// Dòng dạng ô nhập chỉ xem / chọn (Năm sinh ›, Mục tiêu ›, Giờ ›): nền thẻ,
/// nhãn trái chữ phụ, giá trị phải trắng, mũi tên nếu chạm được.
class IronlyValueRow extends StatelessWidget {
  const IronlyValueRow({
    super.key,
    required this.label,
    required this.value,
    this.onTap,
    this.unit,
    this.error,
    this.valueStyle,
    this.color,
  });

  final String label;
  final String value;
  final VoidCallback? onTap;
  final String? unit;
  final String? error;
  final TextStyle? valueStyle;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final radius = BorderRadius.circular(TokenRadius.field);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          button: onTap != null,
          label: '$label, $value${unit == null ? '' : ' $unit'}',
          child: ExcludeSemantics(
            child: Material(
              color: color ?? t.surface,
              // Material không nhận cả borderRadius lẫn shape.
              borderRadius: error == null ? radius : null,
              shape: error == null
                  ? null
                  : RoundedRectangleBorder(
                      borderRadius: radius,
                      side: BorderSide(
                        color: t.danger,
                        width: TokenSize.fieldStroke,
                      ),
                    ),
              child: InkWell(
                borderRadius: radius,
                onTap: onTap,
                child: Container(
                  constraints: const BoxConstraints(minHeight: 44),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          label,
                          style: IronlyText.body.copyWith(
                            color: t.textSecondary,
                          ),
                        ),
                      ),
                      Text(value, style: valueStyle ?? IronlyText.body),
                      if (unit != null) ...[
                        const SizedBox(width: 4),
                        Text(unit!, style: IronlyText.caption),
                      ],
                      if (onTap != null) ...[
                        const SizedBox(width: 4),
                        Icon(
                          Icons.chevron_right,
                          size: 18,
                          color: t.textSecondary,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        if (error != null)
          Padding(
            padding: const EdgeInsets.only(top: 6, left: 2),
            child: Text(error!, style: IronlyText.error),
          ),
      ],
    );
  }
}
