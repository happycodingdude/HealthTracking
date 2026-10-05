import 'package:flutter/material.dart';

/// Thông báo nhanh (04 §6.13.1): ngắn, thì quá khứ, hiện ở cuối màn hình khoảng
/// 4 giây.
void showToast(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
      ),
    );
}
