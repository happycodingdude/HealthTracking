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
import '../../schedule/presentation/day_line.dart';
import '../../schedule/presentation/day_sheet.dart';
import '../application/progress_view.dart';

/// Đường dẫn S-25 của tuần [week], mở trong tab [tab] (Hôm nay hoặc Lịch tập).
String weekProgressPath(AppTab tab, ProgressWeek week) =>
    '${tab.path}/progress/${week.start.toKey()}';

/// S-25 — Tiến độ tuần (04 S-25): thanh tuần "‹ 05/10 – 10/10 ›" không lùi
/// trước tuần thiết lập, không tiến quá tuần hiện tại (F06-R5, F06-E3); con
/// số lớn "X/Y", "Đã tập X/Y buổi theo lịch", "+Z buổi thêm"; danh sách thứ 2
/// → thứ 7 kèm nhãn trạng thái; chạm vào ngày → S-21.
class WeekProgressScreen extends ConsumerStatefulWidget {
  const WeekProgressScreen({super.key, required this.week, required this.tab});

  final ProgressWeek week;

  /// Tab mở màn hình; nút quay lại mang tên tab đó.
  final AppTab tab;

  @override
  ConsumerState<WeekProgressScreen> createState() => _WeekProgressScreenState();
}

class _WeekProgressScreenState extends ConsumerState<WeekProgressScreen> {
  late ProgressWeek _week = widget.week;

  @override
  Widget build(BuildContext context) {
    final weeks = ref.watch(progressWeeksProvider);
    final progress = ref.watch(weekProgressProvider(_week));
    final now = ref.watch(nowProvider);
    final palette = context.palette;
    final hasPrevious = weeks.isNotEmpty && weeks.first.start < _week.start;
    final hasNext = weeks.isNotEmpty && weeks.last.start > _week.start;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: EdgeInsets.fromLTRB(
            16,
            8,
            16,
            MediaQuery.paddingOf(context).bottom + 24,
          ),
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.only(right: 12),
                ),
                onPressed: () => context.pop(),
                icon: const Icon(Icons.chevron_left),
                label: Text(widget.tab.label),
              ),
            ),
            const SizedBox(height: 16),
            Heading(
              S.weekProgressTitle,
              style: context.text.headlineMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _WeekArrow(
                  id: 'week-previous',
                  icon: Icons.chevron_left,
                  label: S.previousWeek,
                  visible: hasPrevious,
                  onTap: () => setState(() => _week = _week.previous),
                ),
                Expanded(
                  child: Text(
                    Fmt.weekRange(_week.start, _week.end),
                    key: const ValueKey('week-range'),
                    textAlign: TextAlign.center,
                    style: context.text.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                _WeekArrow(
                  id: 'week-next',
                  icon: Icons.chevron_right,
                  label: S.nextWeek,
                  visible: hasNext,
                  onTap: () => setState(() => _week = _week.next),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (progress != null) ...[
              _Summary(progress: progress),
              const SizedBox(height: 16),
              Container(
                decoration: BoxDecoration(
                  color: palette.card,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: palette.border),
                ),
                clipBehavior: Clip.antiAlias,
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Ngày trước ngày thiết lập không có lịch (F06-E2).
                    for (final d in progress.days)
                      if (d.day != null)
                        DayLine(
                          key: ValueKey('progress-day-${d.date.toKey()}'),
                          date: d.date,
                          day: d.day,
                          now: now,
                          highlightToday: false,
                          onTap: () => showDaySheet(context, d.date),
                        ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Con số lớn "X/Y", dòng "Đã tập X/Y buổi theo lịch" và nhãn "+Z buổi thêm"
/// (mock S-25). Y = 0 → "Tuần này không có buổi tập theo lịch" (F06-E1).
class _Summary extends StatelessWidget {
  const _Summary({required this.progress});

  final WeeklyProgress progress;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final p = progress;
    return Container(
      key: const ValueKey('progress-summary'),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      decoration: BoxDecoration(
        color: palette.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        children: [
          if (p.planned == 0)
            Text(
              S.noPlannedSessions,
              textAlign: TextAlign.center,
              style: context.text.titleMedium,
            )
          else ...[
            ExcludeSemantics(
              child: Text(
                '${p.done}/${p.planned}',
                style: context.text.displayMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              S.progressLine(p.done, p.planned),
              textAlign: TextAlign.center,
              style: context.text.bodyLarge?.copyWith(
                color: palette.textSecondary,
              ),
            ),
          ],
          if (p.extra > 0) ...[
            const SizedBox(height: 12),
            ExtraCountChip(extra: p.extra),
          ],
        ],
      ),
    );
  }
}

/// Nhãn "+Z buổi thêm" (xanh ngọc, mock S-25).
class ExtraCountChip extends StatelessWidget {
  const ExtraCountChip({super.key, required this.extra});

  final int extra;

  @override
  Widget build(BuildContext context) => Container(
    key: const ValueKey('extra-count'),
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    decoration: BoxDecoration(
      color: context.colors.primaryContainer,
      borderRadius: BorderRadius.circular(10),
    ),
    child: Text(
      S.extraCount(extra),
      style: context.text.labelLarge?.copyWith(
        color: context.colors.onPrimaryContainer,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}

/// Nút "‹" / "›" của thanh tuần; ẩn nhưng giữ chỗ khi không đi tiếp được.
class _WeekArrow extends StatelessWidget {
  const _WeekArrow({
    required this.id,
    required this.icon,
    required this.label,
    required this.visible,
    required this.onTap,
  });

  final String id;
  final IconData icon;
  final String label;
  final bool visible;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Visibility(
    visible: visible,
    maintainSize: true,
    maintainAnimation: true,
    maintainState: true,
    child: IconButton(
      key: visible ? ValueKey(id) : null,
      tooltip: label,
      onPressed: visible ? onTap : null,
      icon: Icon(icon, color: context.colors.primary),
    ),
  );
}
