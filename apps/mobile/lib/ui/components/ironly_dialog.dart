import 'package:flutter/material.dart';

import '../keys.dart';
import '../theme.dart';
import 'ironly_button.dart';

/// Hộp xác nhận (04 Bản 4 §6.1): giữa màn, bo 16, đệm 18 / 16; tiêu đề 15 /
/// 600, câu 13 chữ phụ; hai nút ngang, nút phải là hành động chính (cam) hoặc
/// hành động xóa (đỏ). Câu chữ giữ nguyên Bản 1 → 3 (FR4-03).
class IronlyDialog extends StatelessWidget {
  const IronlyDialog({
    super.key,
    required this.title,
    this.body,
    this.secondaryLabel,
    this.onSecondary,
    this.primaryLabel,
    this.onPrimary,
    this.destructive = false,
    this.primaryLoading = false,
    this.child,
    this.primaryKey = K.dialogPrimary,
    this.secondaryKey = K.dialogSecondary,
  });

  final String title;
  final String? body;

  /// Nội dung thêm giữa câu và nút (vòng xoay, danh sách…).
  final Widget? child;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;
  final String? primaryLabel;
  final VoidCallback? onPrimary;

  /// Nút phải màu đỏ nền (Đăng xuất, Xóa).
  final bool destructive;
  final bool primaryLoading;
  final Key primaryKey;
  final Key secondaryKey;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final stacked = MediaQuery.textScalerOf(context).scale(1) >= 1.6;
    final buttons = <Widget>[
      if (secondaryLabel != null)
        IronlyButton.gray(
          key: secondaryKey,
          label: secondaryLabel!,
          onPressed: onSecondary,
        ),
      if (primaryLabel != null)
        destructive
            ? _DangerFilled(
                key: primaryKey,
                label: primaryLabel!,
                onPressed: onPrimary,
              )
            : IronlyButton.primary(
                key: primaryKey,
                label: primaryLabel!,
                onPressed: onPrimary,
                loading: primaryLoading,
              ),
    ];
    return Dialog(
      key: K.dialog,
      backgroundColor: t.surface,
      insetPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(TokenRadius.dialog),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              header: true,
              child: Text(title, style: IronlyText.dialogTitle),
            ),
            if (body != null) ...[
              const SizedBox(height: TokenSpace.s2),
              Text(body!, style: IronlyText.dialogBody),
            ],
            if (child != null) ...[const SizedBox(height: 14), child!],
            if (buttons.isNotEmpty) ...[
              const SizedBox(height: 18),
              if (stacked || buttons.length == 1)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final (i, b) in buttons.indexed) ...[
                      if (i > 0) const SizedBox(height: TokenSpace.s2),
                      b,
                    ],
                  ],
                )
              else
                Row(
                  children: [
                    for (final (i, b) in buttons.indexed) ...[
                      if (i > 0) const SizedBox(width: TokenSpace.s3),
                      Expanded(child: b),
                    ],
                  ],
                ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Nút đỏ nền cho hành động xóa / đăng xuất trong hộp (mock S-73).
class _DangerFilled extends StatelessWidget {
  const _DangerFilled({
    super.key,
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final radius = BorderRadius.circular(TokenRadius.button);
    return Semantics(
      button: true,
      enabled: onPressed != null,
      label: label,
      child: ExcludeSemantics(
        child: Opacity(
          opacity: onPressed == null ? IronlyButton.disabledOpacity : 1,
          child: Material(
            color: t.danger,
            borderRadius: radius,
            child: InkWell(
              borderRadius: radius,
              onTap: onPressed,
              child: Container(
                constraints: const BoxConstraints(minHeight: TokenSize.button),
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(
                  horizontal: TokenSpace.s5,
                  vertical: TokenSpace.s2,
                ),
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: IronlyText.button.copyWith(color: t.onAccent),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
