import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/shell/app_tab.dart';
import '../../../app/strings_vi.dart';
import '../../../app/theme.dart';
import '../../../app/time_ticker.dart';
import '../../../core/formatters.dart';
import '../../../core/widgets/app_sheet.dart';
import '../../../core/widgets/tab_page.dart';
import '../../../core/widgets/toast.dart';
import '../../today/application/progress_view.dart';
import '../../today/presentation/week_progress_screen.dart';
import '../application/schedule_edits.dart';
import '../application/schedule_providers.dart';
import 'day_line.dart';
import 'day_sheet.dart';
import 'weekly_schedule_screen.dart';

/// S-20 — Lịch tháng, chế độ xem (VS04-T11). Danh sách ngày nhóm theo tuần,
/// hôm nay được làm nổi bật và tự cuộn tới khi mở tab; xem được các tháng
/// trước, không có tháng sau trước ngày 1 (F03-R13). Mỗi buổi tập có nhãn
/// trạng thái (04 §6.13.3, VS06-T08). Nút "Lịch tuần" → S-22; banner Chia lại
/// khi lịch tuần đã đổi; chạm một ngày → S-21 (VS-09).
class ScheduleScreen extends ConsumerStatefulWidget {
  const ScheduleScreen({super.key});

  @override
  ConsumerState<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends ConsumerState<ScheduleScreen> {
  /// null = tháng hiện tại.
  YearMonth? _shown;
  final _todayKey = GlobalKey();
  bool _scrolledToToday = false;

  void _scrollToToday() {
    if (_scrolledToToday) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final target = _todayKey.currentContext;
      if (target == null || !target.mounted || _scrolledToToday) return;
      _scrolledToToday = true;
      // Chỉ cuộn khi hôm nay còn khuất phía dưới. Nội dung trang kéo dài dưới
      // thanh tab (padding đáy) nên mép thấy được là phía trên thanh tab.
      final row = target.findRenderObject();
      if (row is! RenderBox) return;
      final bottom = row.localToGlobal(Offset(0, row.size.height)).dy;
      final media = MediaQuery.of(target);
      if (bottom <= media.size.height - media.padding.bottom) return;
      Scrollable.ensureVisible(target, alignment: 0.5);
    });
  }

  @override
  Widget build(BuildContext context) {
    final now = ref.watch(nowProvider);
    final today = LocalDate.fromDateTime(now);
    final current = today.yearMonth;
    final month = _shown ?? current;
    final plans = ref.watch(monthPlansProvider).value ?? const [];
    final plan = plans.where((p) => p.month == month).firstOrNull;
    final first = plans.isEmpty ? current : plans.first.month;
    final days = ref.watch(monthDaysProvider(month)).value ?? const [];
    if (month == current && plan != null) _scrollToToday();

    final changed = month == current && ref.watch(templateChangedProvider);

    return TabPage(
      tab: AppTab.schedule,
      title: S.tabSchedule,
      trailing: OutlinedButton(
        key: const ValueKey('open-weekly'),
        onPressed: () => context.push(weeklySchedulePath),
        child: const Text(S.weeklySchedule),
      ),
      // Một khối duy nhất: dựng đủ mọi dòng để tự cuộn tới hôm nay.
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _MonthBar(
              month: month,
              // "‹" dừng ở tháng thiết lập; ở tháng hiện tại ẩn "›" (04 S-20).
              onPrevious: month.compareTo(first) > 0
                  ? () => setState(() => _shown = month.previous)
                  : null,
              onNext: month.compareTo(current) < 0
                  ? () => setState(
                      () => _shown = month.next == current ? null : month.next,
                    )
                  : null,
            ),
            const SizedBox(height: 12),
            if (changed) ...[
              const _RedistributeBanner(),
              const SizedBox(height: 16),
            ],
            if (plan != null)
              _MonthList(plan: plan, days: days, now: now, todayKey: _todayKey),
            if (month == current && plan != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  S.nextMonthNotice(current.next.month),
                  textAlign: TextAlign.center,
                  style: context.text.bodyMedium?.copyWith(
                    color: context.palette.textSecondary,
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _MonthBar extends StatelessWidget {
  const _MonthBar({required this.month, this.onPrevious, this.onNext});

  final YearMonth month;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    Widget arrow(IconData icon, String label, VoidCallback? onTap, Key key) =>
        SizedBox(
          width: 48,
          height: 48,
          child: onTap == null
              ? null
              : IconButton(
                  key: key,
                  tooltip: label,
                  onPressed: onTap,
                  icon: Icon(icon, color: context.colors.primary),
                ),
        );
    return Row(
      children: [
        arrow(
          Icons.chevron_left,
          S.previousMonth,
          onPrevious,
          const ValueKey('month-previous'),
        ),
        Expanded(
          child: Text(
            S.monthTitle(month.month, month.year),
            textAlign: TextAlign.center,
            style: context.text.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        arrow(
          Icons.chevron_right,
          S.nextMonth,
          onNext,
          const ValueKey('month-next'),
        ),
      ],
    );
  }
}

/// Các ngày từ ngày bắt đầu của lịch (tháng đầu = ngày thiết lập, UA-12) đến
/// cuối tháng, nhóm theo tuần thứ 2 → chủ nhật.
class _MonthList extends StatelessWidget {
  const _MonthList({
    required this.plan,
    required this.days,
    required this.now,
    required this.todayKey,
  });

  final MonthPlan plan;
  final List<PlanDay> days;
  final DateTime now;
  final GlobalKey todayKey;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final today = LocalDate.fromDateTime(now);
    final byDate = {for (final d in days) d.date: d};
    final weeks = <List<LocalDate>>[];
    for (var d = plan.startDate; d <= plan.month.lastDay; d = d.addDays(1)) {
      if (weeks.isEmpty || d.weekday == DateTime.monday) weeks.add([]);
      weeks.last.add(d);
    }
    return Container(
      decoration: BoxDecoration(
        color: palette.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: palette.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final week in weeks) ...[
            _WeekHeader(start: week.first.weekStart),
            for (final date in week)
              DayLine(
                key: date == today ? todayKey : ValueKey('day-${date.toKey()}'),
                date: date,
                day: byDate[date],
                now: now,
                onTap: () => showDaySheet(context, date),
              ),
          ],
        ],
      ),
    );
  }
}

/// Tiêu đề tuần "05/10 – 11/10" và bên phải "Đã tập 2/3 ›" (04 S-20, mock
/// S-20-1). Chạm → S-25 của tuần đó; tuần chưa tới không mở được (F06-R5).
class _WeekHeader extends ConsumerWidget {
  const _WeekHeader({required this.start});

  /// Thứ 2 của tuần.
  final LocalDate start;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final week = ProgressWeek.containing(start);
    final weeks = ref.watch(progressWeeksProvider);
    final progress = ref.watch(weekProgressProvider(week));
    final style = context.text.bodyMedium?.copyWith(
      color: palette.textSecondary,
      fontWeight: FontWeight.w700,
    );
    // Tuần trước tuần thiết lập (chỉ có chủ nhật trong lịch) không có tiến độ.
    final shown =
        progress != null && weeks.isNotEmpty && week.start >= weeks.first.start;
    final openable = shown && week.start <= weeks.last.start;
    final count = !shown
        ? null
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(S.weekDone(progress.done, progress.planned), style: style),
              if (openable)
                Icon(
                  Icons.chevron_right,
                  size: 20,
                  color: palette.textSecondary,
                ),
            ],
          );
    return InkWell(
      key: ValueKey('week-header-${start.toKey()}'),
      onTap: openable
          ? () => context.push(weekProgressPath(AppTab.schedule, week))
          : null,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
        child: Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 8,
          runSpacing: 4,
          children: [
            Text(Fmt.weekRange(start, start.addDays(6)), style: style),
            ?count,
          ],
        ),
      ),
    );
  }
}

