import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/shell/app_tab.dart';
import '../../app/shell/tab_scroll.dart';
import '../../app/theme.dart';
import 'heading.dart';

/// Bố cục chung của một tab: tiêu đề lớn, một cột, cuộn dọc, có
/// [ScrollController] riêng của tab (NAV-3, NAV-8).
class TabPage extends ConsumerWidget {
  const TabPage({
    super.key,
    required this.tab,
    required this.title,
    this.subtitle,
    this.trailing,
    this.children = const [],
  });

  final AppTab tab;
  final String title;

  /// Dòng nhỏ phía trên tiêu đề (ví dụ lời chào ở Hôm nay).
  final String? subtitle;

  /// Thành phần ở góc phải tiêu đề (ví dụ chỉ báo "Chưa đồng bộ").
  final Widget? trailing;

  final List<Widget> children;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          controller: ref.watch(tabScrollControllersProvider).of(tab),
          padding: EdgeInsets.fromLTRB(
            16,
            24,
            16,
            MediaQuery.paddingOf(context).bottom + 24,
          ),
          children: [
            if (subtitle != null)
              Text(
                subtitle!,
                style: context.text.titleMedium?.copyWith(
                  color: context.palette.textSecondary,
                ),
              ),
            // Tiêu đề và thành phần bên phải; không đủ chỗ (cỡ chữ lớn) thì
            // thành phần bên phải xuống dòng, không ép tiêu đề (UX-AC18).
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.end,
              spacing: 12,
              runSpacing: 8,
              children: [
                Heading(
                  title,
                  style: context.text.displaySmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                ?trailing,
              ],
            ),
            const SizedBox(height: 20),
            ...children,
          ],
        ),
      ),
    );
  }
}
