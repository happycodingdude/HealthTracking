import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/shell/app_tab.dart';
import '../../../app/shell/tab_scroll.dart';
import '../../../app/strings_vi.dart';
import '../../../app/time_ticker.dart';
import '../../../core/formatters.dart';
import '../../../ui/components/components.dart';
import '../../../ui/theme.dart';
import '../../today/application/progress_view.dart';
import '../../today/presentation/today_cards.dart';
import '../../today/presentation/week_progress_screen.dart';
import '../../training/application/training_section.dart';
import '../../training/presentation/training_screen.dart';
import '../application/schedule_edits.dart';
import '../application/schedule_providers.dart';
import 'day_line.dart';
import 'day_sheet.dart';
import 'weekly_schedule_screen.dart';

/// S-20 — Lịch tháng (04 Bản 4 S-20): tiêu đề "Tập luyện" + icon lịch cam
/// (→ S-22); thanh chọn Lịch · Bài tập · Tiến bộ; banner "Lịch tuần đã thay
/// đổi" + nút nhỏ "Chia lại"; thẻ lịch "‹ Tháng 10/2026 ›" + lưới 7 cột ô
/// màu theo trạng thái (chạm ô → S-21); dưới: "Tuần này n / m" + thẻ danh
/// sách buổi của tuần đang chọn. Quy tắc F-03 như Bản 1 → 3.
class ScheduleScreen extends ConsumerStatefulWidget {
  const ScheduleScreen({super.key});

