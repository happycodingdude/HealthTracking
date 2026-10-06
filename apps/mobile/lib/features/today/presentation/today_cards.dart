import 'dart:async';

import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/shell/app_tab.dart';
import '../../../app/strings_vi.dart';
import '../../../app/theme.dart';
import '../../../app/time_ticker.dart';
import '../../../core/formatters.dart';
import '../../../core/widgets/heading.dart';
import '../../../core/widgets/reference_tag.dart';
import '../../../core/widgets/session_tag.dart';
import '../../menu/application/menu_generator.dart';
import '../../menu/application/menu_view.dart';
import '../../menu/presentation/menu_screen.dart';
import '../../schedule/application/schedule_providers.dart';
import '../../schedule/presentation/day_sheet.dart';
import '../../schedule/presentation/extra_session_sheet.dart';
import '../../schedule/presentation/mark_session_sheet.dart';
import '../application/progress_view.dart';
import '../application/today_view.dart';
import 'quick_mark.dart';
import 'week_progress_screen.dart';

/// Từ mức phóng chữ này trở lên, các nút và cột xếp dọc (UX-AC18).
const _stackedScale = 1.6;

bool _stacked(BuildContext context) =>
    MediaQuery.textScalerOf(context).scale(1) >= _stackedScale;

/// Thẻ ở Hôm nay (04 §6.13.1): bo góc, viền mảnh, tiêu đề nhỏ, tối đa 1 nút
/// chính.
class TodayCard extends StatelessWidget {
  const TodayCard({
    super.key,
    required this.title,
    this.trailing,
    this.onTap,
    required this.children,
  });

  final String title;
  final Widget? trailing;

  /// Chạm cả thẻ (ví dụ thẻ tiến độ → S-25).
  final VoidCallback? onTap;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final content = Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 8,
            children: [
              Text(
                title,
                style: context.text.titleMedium?.copyWith(
                  color: context.palette.textSecondary,
                ),
              ),
              ?trailing,
            ],
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
    if (onTap == null) return Card(child: content);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(onTap: onTap, child: content),
    );
  }
}

/// "Đã tập" (nút chính) · "Không tập" (nút phụ cùng kích thước, 04 §6.7.1).
class MarkButtons extends StatelessWidget {
  const MarkButtons({
    super.key,
    required this.day,
    required this.onDone,
    required this.onSkipped,
    this.compact = false,
  });

  final PlanDay day;
  final VoidCallback onDone;
  final VoidCallback onSkipped;

  /// Nút nhỏ trong danh sách buổi chưa đánh dấu (04 §6.7.2).
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final key = day.date.toKey();
    final padding = compact ? const EdgeInsets.symmetric(horizontal: 16) : null;
    final done = FilledButton(
      key: ValueKey('mark-done-$key'),
      style: FilledButton.styleFrom(padding: padding),
      onPressed: onDone,
      child: const Text(S.sessionDone, textAlign: TextAlign.center),
    );
    final skipped = OutlinedButton(
      key: ValueKey('mark-skipped-$key'),
      style: OutlinedButton.styleFrom(padding: padding),
      onPressed: onSkipped,
      child: const Text(S.sessionSkipped, textAlign: TextAlign.center),
    );
    if (_stacked(context)) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [done, const SizedBox(height: 8), skipped],
      );
    }
    if (compact) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [done, const SizedBox(width: 8), skipped],
      );
    }
    return Row(
      children: [
        Expanded(child: done),
        const SizedBox(width: 12),
        Expanded(child: skipped),
      ],
    );
  }
}

/// Liên kết chữ (nút phụ dạng chữ, căn trái).
class _Link extends StatelessWidget {
  const _Link({required this.id, required this.label, required this.onTap});

  final Key id;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.centerLeft,
    child: TextButton(
      key: id,
      style: TextButton.styleFrom(
        padding: EdgeInsets.zero,
        alignment: Alignment.centerLeft,
        textStyle: context.text.titleMedium,
      ),
      onPressed: onTap,
      child: Text(label),
    ),
  );
}

