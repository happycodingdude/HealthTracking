import 'package:flutter/material.dart';

/// Cỡ chữ của thông báo nhanh chỉ phóng tối đa ngần này lần, để thông báo luôn
/// nằm gọn phía trên thanh tab ở cỡ chữ lớn nhất (UX-AC18).
const toastMaxTextScale = 2.0;

/// Thông báo nhanh (04 §6.13.1): ngắn, thì quá khứ, hiện ở cuối màn hình khoảng
/// 4 giây. Có thể kèm 1 nút ([action], ví dụ "Sửa nhóm cơ", "Hoàn tác").
/// [next] = thông báo tiếp theo, hiện sau thông báo đang có (04 S-41: "Đã lưu
/// {X} kg" rồi "Mức calo đã cập nhật…").
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
      duration: const Duration(seconds: 4),
      content: MediaQuery.withClampedTextScaling(
        maxScaleFactor: toastMaxTextScale,
        child: Builder(
          builder: (context) {
            final text = Text(message);
            if (action == null) return text;
            final button = TextButton(
              key: const ValueKey('toast-action'),
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.inversePrimary,
                textStyle: Theme.of(
                  context,
                ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
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
