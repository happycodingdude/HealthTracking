import 'package:flutter/material.dart';

import '../keys.dart';
import '../theme.dart';

/// Mở bảng trượt từ dưới lên (04 Bản 4 §6.1): nền thẻ, bo 22 trên, thanh kéo
/// 36 × 4, nền sau phủ mờ 55 %. Vuốt xuống hoặc chạm vùng mờ để đóng.
/// Bảng có ô nhập dùng [enableDrag] = false kèm `UnsavedChangesGuard`.
Future<T?> showIronlySheet<T>(
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
    barrierColor: context.tokens.scrim,
    builder: (sheetContext) => Padding(
      // Giữ nội dung và nút phía trên bàn phím.
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(sheetContext).bottom,
      ),
      child: SafeArea(top: false, child: builder(sheetContext)),
    ),
  );
}

/// Mở hộp xác nhận; trang phía sau phủ mờ. [barrierDismissible] = false với
/// hộp không có nút (đang đồng bộ).
Future<T?> showIronlyDialog<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  bool barrierDismissible = true,
}) {
  return showDialog<T>(
    context: context,
    useRootNavigator: true,
    barrierColor: context.tokens.scrim,
    barrierDismissible: barrierDismissible,
    builder: builder,
  );
}

/// Thân bảng trượt: thanh kéo, [title] 15 / 600 (tùy chọn), nội dung cuộn,
/// [footer] ghim đáy (nút Lưu luôn trên bàn phím).
class IronlySheet extends StatelessWidget {
  const IronlySheet({
    super.key,
    this.title,
    this.titleTrailing,
    required this.children,
    this.footer,
    this.scrollController,
    this.padding = const EdgeInsets.fromLTRB(
      TokenSpace.s5,
      0,
      TokenSpace.s5,
      TokenSpace.s2,
    ),
  });

  final String? title;
  final Widget? titleTrailing;
  final List<Widget> children;
  final Widget? footer;
  final ScrollController? scrollController;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Column(
      key: K.sheet,
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: Container(
            margin: const EdgeInsets.only(top: TokenSpace.s2, bottom: 14),
            width: TokenSize.sheetHandleWidth,
            height: TokenSize.sheetHandleHeight,
            decoration: BoxDecoration(
              color: t.textFaint,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        Flexible(
          child: SingleChildScrollView(
            controller: scrollController,
            padding: padding,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (title != null) ...[
                  Row(
                    children: [
                      Expanded(
                        child: Semantics(
                          header: true,
                          child: Text(title!, style: IronlyText.subtitle),
                        ),
                      ),
                      ?titleTrailing,
                    ],
                  ),
                  const SizedBox(height: TokenSpace.s4),
                ],
                ...children,
              ],
            ),
          ),
        ),
        if (footer != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              TokenSpace.s5,
              TokenSpace.s2,
              TokenSpace.s5,
              TokenSpace.s5,
            ),
            child: footer,
          ),
      ],
    );
  }
}
