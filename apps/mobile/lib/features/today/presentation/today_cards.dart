import 'dart:async';

import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/shell/app_tab.dart';
import '../../../app/strings_vi.dart';
import '../../../core/formatters.dart';
import '../../../ui/components/components.dart';
import '../../../ui/theme.dart';
import '../../menu/application/menu_generator.dart';
import '../../menu/application/menu_view.dart';
import '../../menu/presentation/menu_screen.dart';
import '../../schedule/presentation/extra_session_sheet.dart';
import '../../schedule/presentation/weekly_schedule_screen.dart';
import '../application/today_screen_state.dart';
import 'week_progress_screen.dart';

/// H1 — chưa có lịch (04 Bản 4 S-10): thẻ chỉ có icon lịch + nút cam "Xếp
/// lịch tuần" → S-22. Không câu nào.
class NoScheduleCard extends StatelessWidget {
  const NoScheduleCard({super.key});

  @override
  Widget build(BuildContext context) => EmptyAction(
    key: const ValueKey('no-schedule-card'),
    icon: Icons.calendar_month_outlined,
    action: IronlyButton.primary(
      key: const ValueKey('arrange-weekly'),
      label: S.arrangeWeekly,
      onPressed: () => context.push(weeklySchedulePath),
    ),
  );
}

/// H2 — thẻ Nghỉ (04 Bản 4 S-10): icon lịch tròn, "Nghỉ" chữ phụ 600, dòng
/// "Thứ · Nhóm cơ · giờ" của buổi tới; nút nhỏ phụ "+ Buổi thêm" → S-24
/// (ẩn ở chủ nhật và khi không thêm được).
class RestCard extends StatelessWidget {
  const RestCard({super.key, required this.state});

  final TodayScreenState state;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final next = state.next;
    final stacked = MediaQuery.textScalerOf(context).scale(1) >= 1.6;
    final info = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          S.rest,
          key: const ValueKey('rest-title'),
          style: IronlyText.body.copyWith(
            fontWeight: FontWeight.w600,
            color: t.textSecondary,
          ),
        ),
        if (next != null)
          Text(
            S.nextSessionShort(
              Fmt.weekday(next.date),
              Fmt.musclesTitle(next.muscles),
              Fmt.time(next.time!),
            ),
            key: const ValueKey('next-session'),
            style: IronlyText.body,
          ),
      ],
    );
    final add = state.canAddExtra
        ? IronlyButton.secondary(
            key: const ValueKey('extra-log'),
            label: S.extraSessionButton,
            small: true,
            expand: false,
            onPressed: () => showExtraSessionSheet(context, state.today),
          )
        : null;
    return IronlyCard(
      key: const ValueKey('rest-card'),
      child: Row(
        children: [
          const CircleIcon(Icons.calendar_today_outlined),
          const SizedBox(width: TokenSpace.s3),
          Expanded(
            child: stacked && add != null
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      info,
                      const SizedBox(height: TokenSpace.s2),
                      add,
                    ],
                  )
                : info,
          ),
          if (!stacked && add != null) ...[
            const SizedBox(width: TokenSpace.s2),
            add,
          ],
        ],
      ),
    );
  }
}

/// H2 — thẻ "Tuần này" (04 Bản 4 S-10): n / m (n cam) + dải 6 vòng T2 → T7
/// với dấu hiệu từng ngày (03 Bản 4 §6.4). Chạm → S-25.
class WeekCard extends StatelessWidget {
  const WeekCard({super.key, required this.progress, required this.today});

  final WeeklyProgress? progress;
  final LocalDate today;

  /// Dấu hiệu và nhãn VoiceOver của một ngày trên dải tuần.
  static (GlyphStatus, String) glyphOf(ProgressDay d) {
    final status = d.status;
    if (status != null) {
      return switch (status.state) {
        SessionState.done => (GlyphStatus.done, S.sessionDone),
        SessionState.awaitingMark => (GlyphStatus.pending, S.statusAwaiting),
        SessionState.upcoming => (GlyphStatus.upcoming, S.statusUpcoming),
        SessionState.skipped => (GlyphStatus.skipped, S.sessionSkipped),
        SessionState.autoSkipped => (GlyphStatus.skipped, S.statusAutoSkipped),
      };
    }
    if (d.extra != null) return (GlyphStatus.extra, S.extraSession);
    return (GlyphStatus.rest, S.rest);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final p = progress;
    if (p == null) return const SizedBox.shrink();
    return IronlyCard(
      key: const ValueKey('week-card'),
      onTap: () => context.push(weekProgressPath(AppTab.today, p.week)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: Text(S.thisWeek, style: IronlyText.cardTitle)),
              Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: '${p.done}',
                      style: TextStyle(color: t.accent),
                    ),
                    TextSpan(text: ' / ${p.planned}'),
                  ],
                ),
                key: const ValueKey('week-ratio'),
                style: IronlyText.body.copyWith(
                  fontWeight: FontWeight.w600,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
          const SizedBox(height: TokenSpace.s4),
          WeekStrip(
            days: [
              for (final d in p.days)
                () {
                  final (g, label) = glyphOf(d);
                  return (
                    dateKey: d.date.toKey(),
                    label: S.weekdaysShort[d.date.weekday - 1],
                    status: g,
                    semantics: '${Fmt.weekday(d.date)}: $label',
                    highlighted: d.date == today,
                  );
                }(),
            ],
          ),
        ],
      ),
    );
  }
}