/// Banner "Lịch tuần đã thay đổi…" kèm "Chia lại" (F03-R7, F03-R8, mock
/// S-20-1, S-20-2). Hiện cho đến khi chia lại hoặc sang tháng mới.
class _RedistributeBanner extends ConsumerWidget {
  const _RedistributeBanner();

  Future<void> _redistribute(BuildContext context, WidgetRef ref) async {
    final ok =
        await showAppDialog<bool>(
          context,
          builder: (dialogContext) => AlertDialog(
            title: const Text(S.redistributeTitle),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(S.redistributeBody),
                const SizedBox(height: 12),
                Text(
                  S.redistributeNote,
                  style: dialogContext.text.bodyMedium?.copyWith(
                    color: dialogContext.palette.textSecondary,
                  ),
                ),
              ],
            ),
            actions: [
              OutlinedButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text(S.cancel),
              ),
              FilledButton(
                key: const ValueKey('confirm-redistribute'),
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: const Text(S.redistribute),
              ),
            ],
          ),
        ) ??
        false;
    if (!ok) return;
    final r = await ref.read(scheduleEditsProvider).redistribute();
    if (r == null || !context.mounted) return;
    showToast(
      context,
      S.redistributed(
        Fmt.dayMonth(r.from),
        Fmt.dayMonth(r.to),
        r.keptOverrides,
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    return Container(
      key: const ValueKey('redistribute-banner'),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      decoration: BoxDecoration(
        color: palette.attentionContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            S.templateChangedBanner,
            style: context.text.bodyLarge?.copyWith(color: palette.attention),
          ),
          const SizedBox(height: 12),
          FilledButton(
            key: const ValueKey('redistribute'),
            onPressed: () => _redistribute(context, ref),
            child: const Text(S.redistribute),
          ),
        ],
      ),
    );
  }
}
