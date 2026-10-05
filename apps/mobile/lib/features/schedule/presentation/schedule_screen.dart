import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../app/shell/app_tab.dart';
import '../../../app/strings_vi.dart';
import '../../../app/theme.dart';
import '../../../core/formatters.dart';
import '../../../core/widgets/tab_page.dart';
import '../../../data/sync/sync_providers.dart';

/// Các tháng đã có lịch, cũ → mới.
final monthPlansProvider = StreamProvider<List<MonthPlan>>(
  (ref) => ref.watch(scheduleRepositoryProvider).watchPlans(),
);

/// Các ngày (thứ 2 → thứ 7) của một tháng.
final monthDaysProvider = StreamProvider.family<List<PlanDay>, YearMonth>(
  (ref, month) => ref.watch(scheduleRepositoryProvider).watchMonth(month),
);

/// S-20 — Lịch tháng, chế độ xem (VS04-T11). Danh sách ngày nhóm theo tuần,
/// hôm nay được làm nổi bật và tự cuộn tới khi mở tab; xem được các tháng
/// trước, không có tháng sau trước ngày 1 (F03-R13). Nhãn trạng thái buổi
/// (VS-06), banner Chia lại, nút "Lịch tuần" và S-21 (VS-09) thêm sau.
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
      // Chỉ cuộn khi hôm nay còn khuất phía dưới.
      Scrollable.ensureVisible(
        target,
        alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final today = ref.watch(clockProvider).today();
    final current = today.yearMonth;
    final month = _shown ?? current;
    final plans = ref.watch(monthPlansProvider).value ?? const [];
    final plan = plans.where((p) => p.month == month).firstOrNull;
    final first = plans.isEmpty ? current : plans.first.month;
    final days = ref.watch(monthDaysProvider(month)).value ?? const [];
    if (month == current && plan != null) _scrollToToday();

    return TabPage(
      tab: AppTab.schedule,
      title: S.tabSchedule,
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
            if (plan != null)
              _MonthList(
                plan: plan,
                days: days,
                today: today,
                todayKey: _todayKey,
              ),
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
    required this.today,
    required this.todayKey,
  });

  final MonthPlan plan;
  final List<PlanDay> days;
  final LocalDate today;
  final GlobalKey todayKey;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
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
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
              child: Text(
                Fmt.weekRange(
                  week.first.weekStart,
                  week.first.weekStart.addDays(6),
                ),
                style: context.text.bodyMedium?.copyWith(
                  color: palette.textSecondary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            for (final date in week)
              _DayLine(
                key: date == today ? todayKey : ValueKey('day-${date.toKey()}'),
                date: date,
                day: byDate[date],
                today: today,
              ),
          ],
        ],
      ),
    );
  }
}

class _DayLine extends StatelessWidget {
  const _DayLine({
    super.key,
    required this.date,
    required this.day,
    required this.today,
  });

  final LocalDate date;

  /// null với chủ nhật (luôn nghỉ, không có bản ghi).
  final PlanDay? day;
  final LocalDate today;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final d = day;
    final past = date.isBefore(today);
    final isToday = date == today;
    final info = d != null && d.isWorkout
        ? '${Fmt.muscles(d.muscles)} · ${Fmt.time(d.time!)}'
        : S.rest;
    final color = past ? palette.textSecondary : null;
    return Container(
      color: isToday ? context.colors.primaryContainer : null,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 12,
        runSpacing: 4,
        children: [
          // Cỡ chữ lớn: cột ngày tự giãn, phần còn lại xuống dòng (UX-AC18).
          ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 84),
            child: Text(
              Fmt.shortWeekdayDate(date),
              style: context.text.bodyLarge?.copyWith(
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ),
          Text(
            info,
            style: context.text.bodyLarge?.copyWith(
              color: d != null && d.isWorkout ? color : palette.textSecondary,
            ),
          ),
          if (d?.source == DaySource.override)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: context.colors.primaryContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                S.overridden,
                style: context.text.labelLarge?.copyWith(
                  color: context.colors.onPrimaryContainer,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