/// H1, H2 — thẻ Thực đơn đầy đủ (04 Bản 4 S-10): "Thực đơn" + kcal, ba dòng
/// Sáng / Trưa / Tối (tên bữa chữ phụ, món trắng, cắt "…"); chạm → tab Thực
/// đơn. Trống: nút "Gợi ý thực đơn" + "Còn n lượt"; đang tạo: khung chờ +
/// "Đang lên thực đơn…"; không mạng / chạm trần / hết lượt: banner câu nguyên
/// văn (F08-E1 → E3).
class MenuCard extends ConsumerWidget {
  const MenuCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final view = ref.watch(menuViewProvider);
    if (view == null) return const SizedBox.shrink();
    final t = context.tokens;
    void openMenu() => context.go(AppTab.menu.path);
    final menu = view.menu;
    final reason = view.generating || menu != null
        ? null
        : view.blocked
        ? S.budgetPaused(view.nextMonth)
        : view.exhausted
        ? S.menuQuotaExhausted
        : view.issue == MenuIssue.offline
        ? S.offlineMenu
        : null;
    final List<Widget> body;
    if (view.generating) {
      body = [
        const SkeletonLines(lines: 3),
        const SizedBox(height: TokenSpace.s3),
        Text(
          S.menuGenerating,
          key: const ValueKey('menu-card-generating'),
          style: IronlyText.caption,
        ),
      ];
    } else if (menu != null) {
      body = [
        // Ba dòng Sáng / Trưa / Tối (04 Bản 4 S-10); bữa phụ xem ở S-30.
        for (final (meal, snack) in menu.ordered)
          if (meal.type != MealType.snack)
            Padding(
              padding: const EdgeInsets.only(top: TokenSpace.s2),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 52,
                    child: Text(
                      mealLabel(meal, snack),
                      style: IronlyText.caption,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      [for (final d in meal.dishes) d.name].join(', '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: IronlyText.body,
                    ),
                  ),
                ],
              ),
            ),
      ];
    } else if (reason != null) {
      body = [
        const SizedBox(height: TokenSpace.s2),
        IronlyBanner(key: const ValueKey('menu-card-reason'), text: reason),
      ];
    } else {
      body = [
        const SizedBox(height: TokenSpace.s2),
        EmptyAction(
          inCard: false,
          icon: Icons.soup_kitchen_outlined,
          action: IronlyButton.primary(
            key: const ValueKey('menu-card-generate'),
            label: S.generateMenuShort,
            onPressed: () {
              unawaited(ref.read(menuGeneratorProvider.notifier).generate());
              openMenu();
            },
          ),
          caption: S.remainingShort(view.remaining),
        ),
      ];
    }
    return IronlyCard(
      key: const ValueKey('menu-card'),
      onTap: openMenu,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: Text(S.tabMenu, style: IronlyText.cardTitle)),
              Text(
                Fmt.kcal(view.totalKcal ?? menu?.totalKcal ?? view.targetKcal),
                key: const ValueKey('menu-card-total'),
                style: IronlyText.caption.copyWith(color: t.textSecondary),
              ),
            ],
          ),
          ...body,
        ],
      ),
    );
  }
}

/// H3 → H6 — thực đơn thu một dòng: "Thực đơn · 1.850 kcal ›" → tab Thực đơn.
class MenuLine extends ConsumerWidget {
  const MenuLine({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final view = ref.watch(menuViewProvider);
    if (view == null) return const SizedBox.shrink();
    final t = context.tokens;
    final menu = view.menu;
    return IronlyCard(
      key: const ValueKey('menu-line'),
      onTap: () => context.go(AppTab.menu.path),
      padding: const EdgeInsets.symmetric(
        horizontal: TokenSize.cardPadding,
        vertical: TokenSpace.s3,
      ),
      child: Row(
        children: [
          Expanded(child: Text(S.tabMenu, style: IronlyText.body)),
          Text(
            Fmt.kcal(view.totalKcal ?? menu?.totalKcal ?? view.targetKcal),
            key: const ValueKey('menu-card-total'),
            style: IronlyText.caption.copyWith(color: t.textSecondary),
          ),
          const SizedBox(width: TokenSpace.s1),
          Icon(Icons.chevron_right, size: 18, color: t.textSecondary),
        ],
      ),
    );
  }
}
