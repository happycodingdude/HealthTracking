import 'package:flutter/material.dart';

import '../theme.dart';

/// Công tắc 44 × 26, bo 13: bật cam, tắt thẻ nổi (04 Bản 4 §6.1).
class IronlySwitch extends StatelessWidget {
  const IronlySwitch({
    super.key,
    required this.value,
    required this.onChanged,
    this.label,
  });

  final bool value;
  final ValueChanged<bool>? onChanged;

  /// Nhãn VoiceOver.
  final String? label;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final enabled = onChanged != null;
    return Semantics(
      toggled: value,
      enabled: enabled,
      label: label,
      child: ExcludeSemantics(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: enabled ? () => onChanged!(!value) : null,
          child: Opacity(
            opacity: enabled ? 1 : 0.4,
            child: AnimatedContainer(
              duration: MediaQuery.disableAnimationsOf(context)
                  ? Duration.zero
                  : const Duration(milliseconds: 150),
              width: TokenSize.switchWidth,
              height: TokenSize.switchHeight,
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: value ? t.accent : t.surfaceRaised,
                borderRadius: BorderRadius.circular(TokenRadius.switchTrack),
              ),
              alignment: value ? Alignment.centerRight : Alignment.centerLeft,
              child: Container(
                width: TokenSize.switchHeight - 4,
                height: TokenSize.switchHeight - 4,
                decoration: BoxDecoration(
                  color: t.textPrimary,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
