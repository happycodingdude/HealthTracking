import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/shell/app_tab.dart';
import '../../../app/strings_vi.dart';
import '../../../app/time_ticker.dart';
import '../../../core/formatters.dart';
import '../../../ui/components/components.dart';
import '../../../ui/theme.dart';
import '../../schedule/presentation/day_line.dart';
import '../../schedule/presentation/day_sheet.dart';
import '../application/progress_view.dart';
import 'today_cards.dart';

/// Đường dẫn S-25 của tuần [week], mở trong tab [tab] (Hôm nay hoặc Lịch tập).
String weekProgressPath(AppTab tab, ProgressWeek week) =>
    '${tab.path}/progress/${week.start.toKey()}';

/// S-25 — Tiến độ tuần (04 Bản 4 S-25): tiêu đề giữa "19/10 – 25/10" với
/// ‹ › (không lùi trước tuần thiết lập, không tiến quá tuần hiện tại, F06-R5,
/// F06-E3); thẻ số lớn "3" cam + "/4" chữ phụ, "+1" khi có buổi thêm, dải 6
/// vòng T2–T7; thẻ danh sách ngày "T2 19 · Ngực · dấu hiệu"; chạm dòng → S-21.
class WeekProgressScreen extends ConsumerStatefulWidget {
  const WeekProgressScreen({super.key, required this.week, required this.tab});

  final ProgressWeek week;
  final AppTab tab;

  @override
  ConsumerState<WeekProgressScreen> createState() => _WeekProgressScreenState();
}

class _WeekProgressScreenState extends ConsumerState<WeekProgressScreen> {
  late ProgressWeek _week = widget.week;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final weeks = ref.watch(progressWeeksProvider);
    final progress = ref.watch(weekProgressProvider(_week));
    final now = ref.watch(nowProvider);
    final today = LocalDate.fromDateTime(now);
    final hasPrevious = weeks.isNotEmpty && weeks.first.start < _week.start;
    final hasNext = weeks.isNotEmpty && weeks.last.start > _week.start;

    Widget arrow(
      String id,
      IconData icon,
      String label,
      bool visible,
      VoidCallback onTap,
    ) => Visibility(
      visible: visible,
      maintainSize: true,
      maintainAnimation: true,
      maintainState: true,
      child: Semantics(
        button: true,
        label: label,
        child: ExcludeSemantics(
          child: GestureDetector(
            key: visible ? ValueKey(id) : null,
            behavior: HitTestBehavior.opaque,
            onTap: visible ? onTap : null,
            child: SizedBox(
              width: 36,
              height: 36,
              child: Icon(icon, size: 22, color: t.accent),
            ),
          ),
        ),
      ),
    );

    return IronlySubPage(
      title: Fmt.weekRange(_week.start, _week.end),
      titleWidget: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          arrow(
            'week-previous',
            Icons.chevron_left,
            S.previousWeek,
            hasPrevious,
            () => setState(() => _week = _week.previous),
          ),
          // Cỡ chữ lớn: co chữ cho vừa giữa hai mũi tên (TA4-04).
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Semantics(
                header: true,
                child: Text(
                  Fmt.weekRange(_week.start, _week.end),
                  key: const ValueKey('week-range'),
                  style: IronlyText.subtitle,
                ),
              ),
            ),
          ),
          arrow(
            'week-next',
            Icons.chevron_right,
            S.nextWeek,
            hasNext,
            () => setState(() => _week = _week.next),
          ),
        ],
      ),
      listKey: const ValueKey('week-progress-list'),
      children: [
        if (progress != null) ...[
          _Summary(progress: progress, today: today),
          const CardGap(),
          IronlyListCard(
            children: [
              // Ngày trước ngày thiết lập không có lịch (F06-E2).
              for (final d in progress.days)
                if (d.day != null)
                  DayLine(
                    key: ValueKey('progress-day-${d.date.toKey()}'),
                    date: d.date,
                    day: d.day,
                    now: now,
                    compact: true,
                    onTap: () => showDaySheet(context, d.date),
                  ),
            ],
          ),
        ],
      ],
    );
  }
}

/// Số lớn 36 "3" cam + "/4" chữ phụ; "+1" chữ phụ nhỏ khi có buổi thêm; dải
/// 6 vòng T2–T7 với dấu hiệu.
class _Summary extends StatelessWidget {
  const _Summary({required this.progress, required this.today});

  final WeeklyProgress progress;
  final LocalDate today;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final p = progress;
    return IronlyCard(
      key: const ValueKey('progress-summary'),
      child: Column(
        children: [
          Semantics(
            container: true,
            label: S.progressLine(p.done, p.planned),
            child: ExcludeSemantics(
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: '${p.done}',
                      style: IronlyText.numberXL.copyWith(color: t.accent),
                    ),
                    TextSpan(
                      text: '/${p.planned}',
                      style: IronlyText.number.copyWith(color: t.textSecondary),
                    ),
                  ],
                ),
                key: const ValueKey('progress-ratio'),
              ),
            ),
          ),
          if (p.extra > 0)
            Semantics(
              container: true,
              label: S.extraCount(p.extra),
              child: ExcludeSemantics(
                child: Text(
                  '+${p.extra}',
                  key: const ValueKey('extra-count'),
                  style: IronlyText.caption,
                ),
              ),
            ),
          const SizedBox(height: TokenSpace.s4),
          WeekStrip(
            days: [
              for (final d in p.days)
                () {
                  final (g, label) = WeekCard.glyphOf(d);
                  return (
                    dateKey: d.date.toKey(),
                    label: S.weekdaysShort[d.date.weekday - 1],
                    status: g,
                    semantics: label,
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
