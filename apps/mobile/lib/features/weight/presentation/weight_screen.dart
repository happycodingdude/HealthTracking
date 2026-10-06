import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/shell/app_tab.dart';
import '../../../app/strings_vi.dart';
import '../../../app/theme.dart';
import '../../../core/formatters.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/tab_page.dart';
import '../../../data/sync/sync_providers.dart';
import '../../me/application/calorie_view.dart';
import '../../today/application/today_view.dart';
import 'weight_chart.dart';
import 'weight_sheet.dart';

/// Mọi số cân, cũ → mới.
final weightLogProvider = StreamProvider<WeightLog>(
  (ref) => ref.watch(weightRepositoryProvider).watchAll().map(WeightLog.new),
);

/// S-40 — Cân nặng (04 S-40): tóm tắt (số cân mới nhất, chênh so với lần
/// trước và ban đầu, F07-R7), "Ghi cân tuần này", biểu đồ xu hướng, lịch sử
/// từ tuần hiện tại về tuần thiết lập.
class WeightScreen extends ConsumerWidget {
  const WeightScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final log = ref.watch(weightLogProvider).value;
    final setup = ref.watch(profileProvider).value?.setupDate;
    final today = ref.watch(todayProvider);
    if (log == null || setup == null) {
      return const TabPage(tab: AppTab.weight, title: S.tabWeight);
    }
    final weeks = WeightLog.weeks(setupDate: setup, today: today);
    final thisWeek = WeightRules.weekKey(today);
    return TabPage(
      tab: AppTab.weight,
      title: S.tabWeight,
      children: [
        if (log.latest != null) _Summary(log: log),
        const SizedBox(height: 16),
        PrimaryButton(
          label: S.logThisWeek,
          onPressed: () => showWeightSheet(context, thisWeek),
        ),
        const SizedBox(height: 16),
        _Trend(weeks: weeks.reversed.toList(), log: log),
        const SizedBox(height: 16),
        _History(weeks: weeks, log: log),
      ],
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.log});

  final WeightLog log;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final latest = log.latest!;
    final previous = log.changeFromPrevious;
    final changes = [
      if (previous != null) (previous, S.vsPrevious),
      (log.changeFromInitial!, S.vsInitial),
    ];
    final style = context.text.bodyLarge?.copyWith(
      color: palette.textSecondary,
    );
    return Card(
      key: const ValueKey('weight-summary'),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              S.latestWeek(Fmt.weekRange(latest.week, latest.week.addDays(6))),
              style: context.text.titleMedium?.copyWith(
                color: palette.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: Fmt.kgNumber(latest.kgX10),
                    style: context.text.displayMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  TextSpan(
                    text: ' ${S.unitKg}',
                    style: context.text.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            // Mũi tên, màu trung tính: tăng nhẹ không phải thất bại (UA-15).
            // Mũi tên vẽ bằng biểu tượng; VoiceOver đọc cả câu.
            Semantics(
              container: true,
              label: [
                for (final (diff, line) in changes)
                  line(Fmt.weightChange(diff)),
              ].join(' · '),
              child: ExcludeSemantics(
                child: Text.rich(
                  TextSpan(
                    style: style,
                    children: [
                      for (final (i, (diff, line)) in changes.indexed) ...[
                        if (i > 0) const TextSpan(text: ' · '),
                        if (diff != 0)
                          WidgetSpan(
                            alignment: PlaceholderAlignment.middle,
                            child: Icon(
                              diff < 0
                                  ? Icons.arrow_downward
                                  : Icons.arrow_upward,
                              size:
                                  (style?.fontSize ?? 16) *
                                  MediaQuery.textScalerOf(context).scale(1),
                              color: palette.textSecondary,
                            ),
                          ),
                        TextSpan(text: line(Fmt.kg(diff.abs()))),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Trend extends StatelessWidget {
  const _Trend({required this.weeks, required this.log});

  /// Cũ → mới.
  final List<LocalDate> weeks;
  final WeightLog log;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Card(
      key: const ValueKey('weight-trend'),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 12,
              children: [
                Text(
                  S.trendTitle,
                  style: context.text.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  S.lastEightWeeks,
                  style: context.text.bodyMedium?.copyWith(
                    color: palette.textSecondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            WeightChart(weeks: weeks, log: log),
            if (log.points.length == 1) ...[
              const SizedBox(height: 8),
              Text(
                S.firstWeightHint,
                style: context.text.bodyLarge?.copyWith(
                  color: palette.textSecondary,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Lịch sử: mới nhất ở trên; tuần chưa ghi có "Chưa ghi" · "Thêm" (04 S-40).
class _History extends StatelessWidget {
  const _History({required this.weeks, required this.log});

  /// Mới → cũ.
  final List<LocalDate> weeks;
  final WeightLog log;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (i, week) in weeks.indexed) ...[
            if (i > 0) const Divider(indent: 16, endIndent: 16),
            _HistoryRow(week: week, point: log.at(week), palette: palette),
          ],
        ],
      ),
    );
  }
}

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({
    required this.week,
    required this.point,
    required this.palette,
  });

  final LocalDate week;
  final WeightPoint? point;
  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    final p = point;
    final label = Text(
      S.weekLabel(Fmt.weekRange(week, week.addDays(6))),
      style: context.text.bodyLarge,
    );
    if (p == null) {
      return Padding(
        key: ValueKey('weight-week-${week.toKey()}'),
        padding: const EdgeInsets.fromLTRB(16, 4, 8, 4),
        child: Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 8,
          children: [
            label,
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  S.notLogged,
                  style: context.text.bodyMedium?.copyWith(
                    color: palette.textSecondary,
                  ),
                ),
                TextButton(
                  key: ValueKey('weight-add-${week.toKey()}'),
                  onPressed: () => showWeightSheet(context, week),
                  child: const Text(S.add),
                ),
              ],
            ),
          ],
        ),
      );
    }
    return InkWell(
      key: ValueKey('weight-week-${week.toKey()}'),
      onTap: () => showWeightSheet(context, week, edit: true),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
        child: Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 8,
          children: [
            label,
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  Fmt.kg(p.kgX10),
                  style: context.text.bodyLarge?.copyWith(
                    color: palette.textSecondary,
                  ),
                ),
                Icon(Icons.chevron_right, color: palette.textSecondary),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
