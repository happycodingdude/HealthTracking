import 'package:flutter/material.dart';

import '../../app/shell/app_tab.dart';
import '../keys.dart';
import '../theme.dart';

/// Thanh tab Bản 4 (04 Bản 4 §6.1): 5 mục theo thứ tự gốc Tập luyện · Thực
/// đơn · Hôm nay · Cân nặng · Tôi. Hôm nay là nút tròn 46 nền cam, icon
/// trắng, nổi 24 pt trên thanh, viền 4 pt màu nền. Mục đang chọn: icon + nhãn
/// cam; còn lại chữ phụ. Vạch 0,5 trên thanh.
class IronlyTabBar extends StatelessWidget {
  const IronlyTabBar({
    super.key,
    required this.current,
    required this.onTap,
    this.dots = const {},
  });

  final AppTab current;
  final ValueChanged<AppTab> onTap;

  /// Tab có chấm báo hiệu.
  final Set<AppTab> dots;

  /// Phần nút tròn nhô lên trên mép thanh tab.
  static const protrusion = TokenSize.todayLift;

  /// Nhãn thanh tab chỉ phóng tới mức này, giống thanh tab hệ thống.
  static const maxLabelScale = 1.35;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final bottom = MediaQuery.paddingOf(context).bottom;
    final scale = MediaQuery.textScalerOf(
      context,
    ).clamp(maxScaleFactor: maxLabelScale).scale(1);
    final barHeight = 40 + 14 * scale;

    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: maxLabelScale,
      child: SizedBox(
        key: K.tabBar,
        height: protrusion + barHeight + bottom,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              top: protrusion,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: t.bg,
                  border: Border(
                    top: BorderSide(
                      color: t.divider,
                      width: TokenSize.dividerStroke,
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              top: 0,
              height: protrusion + barHeight,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final tab in AppTab.values)
                    Expanded(
                      child: tab == AppTab.today
                          ? _TodayItem(
                              selected: current == tab,
                              onTap: () => onTap(tab),
                            )
                          : _TabItem(
                              tab: tab,
                              selected: current == tab,
                              dot: dots.contains(tab),
                              onTap: () => onTap(tab),
                            ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TabItem extends StatelessWidget {
  const _TabItem({
    required this.tab,
    required this.selected,
    required this.dot,
    required this.onTap,
  });

  final AppTab tab;
  final bool selected;
  final bool dot;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final color = selected ? t.accent : t.textSecondary;
    return Semantics(
      button: true,
      selected: selected,
      label: tab.label,
      child: ExcludeSemantics(
        child: GestureDetector(
          key: K.tab(tab.name),
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.only(
              top: IronlyTabBar.protrusion + 7,
              bottom: 4,
            ),
            child: Column(
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Icon(_icon(tab), size: 24, color: color),
                    if (dot)
                      Positioned(
                        right: -3,
                        top: -1,
                        child: Container(
                          key: K.tabDot(tab.name),
                          width: TokenSize.dot,
                          height: TokenSize.dot,
                          decoration: BoxDecoration(
                            color: t.accent,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 3),
                Expanded(child: _Label(tab.label, color: color)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static IconData _icon(AppTab tab) => switch (tab) {
    AppTab.schedule => Icons.fitness_center,
    AppTab.menu => Icons.soup_kitchen_outlined,
    AppTab.weight => Icons.monitor_weight_outlined,
    AppTab.me => Icons.person_outline,
    AppTab.today => Icons.calendar_today_outlined,
  };
}

class _TodayItem extends StatelessWidget {
  const _TodayItem({required this.selected, required this.onTap});

  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    const outer = TokenSize.todayButton + TokenSize.todayRing * 2;
    return Semantics(
      button: true,
      selected: selected,
      label: AppTab.today.label,
      child: ExcludeSemantics(
        child: GestureDetector(
          key: K.tabTodayButton,
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Column(
            children: [
              Container(
                width: outer,
                height: outer,
                decoration: BoxDecoration(color: t.bg, shape: BoxShape.circle),
                alignment: Alignment.center,
                child: Container(
                  width: TokenSize.todayButton,
                  height: TokenSize.todayButton,
                  decoration: BoxDecoration(
                    color: t.accent,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    Icons.calendar_today_outlined,
                    size: 22,
                    color: t.onAccent,
                  ),
                ),
              ),
              Expanded(
                child: _Label(
                  AppTab.today.label,
                  color: selected ? t.accent : t.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text, {required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          text,
          maxLines: 1,
          style: IronlyText.tabLabel.copyWith(color: color),
        ),
      ),
    );
  }
}
