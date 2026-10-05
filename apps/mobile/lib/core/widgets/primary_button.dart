import 'package:flutter/material.dart';

/// Nút chính (04 §6.13.1). [loading] = true: hiện vòng xoay nhỏ, không bấm lặp
/// được (S-01b), vẫn giữ màu để không giống nút bị khóa.
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
  });

  final String label;
  final VoidCallback onPressed;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final onPrimary = Theme.of(context).colorScheme.onPrimary;
    return Semantics(
      button: true,
      label: label,
      enabled: !loading,
      child: ExcludeSemantics(
        child: FilledButton(
          onPressed: loading ? () {} : onPressed,
          child: loading
              ? SizedBox.square(
                  key: const ValueKey('button-spinner'),
                  dimension: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: onPrimary,
                  ),
                )
              : Text(label, textAlign: TextAlign.center),
        ),
      ),
    );
  }
}