/// Thẻ buổi tập hôm nay (04 §6.7.1).
class SessionCard extends ConsumerWidget {
  const SessionCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = ref.watch(nowProvider);
    final today = LocalDate.fromDateTime(now);
    final async = ref.watch(dayProvider(today));
    if (!async.hasValue) return const SizedBox.shrink();
    final day = async.value;
    final next = ref.watch(nextSessionProvider);
    final status = day == null ? null : SessionStatus.derive(day, now);
    final title = context.text.headlineSmall?.copyWith(
      fontWeight: FontWeight.w700,
    );
    final secondary = context.text.bodyLarge?.copyWith(
      color: context.palette.textSecondary,
    );

    Widget nextLine() => next == null
        ? const SizedBox.shrink()
        : Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              S.nextSession(
                Fmt.weekday(next.date),
                Fmt.muscles(next.muscles),
                Fmt.time(next.time!),
              ),
              style: secondary,
            ),
          );

    if (day == null || status == null) {
      // Ngày nghỉ thứ 2 → thứ 7, hoặc chủ nhật (FR-21): ghi buổi tập thêm
      // (F05-R7, F05-E6). Ngày chưa có lịch (trước ngày thiết lập) thì không.
      final extra = day?.extraMuscles;
      final canLog = day != null && ExtraSessionRules.canLog(day, now);
      return TodayCard(
        key: const ValueKey('session-card'),
        title: S.todaySessionTitle,
        children: [
          if (extra != null) ...[
            Heading(S.extraSessionLine(Fmt.muscles(extra)), style: title),
            if (canLog) ...[
              const SizedBox(height: 4),
              _Link(
                id: const ValueKey('extra-edit'),
                label: S.edit,
                onTap: () => showExtraSessionSheet(context, today),
              ),
            ],
          ] else ...[
            Heading(today.isSunday ? S.sundayRest : S.todayRest, style: title),
            nextLine(),
            if (canLog) ...[
              const SizedBox(height: 4),
              _Link(
                id: const ValueKey('extra-log'),
                label: S.logExtraSession,
                onTap: () => showExtraSessionSheet(context, today),
              ),
            ],
          ],
        ],
      );
    }

    final planned = '${Fmt.muscles(day.muscles)} · ${Fmt.time(day.time!)}';
    return TodayCard(
      key: const ValueKey('session-card'),
      title: S.todaySessionTitle,
      trailing: SessionTag(status),
      children: switch (status.state) {
        SessionState.upcoming => [
          Heading(planned, style: title),
          const SizedBox(height: 8),
          Text(S.markableFrom(Fmt.time(day.time!)), style: secondary),
          // 04 §6.7.1: "Sửa buổi hôm nay" → S-21.
          const SizedBox(height: 4),
          _Link(
            id: const ValueKey('session-edit-today'),
            label: S.editTodaySession,
            onTap: () => showDaySheet(context, day.date),
          ),
        ],
        SessionState.awaitingMark => [
          Heading(planned, style: title),
          const SizedBox(height: 16),
          MarkButtons(
            day: day,
            onDone: () => QuickMark.done(context, ref, day),
            onSkipped: () => QuickMark.skipped(context, ref, day),
          ),
        ],
        SessionState.done => [
          Heading(Fmt.muscles(day.actualMuscles ?? day.muscles), style: title),
          const SizedBox(height: 4),
          _Link(
            id: const ValueKey('session-edit'),
            label: S.edit,
            onTap: () => showMarkSessionSheet(context, day.date),
          ),
        ],
        SessionState.skipped || SessionState.autoSkipped => [
          Heading(planned, style: title),
          const SizedBox(height: 4),
          _Link(
            id: const ValueKey('session-edit'),
            label: S.edit,
            onTap: () => showMarkSessionSheet(context, day.date),
          ),
        ],
      },
    );
  }
}