  @override
  ConsumerState<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends ConsumerState<ScheduleScreen> {
  /// null = tháng hiện tại.
  YearMonth? _shown;

  /// Tuần đang chọn (thứ 2); null = tuần chứa hôm nay.
  LocalDate? _week;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final now = ref.watch(nowProvider);
    final today = LocalDate.fromDateTime(now);
    final current = today.yearMonth;
    final month = _shown ?? current;
    final plans = ref.watch(monthPlansProvider).value ?? const [];
    final plan = plans.where((p) => p.month == month).firstOrNull;
    final first = plans.isEmpty ? current : plans.first.month;
    final days = ref.watch(monthDaysProvider(month)).value ?? const [];
    final changed = month == current && ref.watch(templateChangedProvider);
    final noSchedule = ref.watch(scheduleStateProvider)?.hasSchedule == false;
    final weekStart = _week ?? today.weekStart;

    return IronlyTabPage(
      tab: AppTab.schedule,
      title: S.tabTraining,
      scrollController: ref
          .watch(tabScrollControllersProvider)
          .section(TrainingSection.schedule),
      trailing: Semantics(
        button: true,
        label: S.weeklySchedule,
        child: ExcludeSemantics(
          child: GestureDetector(
            key: const ValueKey('open-weekly'),
            behavior: HitTestBehavior.opaque,
            onTap: () => context.push(weeklySchedulePath),
            child: SizedBox(
              width: 44,
              height: 44,
              child: Icon(Icons.calendar_month_outlined, color: t.accent),
            ),
          ),
        ),
      ),
      children: [
        const TrainingSectionBar(),
        const SizedBox(height: TokenSpace.s4),
        if (noSchedule)
          // Chưa có lịch: chỉ nút "Xếp lịch tuần" (F4-R7).
          const NoScheduleCard(key: ValueKey('no-schedule'))
        else ...[
          if (changed) ...[const _RedistributeBanner(), const CardGap()],
          IronlyCard(
            key: const ValueKey('month-card'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _MonthBar(
                  month: month,
                  onPrevious: month.compareTo(first) > 0
                      ? () => setState(() {
                          _shown = month.previous;
                          _week = null;
                        })
                      : null,
                  onNext: month.compareTo(current) < 0
                      ? () => setState(() {
                          _shown = month.next == current ? null : month.next;
                          _week = null;
                        })
                      : null,
                ),
                const SizedBox(height: TokenSpace.s3),
                if (plan != null)
                  _Grid(
                    plan: plan,
                    days: days,
                    now: now,
                    onTap: (date) {
                      setState(() => _week = date.weekStart);
                      showDaySheet(context, date);
                    },
                  ),
              ],
            ),
          ),
          if (plan != null) ...[
            const SizedBox(height: TokenSpace.s4),
            _WeekSummary(start: weekStart, days: days, now: now),
          ],
        ],
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
    final t = context.tokens;
    Widget arrow(IconData icon, String label, VoidCallback? onTap, Key key) =>
        SizedBox(
          width: 36,
          height: 36,
          child: onTap == null
              ? null
              : Semantics(
                  button: true,
                  label: label,
                  child: ExcludeSemantics(
                    child: GestureDetector(
                      key: key,
                      behavior: HitTestBehavior.opaque,
                      onTap: onTap,
                      child: Icon(icon, size: 20, color: t.textSecondary),
                    ),
                  ),
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
            style: IronlyText.body.copyWith(fontWeight: FontWeight.w600),
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

/// Lưới tháng: từ ngày 1 (ngày trước ngày bắt đầu lịch là ô nghỉ mờ, không
/// chạm được) đến cuối tháng; ô theo bộ dấu hiệu 03 Bản 4 §6.4.
class _Grid extends StatelessWidget {
  const _Grid({
    required this.plan,
    required this.days,
    required this.now,
    required this.onTap,
  });

  final MonthPlan plan;
  final List<PlanDay> days;
  final DateTime now;
  final ValueChanged<LocalDate> onTap;

  /// Ô và nhãn VoiceOver của một ngày (dùng chung với S-25, S-10).
  static (MonthCellKind, String) kindOf(
    LocalDate date,
    PlanDay? d,
    DateTime now,
  ) {
    final today = LocalDate.fromDateTime(now);
    if (d == null) return (MonthCellKind.rest, S.rest);
    final status = SessionStatus.derive(d, now);
    if (status != null) {
      final label = status.locked
          ? '${_label(status.state)}, ${S.statusLocked}'
          : _label(status.state);
      return switch (status.state) {
        SessionState.done => (MonthCellKind.done, label),
        SessionState.awaitingMark => (MonthCellKind.today, label),
        SessionState.upcoming => (MonthCellKind.upcoming, label),
        SessionState.skipped ||
        SessionState.autoSkipped => (MonthCellKind.skipped, label),
      };
    }
    if (d.extraMuscles != null) {
      return (
        date == today ? MonthCellKind.today : MonthCellKind.rest,
        S.extraSessionLine(Fmt.muscles(d.extraMuscles!)),
      );
    }
    return (date == today ? MonthCellKind.today : MonthCellKind.rest, S.rest);
  }

  static String _label(SessionState s) => switch (s) {
    SessionState.upcoming => S.statusUpcoming,
    SessionState.awaitingMark => S.statusAwaiting,
    SessionState.done => S.sessionDone,
    SessionState.skipped => S.sessionSkipped,
    SessionState.autoSkipped => S.statusAutoSkipped,
  };

  @override
  Widget build(BuildContext context) {
    final byDate = {for (final d in days) d.date: d};
    final month = plan.month;
    final cells = <MonthCell>[];
    for (
      var date = month.firstDay;
      date <= month.lastDay;
      date = date.addDays(1)
    ) {
      final inPlan = date >= plan.startDate;
      final d = inPlan ? byDate[date] : null;
      final (kind, label) = inPlan
          ? kindOf(date, d, now)
          : (MonthCellKind.rest, S.rest);
      cells.add((
        dateKey: date.toKey(),
        day: date.day,
        kind: kind,
        extra: d?.extraMuscles != null,
        overridden: d?.source == DaySource.override,
        semantics: '${Fmt.weekdayDate(date)}: $label',
      ));
    }
    return MonthGrid(
      weekdayLabels: S.weekdaysShort,
      leading: month.firstDay.weekday - 1,
      cells: cells,
      extraLabel: S.extraSession,
      overriddenLabel: S.overridden,
      onTap: (c) {
        final date = LocalDate.parse(c.dateKey);
        if (date >= plan.startDate) onTap(date);
      },
    );
  }
}

/// "Tuần này n / m" (n cam) + thẻ danh sách buổi của tuần đang chọn: nhóm cơ
/// · "Thứ · giờ" · dấu hiệu. Chạm dòng → S-21; chạm tiêu đề → S-25.
class _WeekSummary extends ConsumerWidget {
  const _WeekSummary({
    required this.start,
    required this.days,
    required this.now,
  });

  final LocalDate start;
  final List<PlanDay> days;
  final DateTime now;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final week = ProgressWeek.containing(start);
    final weeks = ref.watch(progressWeeksProvider);
    final progress = ref.watch(weekProgressProvider(week));
    final shown =
        progress != null && weeks.isNotEmpty && week.start >= weeks.first.start;
    final openable = shown && week.start <= weeks.last.start;
    final byDate = {for (final d in days) d.date: d};
    final today = LocalDate.fromDateTime(now);
    final title = week.start.weekStart == today.weekStart
        ? S.thisWeek
        : Fmt.weekRange(week.start, week.end);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkWell(
          key: ValueKey('week-header-${start.toKey()}'),
          onTap: openable
              ? () => context.push(weekProgressPath(AppTab.schedule, week))
              : null,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(2, 4, 2, TokenSpace.s2),
            child: Row(
              children: [
                Expanded(child: Text(title, style: IronlyText.cardTitle)),
                if (shown)
                  Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: '${progress.done}',
                          style: TextStyle(color: t.accent),
                        ),
                        TextSpan(text: ' / ${progress.planned}'),
                      ],
                    ),
                    key: ValueKey('week-ratio-${start.toKey()}'),
                    style: IronlyText.body.copyWith(
                      fontWeight: FontWeight.w600,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
              ],
            ),
          ),
        ),
        IronlyListCard(
          children: [
            for (var i = 0; i < 6; i++)
              if (byDate[start.addDays(i)] case final d?
                  when d.isWorkout || d.extraMuscles != null)
                DayLine(
                  key: ValueKey('day-${d.date.toKey()}'),
                  date: d.date,
                  day: d,
                  now: now,
                  onTap: () => showDaySheet(context, d.date),
                ),
          ],
        ),
      ],
    );
  }
}

/// Banner "Lịch tuần đã thay đổi…" + nút nhỏ cam "Chia lại" (F03-R7, R8).
class _RedistributeBanner extends ConsumerWidget {
  const _RedistributeBanner();

  Future<void> _redistribute(BuildContext context, WidgetRef ref) async {
    final ok =
        await showIronlyDialog<bool>(
          context,
          builder: (dialogContext) => IronlyDialog(
            title: S.redistributeTitle,
            body: S.redistributeBody,
            secondaryLabel: S.cancel,
            onSecondary: () => Navigator.of(dialogContext).pop(false),
            primaryLabel: S.redistribute,
            primaryKey: const ValueKey('confirm-redistribute'),
            onPrimary: () => Navigator.of(dialogContext).pop(true),
            child: Text(S.redistributeNote, style: IronlyText.dialogBody),
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
  Widget build(BuildContext context, WidgetRef ref) => IronlyBanner(
    key: const ValueKey('redistribute-banner'),
    text: S.templateChangedBanner,
    actionLabel: S.redistribute,
    actionKey: const ValueKey('redistribute'),
    filledAction: true,
    onAction: () => _redistribute(context, ref),
  );
}
