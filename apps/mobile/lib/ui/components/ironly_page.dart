import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/shell/app_tab.dart';
import '../../app/shell/tab_scroll.dart';
import '../keys.dart';
import '../theme.dart';

/// Đệm ngang chuẩn của mọi màn.
const pageInset = TokenSpace.s5;

/// Trang của một tab (04 Bản 4): tiêu đề 17 trái, [trailing] phải (dấu trạng
/// thái, ngày, icon); một cột cuộn dọc với `ScrollController` của tab.
class IronlyTabPage extends ConsumerWidget {
  const IronlyTabPage({
    super.key,
    required this.tab,
    required this.title,
    this.trailing,
    this.scrollController,
    this.children = const [],
    this.header,
    this.listKey,
  });

  final AppTab tab;
  final String title;
  final Widget? trailing;
  final ScrollController? scrollController;
  final List<Widget> children;

  /// Dòng nhỏ in hoa phía trên tiêu đề (Thực đơn: "THỨ 2, 26/10").
  final String? header;
  final Key? listKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          key: listKey,
          controller:
              scrollController ??
              ref.watch(tabScrollControllersProvider).of(tab),
          padding: EdgeInsets.fromLTRB(
            pageInset,
            TokenSpace.s3,
            pageInset,
            MediaQuery.paddingOf(context).bottom + 40,
          ),
          children: [
            if (header != null)
              Text(header!.toUpperCase(), style: IronlyText.groupLabel),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Semantics(
                    header: true,
                    child: Text(title, style: IronlyText.title),
                  ),
                ),
                if (trailing != null)
                  KeyedSubtree(key: K.pageTrailing, child: trailing!),
              ],
            ),
            const SizedBox(height: TokenSpace.s4),
            ...children,
          ],
        ),
      ),
    );
  }
}

/// Màn con: nút quay lại trái, tiêu đề 15 / 600 giữa, [trailing] phải; nội
/// dung một cột cuộn. [bottom] ghim đáy (nút Lưu).
class IronlySubPage extends StatelessWidget {
  const IronlySubPage({
    super.key,
    required this.title,
    this.titleWidget,
    this.trailing,
    this.leading,
    this.children = const [],
    this.bottom,
    this.onBack,
    this.scrollController,
    this.listKey,
    this.body,
  });

  final String title;

  /// Thay chữ tiêu đề (ví dụ "‹ 19/10 – 25/10 ›").
  final Widget? titleWidget;
  final Widget? trailing;

  /// Thay nút quay lại.
  final Widget? leading;
  final List<Widget> children;
  final Widget? bottom;
  final VoidCallback? onBack;
  final ScrollController? scrollController;
  final Key? listKey;

  /// Thay danh sách cuộn bằng thân tùy ý.
  final Widget? body;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            SizedBox(
              height: 44,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Positioned.fill(
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 48),
                        child:
                            titleWidget ??
                            Semantics(
                              header: true,
                              child: Text(
                                title,
                                style: IronlyText.subtitle,
                                textAlign: TextAlign.center,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 4,
                    child:
                        leading ??
                        Semantics(
                          button: true,
                          label: MaterialLocalizations.of(
                            context,
                          ).backButtonTooltip,
                          child: ExcludeSemantics(
                            child: GestureDetector(
                              key: K.pageBack,
                              behavior: HitTestBehavior.opaque,
                              onTap: onBack ?? () => context.pop(),
                              child: SizedBox(
                                width: 44,
                                height: 44,
                                child: Icon(
                                  Icons.chevron_left,
                                  size: 26,
                                  color: t.accent,
                                ),
                              ),
                            ),
                          ),
                        ),
                  ),
                  if (trailing != null)
                    Positioned(
                      right: 8,
                      child: KeyedSubtree(
                        key: K.pageTrailing,
                        child: trailing!,
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child:
                  body ??
                  ListView(
                    key: listKey,
                    controller: scrollController,
                    padding: EdgeInsets.fromLTRB(
                      pageInset,
                      TokenSpace.s2,
                      pageInset,
                      (bottom == null ? bottomInset : 0) + TokenSpace.s6,
                    ),
                    children: children,
                  ),
            ),
            if (bottom != null)
              Padding(
                padding: EdgeInsets.fromLTRB(
                  pageInset,
                  TokenSpace.s2,
                  pageInset,
                  bottomInset + TokenSpace.s3,
                ),
                child: bottom,
              ),
          ],
        ),
      ),
    );
  }
}

/// Khoảng cách chuẩn giữa hai thẻ.
class CardGap extends StatelessWidget {
  const CardGap({super.key});

  @override
  Widget build(BuildContext context) =>
      const SizedBox(height: TokenSize.cardGap);
}