/// Buổi chưa đánh dấu khác trong tuần (04 §6.7.2, UA-11). Chỉ hiện khi có.
class UnmarkedCard extends ConsumerWidget {
  const UnmarkedCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final days = ref.watch(unmarkedSessionsProvider);
    if (days.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: TodayCard(
        key: const ValueKey('unmarked-card'),
        title: S.unmarkedTitle,
        children: [
          for (final (i, d) in days.indexed) ...[
            if (i > 0) const Divider(height: 24),
            _UnmarkedRow(day: d),
          ],
        ],
      ),
    );
  }
}

class _UnmarkedRow extends ConsumerWidget {
  const _UnmarkedRow({required this.day});

  final PlanDay day;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final info = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          Fmt.weekdayDate(day.date),
          style: context.text.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        Text(
          '${Fmt.muscles(day.muscles)} · ${Fmt.time(day.time!)}',
          style: context.text.bodyLarge?.copyWith(
            color: context.palette.textSecondary,
          ),
        ),
      ],
    );
    final buttons = MarkButtons(
      day: day,
      compact: true,
      onDone: () => QuickMark.done(context, ref, day),
      onSkipped: () => QuickMark.skipped(context, ref, day),
    );
    if (MediaQuery.textScalerOf(context).scale(1) >= 1.3) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [info, const SizedBox(height: 12), buttons],
      );
    }
    return Row(
      children: [
        Expanded(child: info),
        const SizedBox(width: 8),
        buttons,
      ],
    );
  }
}

