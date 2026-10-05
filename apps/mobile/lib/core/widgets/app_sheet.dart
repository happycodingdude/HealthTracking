import 'package:flutter/material.dart';

import '../../app/theme.dart';

/// Mở bảng trượt từ dưới lên (NAV-5). Trang phía sau giữ nguyên nội dung, chỉ
/// phủ lớp mờ (UR-16). Vuốt xuống hoặc chạm vùng mờ để đóng.
///
/// Bảng có ô nhập dùng [enableDrag] = false kèm `UnsavedChangesGuard` để hỏi
/// trước khi bỏ thay đổi chưa lưu.
Future<T?> showAppSheet<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  bool isDismissible = true,
  bool enableDrag = true,
}) {
  return showModalBottomSheet<T>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    useSafeArea: true,
    isDismissible: isDismissible,
    enableDrag: isDismissible && enableDrag,
    barrierColor: context.palette.scrim,
    builder: (sheetContext) => Padding(
      // Giữ nội dung và nút phía trên bàn phím (04 §6.17).
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(sheetContext).bottom,
      ),
      child: SafeArea(top: false, child: builder(sheetContext)),
    ),
  );
}

/// Mở hộp thoại; trang phía sau giữ nguyên, chỉ phủ lớp mờ (UR-16).
Future<T?> showAppDialog<T>(
  BuildContext context, {
  required WidgetBuilder builder,
}) {
  return showDialog<T>(
    context: context,
    useRootNavigator: true,
    barrierColor: context.palette.scrim,
    builder: builder,
  );
}
