import 'package:flutter/material.dart';

import '../theme.dart';
import 'app_tab.dart';

/// Thanh tab tự vẽ (05 §6.4.3): 5 tab, nút tròn Hôm nay ở giữa nhô lên
/// khoảng 1/3, luôn tô màu chủ đạo và luôn có chữ (UR-02, UA-17, 04 §6.3.2).
class AppTabBar extends StatelessWidget {
  const AppTabBar({
    super.key,
    required this.current,
    required this.onTap,
    this.dots = const {},
  });

  final AppTab current;
  final ValueChanged<AppTab> onTap;

  /// Tab có chấm báo hiệu (04 §6.3.1).
  final Set<AppTab> dots;

  /// Phần nút tròn nhô lên trên mép thanh tab.
  static const protrusion = 20.0;
  static const _circle = 56.0;
  static const _ring = 5.0;

  /// Nhãn thanh tab được giới hạn cỡ chữ, phần dư được thu nhỏ để không bị
  /// cắt (UX-AC18), giống thanh tab hệ thống của iPhone.
  static const maxLabelScale = 1.35;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final bottom = MediaQuery.paddingOf(context).bottom;
    final scale = MediaQuery.textScalerOf(
      context,
    ).clamp(maxScaleFactor: maxLabelScale).scale(1);
    final barHeight = 46 + 18 * scale;

    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: maxLabelScale,
      child: SizedBox(
        height: protrusion + barHeight + bottom,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              top: protrusion,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: palette.card,
                  border: Border(top: BorderSide(color: palette.border)),
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
    final color = selected
        ? context.colors.primary
        : context.palette.textSecondary;
    return Semantics(
      button: true,
      selected: selected,
      label: tab.label,
      child: ExcludeSemantics(
        child: InkResponse(
          onTap: onTap,
          highlightShape: BoxShape.rectangle,
          child: Padding(
            padding: const EdgeInsets.only(
              top: AppTabBar.protrusion + 8,
              bottom: 6,
            ),
            child: Column(
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    _TabIcon(tab: tab, color: color),
                    if (dot)
                      Positioned(
                        right: -3,
                        top: -1,
                        child: Container(
                          key: ValueKey('tab-dot-${tab.name}'),
                          width: 9,
                          height: 9,
                          decoration: BoxDecoration(
                            color: context.palette.attention,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 3),
                Expanded(
                  child: _Label(tab.label, color: color, bold: selected),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TodayItem extends StatelessWidget {
  const _TodayItem({required this.selected, required this.onTap});

  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    const outer = AppTabBar._circle + AppTabBar._ring * 2;
    return Semantics(
      button: true,
      selected: selected,
      label: AppTab.today.label,
      child: ExcludeSemantics(
        child: GestureDetector(
          key: const ValueKey('tab-today-button'),
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Column(
            children: [
              Container(
                width: outer,
                height: outer,
                decoration: BoxDecoration(
                  color: context.palette.card,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Container(
                  width: AppTabBar._circle,
                  height: AppTabBar._circle,
                  decoration: BoxDecoration(
                    color: colors.primary,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    Icons.today_outlined,
                    size: 30,
                    color: colors.onPrimary,
                  ),
                ),
              ),
              Expanded(
                child: _Label(
                  AppTab.today.label,
                  color: selected ? colors.primary : colors.onSurface,
                  bold: true,
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
  const _Label(this.text, {required this.color, required this.bold});

  final String text;
  final Color color;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          text,
          maxLines: 1,
          style: context.text.labelMedium?.copyWith(
            color: color,
            fontSize: 12.5,
            fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

class _TabIcon extends StatelessWidget {
  const _TabIcon({required this.tab, required this.color});

  final AppTab tab;
  final Color color;

  @override
  Widget build(BuildContext context) {
    const size = 26.0;
    return switch (tab) {
      AppTab.schedule => Icon(
        Icons.calendar_month_outlined,
        size: size,
        color: color,
      ),
      // Đĩa ăn (04 §6.3.1).
      AppTab.menu => CustomPaint(
        size: const Size.square(size),
        painter: _PlatePainter(color),
      ),
      AppTab.weight => Icon(
        Icons.monitor_weight_outlined,
        size: size,
        color: color,
      ),
      AppTab.me => Icon(Icons.person_outline, size: size, color: color),
      AppTab.today => Icon(Icons.today_outlined, size: size, color: color),
    };
  }
}

class _PlatePainter extends CustomPainter {
  _PlatePainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    final center = size.center(Offset.zero);
    canvas
      ..drawCircle(center, size.width * 0.42, paint)
      ..drawCircle(center, size.width * 0.24, paint);
  }

  @override
  bool shouldRepaint(_PlatePainter old) => old.color != color;
}
