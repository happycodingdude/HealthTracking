import 'package:flutter/material.dart';

import '../keys.dart';
import '../theme.dart';

/// Cỡ chữ của thông báo nhanh chỉ phóng tối đa ngần này lần.
const toastMaxTextScale = 2.0;

/// Thông báo nhanh (04 Bản 4 §6.1): thẻ nổi, chữ trắng, đáy màn, 3 giây;
/// nội dung như Bản 3. Có thể kèm 1 nút ([action]). [next] = hiện sau thông
/// báo đang có.
void showToast(
  BuildContext context,
  String message, {
  String? action,
  VoidCallback? onAction,
  bool next = false,
}) {
  final messenger = ScaffoldMessenger.of(context);
  if (!next) messenger.clearSnackBars();
  messenger.showSnackBar(
    SnackBar(
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 3),
      content: MediaQuery.withClampedTextScaling(
        maxScaleFactor: toastMaxTextScale,
        child: Builder(
          builder: (context) {
            final t = context.tokens;
            final text = Text(
              message,
              style: IronlyText.body.copyWith(color: t.textPrimary),
            );
            if (action == null) return text;
            final button = TextButton(
              key: K.toastAction,
              style: TextButton.styleFrom(
                foregroundColor: t.accent,
                textStyle: IronlyText.button,
              ),
              onPressed: () {
                messenger.hideCurrentSnackBar();
                onAction?.call();
              },
              child: Text(action),
            );
            return MediaQuery.textScalerOf(context).scale(1) >= 1.6
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      text,
                      Align(alignment: Alignment.centerRight, child: button),
                    ],
                  )
                : Row(
                    children: [
                      Expanded(child: text),
                      const SizedBox(width: 8),
                      button,
                    ],
                  );
          },
        ),
      ),
    ),
  );
}
