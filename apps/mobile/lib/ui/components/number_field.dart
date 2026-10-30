import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../keys.dart';
import '../theme.dart';

/// "." → "," ngay khi gõ (F21-E9, UR-10: hiểu như nhau, hiển thị bằng dấu
/// phẩy).
class CommaFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) => newValue.copyWith(text: newValue.text.replaceAll('.', ','));
}

/// Ô nhập số dạng thẻ với nhãn trái và đơn vị phải (Chiều cao 175 cm, Cân
/// nặng 74,9 kg; 04 Bản 4 S-03, S-51): đang nhập viền 1,5 cam; lỗi viền đỏ +
/// câu đỏ dưới ô.
class NumberField extends StatelessWidget {
  const NumberField({
    super.key,
    required this.name,
    required this.label,
    required this.controller,
    this.unit,
    this.error,
    this.focusNode,
    this.decimal = false,
    this.onChanged,
    this.onSubmitted,
    this.textInputAction,
    this.enabled = true,
  });

  final String name;
  final String label;
  final TextEditingController controller;
  final String? unit;
  final String? error;
  final FocusNode? focusNode;
  final bool decimal;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final TextInputAction? textInputAction;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final hasError = error != null;
    final theme = Theme.of(context).inputDecorationTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          label: label,
          textField: true,
          child: TextField(
            key: K.field(name),
            controller: controller,
            focusNode: focusNode,
            enabled: enabled,
            onChanged: onChanged,
            onSubmitted: onSubmitted,
            textInputAction: textInputAction,
            textAlign: TextAlign.right,
            style: IronlyText.body.copyWith(
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
            cursorColor: t.accent,
            keyboardType: TextInputType.numberWithOptions(decimal: decimal),
            inputFormatters: [
              if (decimal) ...[
                FilteringTextInputFormatter.allow(RegExp('[0-9.,]')),
                CommaFormatter(),
              ] else
                FilteringTextInputFormatter.digitsOnly,
            ],
            decoration: InputDecoration(
              prefixIcon: Padding(
                padding: const EdgeInsets.only(left: 12, right: 8),
                child: Text(
                  label,
                  style: IronlyText.body.copyWith(color: t.textSecondary),
                ),
              ),
              prefixIconConstraints: const BoxConstraints(minHeight: 0),
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
              child: Text(
                error!,
                key: K.fieldError(name),
                style: IronlyText.error,
              ),
            ),
          ),
      ],
    );
  }
}

/// Một ô số lớn (04 Bản 4 S-41: số 30 / 600 giữa, viền 1,5 cam, đơn vị nhỏ
/// cạnh số). Chạm vào số để gõ; cũng dùng cho ô của bảng ghi tạ (26 / 600).
class BigNumberField extends StatelessWidget {
  const BigNumberField({
    super.key,
    required this.name,
    required this.controller,
    required this.unit,
    this.focusNode,
    this.active = false,
    this.gray = false,
    this.decimal = true,
    this.onChanged,
    this.style,
    this.height = 64,
    this.semanticsLabel,
    this.enabled = true,
    this.background,
  });

  final String name;
  final TextEditingController controller;
  final String? unit;
  final FocusNode? focusNode;

  /// Ô đang nhập: viền cam.
  final bool active;

  /// Số điền sẵn: mờ.
  final bool gray;
  final bool decimal;
  final ValueChanged<String>? onChanged;
  final TextStyle? style;
  final double height;
  final String? semanticsLabel;
  final bool enabled;

  /// Nền ô; mặc định màu thẻ (trong bảng trượt nền thẻ dùng `surfaceRaised`).
  final Color? background;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final numberStyle = (style ?? IronlyText.number).copyWith(
      color: gray ? t.textPrefill : t.textPrimary,
      fontWeight: gray ? FontWeight.w400 : null,
    );
    final boxHeight = MediaQuery.textScalerOf(
      context,
    ).scale(height * 0.6).clamp(height, height * 2).toDouble();
    return Container(
      height: boxHeight,
      decoration: BoxDecoration(
        color: background ?? t.surface,
        borderRadius: BorderRadius.circular(TokenRadius.field),
        border: Border.all(
          color: active ? t.accent : TokenColor.transparent,
          width: TokenSize.fieldStroke,
        ),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          ExcludeSemantics(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: ListenableBuilder(
                  listenable: controller,
                  builder: (context, _) => Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        controller.text.isEmpty ? '—' : controller.text,
                        key: ValueKey('$name-value'),
                        style: controller.text.isEmpty
                            ? numberStyle.copyWith(
                                color: t.textPrefill,
                                fontWeight: FontWeight.w400,
                              )
                            : numberStyle,
                      ),
                      if (unit != null) ...[
                        const SizedBox(width: 4),
                        Text(unit!, style: IronlyText.caption),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
          // Ô nhập trong suốt phủ lên: chạm con số để gõ.
          Positioned.fill(
            child: Semantics(
              label: semanticsLabel,
              child: TextField(
                key: K.field(name),
                controller: controller,
                focusNode: focusNode,
                onChanged: onChanged,
                enabled: enabled,
                textAlign: TextAlign.center,
                showCursor: false,
                enableInteractiveSelection: false,
                style: numberStyle.copyWith(color: TokenColor.transparent),
                keyboardType: TextInputType.numberWithOptions(decimal: decimal),
                inputFormatters: [
                  if (decimal) ...[
                    FilteringTextInputFormatter.allow(RegExp('[0-9.,]')),
                    CommaFormatter(),
                  ] else
                    FilteringTextInputFormatter.digitsOnly,
                ],
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  disabledBorder: InputBorder.none,
                  filled: false,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