/// Thẻ tiến độ tuần (04 §6.7.3): "Đã tập X/Y buổi theo lịch", "+Z buổi
/// thêm" (chỉ khi Z > 0), Y = 0 → "Tuần này không có buổi tập theo lịch"
/// (F06-E1); dải 6 ô thứ 2 → thứ 7 tô theo trạng thái (04 §6.13.3). Chạm →
/// S-25. Ở cỡ chữ lớn nhất dải chuyển thành 2 hàng (04 §6.17).
class ProgressCard extends ConsumerWidget {
  const ProgressCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = ref.watch(nowProvider);
    final week = ProgressWeek.containing(LocalDate.fromDateTime(now));
    final progress = ref.watch(weekProgressProvider(week));
    if (progress == null) return const SizedBox.shrink();
    final cells = [for (final d in progress.days) _DayCell(day: d)];
    final main = progress.planned == 0
        ? S.noPlannedSessions
        : S.progressLine(progress.done, progress.planned);
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: TodayCard(
        key: const ValueKey('progress-card'),
        title: S.progressCardTitle,
        trailing: ExcludeSemantics(
          child: Icon(
            Icons.chevron_right,
            color: context.palette.textSecondary,
          ),
        ),
        onTap: () => context.push(weekProgressPath(AppTab.today, week)),
        children: [
          // Con số đổi có hiệu ứng chuyển nhẹ khi đánh dấu (04 §6.7.1).
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            layoutBuilder: (current, previous) => Stack(
              alignment: Alignment.centerLeft,
              children: [...previous, ?current],
            ),
            child: Text(
              main,
              key: ValueKey(main),
              style: context.text.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          if (progress.extra > 0) ...[
            const SizedBox(height: 4),
            Text(
              S.extraCount(progress.extra),
              key: const ValueKey('extra-count'),
              style: context.text.bodyLarge?.copyWith(
                color: context.colors.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          const SizedBox(height: 12),
          if (_stacked(context))
            Column(
              children: [
                Row(children: cells.sublist(0, 3)),
                const SizedBox(height: 12),
                Row(children: cells.sublist(3)),
              ],
            )
          else
            Row(children: cells),
        ],
      ),
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({required this.day});

  final ProgressDay day;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final date = day.date;
    final d = day.day;
    final status = day.status;
    final (Color? fill, Color? border) = switch (status?.state) {
      SessionState.done => (palette.success, null),
      SessionState.awaitingMark => (palette.attention, null),
      SessionState.upcoming => (null, context.colors.outline),
      SessionState.skipped || SessionState.autoSkipped => (
        palette.neutral.withValues(alpha: 0.45),
        null,
      ),
      // Ngày nghỉ: có buổi tập thêm thì xanh ngọc (04 §6.13.3).
      null when d?.extraMuscles != null => (context.colors.primary, null),
      null => (palette.neutralContainer, null),
    };
    final label = status != null
        ? SessionTag.label(status.state)
        : d?.extraMuscles != null
        ? S.extraSession
        : S.rest;
    return Expanded(
      child: Semantics(
        container: true,
        label: '${Fmt.weekday(date)}: $label',
        child: ExcludeSemantics(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Column(
              children: [
                Container(
                  key: ValueKey('week-cell-${date.toKey()}'),
                  height: 14,
                  decoration: BoxDecoration(
                    color: fill,
                    borderRadius: BorderRadius.circular(7),
                    border: border == null ? null : Border.all(color: border),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  S.weekdaysShort[date.weekday - 1],
                  style: context.text.bodyMedium?.copyWith(
                    color: palette.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Thẻ thực đơn hôm nay (04 §6.7.4): mức calo dùng cho thực đơn kèm nhãn
/// "tham khảo" (F02-R6). Nút tạo thực đơn và các trạng thái thêm ở VS-12.
class MenuCard extends ConsumerWidget {
  const MenuCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final view = ref.watch(menuViewProvider);
    if (view == null) return const SizedBox.shrink();
    final palette = context.palette;
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
    final List<Widget> children;
    if (view.generating) {
      children = [
        Text(
          S.menuGenerating,
          key: const ValueKey('menu-card-generating'),
          style: context.text.bodyLarge,
        ),
      ];
    } else if (menu != null) {
      // UR-15: mỗi bữa một dòng, tên bữa bên trái, các món bên phải.
      children = [
        Table(
          columnWidths: const {0: IntrinsicColumnWidth(), 1: FlexColumnWidth()},
          children: [
            for (final (meal, snack) in menu.ordered)
              TableRow(
                children: [
                  Padding(
                    padding: const EdgeInsets.only(right: 16, bottom: 8),
                    child: Text(
                      mealLabel(meal, snack),
                      style: context.text.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      [for (final d in meal.dishes) d.name].join(', '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.text.bodyLarge,
                    ),
                  ),
                ],
              ),
          ],
        ),
        const SizedBox(height: 4),
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 8,
          children: [
            Text(
              Fmt.kcal(view.totalKcal ?? menu.totalKcal),
              key: const ValueKey('menu-card-total'),
              style: context.text.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const ReferenceTag(),
          ],
        ),
      ];
    } else if (reason != null) {
      children = [
        Text(
          reason,
          key: const ValueKey('menu-card-reason'),
          style: context.text.bodyLarge?.copyWith(color: palette.textSecondary),
        ),
      ];
    } else {
      children = [
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 8,
          children: [
            Text.rich(
              TextSpan(
                children: [
                  const TextSpan(text: '${S.menuTargetPrefix} '),
                  TextSpan(
                    text: Fmt.kcal(view.targetKcal),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ],
              ),
              style: context.text.titleMedium,
            ),
            const ReferenceTag(),
          ],
        ),
        const SizedBox(height: 12),
        // Bắt đầu tạo và chuyển sang tab Thực đơn (04 §6.7.4).
        FilledButton(
          key: const ValueKey('menu-card-generate'),
          onPressed: () {
            unawaited(ref.read(menuGeneratorProvider.notifier).generate());
            openMenu();
          },
          child: const Text(S.generateMenu, textAlign: TextAlign.center),
        ),
      ];
    }
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: TodayCard(
        key: const ValueKey('menu-card'),
        title: S.menuCardTitle,
        onTap: openMenu,
        children: children,
      ),
    );
  }
}
