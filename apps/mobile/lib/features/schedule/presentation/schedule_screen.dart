import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/shell/app_tab.dart';
import '../../../app/strings_vi.dart';
import '../../../app/theme.dart';
import '../../../app/time_ticker.dart';
import '../../../core/formatters.dart';
import '../../../core/widgets/session_tag.dart';
import '../../../core/widgets/tab_page.dart';
import '../application/schedule_providers.dart';

/// S-20 — Lịch tháng, chế độ xem (VS04-T11). Danh sách ngày nhóm theo tuần,
/// hôm nay được làm nổi bật và tự cuộn tới khi mở tab; xem được các tháng
/// trước, không có tháng sau trước ngày 1 (F03-R13). Mỗi buổi tập có nhãn
/// trạng thái (04 §6.13.3, VS06-T08). Banner Chia lại, nút "Lịch tuần" và S-21
/// (VS-09) thêm sau.
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
                now: now,
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
    required this.now,
  });

  final LocalDate date;

  /// null với chủ nhật (luôn nghỉ, không có bản ghi).
  final PlanDay? day;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final today = LocalDate.fromDateTime(now);
    final d = day;
    final status = d == null ? null : SessionStatus.derive(d, now);
    final past = date.isBefore(today);
    final isToday = date == today;
    final info = d != null && d.isWorkout
        ? '${Fmt.muscles(d.muscles)} · ${Fmt.time(d.time!)}'
        : S.rest;
    final color = past ? palette.textSecondary : null;
    final dateText = Text(
      Fmt.shortWeekdayDate(date),
      style: context.text.bodyLarge?.copyWith(
        fontWeight: FontWeight.w700,
        color: color,
      ),
    );
    final infoText = Text(
      info,
      style: context.text.bodyLarge?.copyWith(
        color: d != null && d.isWorkout ? color : palette.textSecondary,
      ),
    );
    final tags = [
      if (status != null) SessionTag(status),
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
    ];
    // Cỡ chữ lớn: ngày, nội dung và nhãn xếp dọc, không cắt chữ (UX-AC18).
    final stacked = MediaQuery.textScalerOf(context).scale(1) >= 1.6;
    return Container(
      color: isToday ? context.colors.primaryContainer : null,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: stacked
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                dateText,
                infoText,
                if (tags.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Wrap(spacing: 8, runSpacing: 6, children: tags),
                ],
              ],
            )
          : Row(
              children: [
                SizedBox(width: 96, child: dateText),
                // Nội dung và nhãn không đủ một hàng thì nhãn xuống dưới,
                // không ép nội dung thành cột hẹp (nhãn "Không tập · tự động").
                Expanded(
                  child: Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      infoText,
                      if (tags.isNotEmpty)
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            for (final (i, t) in tags.indexed) ...[
                              if (i > 0) const SizedBox(height: 4),
                              t,
                            ],
                          ],
                        ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}
