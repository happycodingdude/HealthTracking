import 'dart:math' as math;

import 'package:domain/domain.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/strings_vi.dart';
import '../../../app/time_ticker.dart';
import '../../../core/formatters.dart';
import '../../../ui/components/components.dart';
import '../../../ui/theme.dart';
import '../../library/application/library_providers.dart';
import '../../workout/application/lift_unit.dart';
import '../application/progress_providers.dart';

/// Đường dẫn S-69 mở từ S-68 (mục Tiến bộ, NAV-11).
String liftChartPath(String exerciseId) =>
    '/schedule/chart/${Uri.encodeComponent(exerciseId)}';

/// Màn trước của S-69: quyết định nút quay lại và "Xem bài".
enum ChartFrom {
  /// Từ S-68: "Xem bài" mở S-67 phía trên.
  progress,

  /// Từ S-67 ("Xem biểu đồ"): "Xem bài" quay lại S-67.
  exercise,
}

/// S-69 — Biểu đồ mức tạ (04 Bản 2 S-69, F-22): tên bài, thanh tháng (mặc định
/// tháng hiện tại, lùi đến tháng có bản ghi đầu tiên, F22-R2), biểu đồ hai
/// chuỗi Bắt đầu (tròn rỗng) và Kết thúc (tròn đặc), danh sách con số của
/// tháng. Chỉ dữ liệu: không xu hướng, không mục tiêu, không nhận xét (F22-R4).
/// Đọc Drift nên dùng được khi không có mạng (F22-R7).
class LiftChartScreen extends ConsumerStatefulWidget {
  const LiftChartScreen({
    super.key,
    required this.exerciseId,
    required this.from,
  });

  final String exerciseId;
  final ChartFrom from;

  @override
  ConsumerState<LiftChartScreen> createState() => _LiftChartScreenState();
}

class _LiftChartScreenState extends ConsumerState<LiftChartScreen> {
  /// Tháng Bạn đã chọn; null = tháng hiện tại.
  YearMonth? _shown;

  void _viewExercise() {
    if (widget.from == ChartFrom.exercise) {
      context.pop();
    } else {
      context.push('${liftChartPath(widget.exerciseId)}/exercise');
    }
  }

  @override
  Widget build(BuildContext context) {
    final current = LocalDate.fromDateTime(ref.watch(nowProvider)).yearMonth;
    final month = _shown ?? current;
    final exercise = ref.watch(exerciseProvider(widget.exerciseId)).value;
    final view = ref.watch(
      liftChartProvider((exerciseId: widget.exerciseId, month: month)),
    );
    final t = context.tokens;
    final earliest = view?.earliest;
    final chart = view?.chart;
    final change = view?.unitChange;
    // Đơn vị hiện tại của bài (F21-R47: số cũ hiện theo đơn vị mới).
    final units = ref.watch(exerciseUnitsProvider).value;
    final unit = exercise == null ? null : displayUnit(units, exercise.id);

    return IronlySubPage(
      title: exercise?.nameVi ?? '',
      leading: Semantics(
        button: true,
        label: S.back,
        child: ExcludeSemantics(
          child: GestureDetector(
            key: const ValueKey('chart-back'),
            behavior: HitTestBehavior.opaque,
            onTap: () => context.pop(),
            child: SizedBox(
              width: 44,
              height: 44,
              child: Icon(Icons.chevron_left, color: t.accent, size: 26),
            ),
          ),
        ),
      ),
      // "Xem bài" (NAV-11): chữ cam nhỏ góc phải.
      trailing: IronlyButton.link(
        key: const ValueKey('chart-view-exercise'),
        label: S.viewExercise,
        small: true,
        expand: false,
        onPressed: _viewExercise,
      ),
      children: [
        _MonthBar(
          month: month,
          // "‹" mờ ở tháng có bản ghi đầu tiên; "›" ẩn ở tháng hiện tại.
          onPrevious: earliest != null && month.compareTo(earliest) > 0
              ? () => setState(() => _shown = month.previous)
              : null,
          onNext: month.compareTo(current) < 0
              ? () => setState(
                  () => _shown = month.next == current ? null : month.next,
                )
              : null,
        ),
        const SizedBox(height: TokenSpace.s3),
        if (chart != null && unit != null) ...[
          IronlyCard(
            key: const ValueKey('chart-card'),
            padding: const EdgeInsets.fromLTRB(
              TokenSpace.s2,
              TokenSpace.s4,
              TokenSpace.s4,
              TokenSpace.s3,
            ),
            child: chart.isEmpty
                // Tháng không có bản ghi: chỉ icon, không câu (F4-R7).
                ? const EmptyAction(
                    key: ValueKey('chart-month-empty'),
                    inCard: false,
                    icon: Icons.show_chart,
                  )
                : Column(
                    children: [
                      // VoiceOver đọc cả mốc đổi đơn vị (04 Bản 3 S-69).
                      Semantics(
                        label: [
                          S.chartSemantics(month.month, chart.logs.length),
                          if (change != null &&
                              change.on.yearMonth == chart.month)
                            S.unitChangeSemantics(
                              Fmt.liftUnit(change.to),
                              Fmt.dayMonth(change.on),
                            ),
                        ].join('. '),
                        child: ExcludeSemantics(
                          child: _LiftChart(
                            key: ValueKey('chart-${month.toKey()}'),
                            chart: chart,
                            unit: unit,
                            change: change,
                          ),
                        ),
                      ),
                      const SizedBox(height: TokenSpace.s2),
                      // Chú giải "○ Bắt đầu  ● Kết thúc" + đơn vị phải.
                      ExcludeSemantics(
                        child: Row(
                          key: const ValueKey('chart-legend'),
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Cỡ chữ lớn: hai mục chú giải xuống dòng.
                            Expanded(
                              child: Wrap(
                                spacing: TokenSpace.s3,
                                runSpacing: TokenSpace.s1,
                                children: [
                                  for (final (filled, label) in [
                                    (false, S.chartStart),
                                    (true, S.chartEnd),
                                  ])
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        _LegendDot(filled: filled),
                                        const SizedBox(width: TokenSpace.s1),
                                        Text(label, style: IronlyText.caption),
                                      ],
                                    ),
                                ],
                              ),
                            ),
                            const SizedBox(width: TokenSpace.s2),
                            Text(
                              Fmt.liftUnit(unit),
                              key: const ValueKey('chart-legend-unit'),
                              style: IronlyText.caption,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
          ),
          if (!chart.isEmpty) ...[
            const CardGap(),
            IronlyListCard(
              key: const ValueKey('chart-list'),
              children: [
                for (final l in chart.logs.reversed)
                  IronlyRow(
                    title: Fmt.shortWeekdayDate(l.date),
                    titleWidget: Text(
                      change != null && l.date.isBefore(change.on)
                          ? '${Fmt.shortWeekdayDate(l.date)} '
                                '${S.beforeUnitChange}'
                          : Fmt.shortWeekdayDate(l.date),
                      key: ValueKey('chart-date-${l.date.toKey()}'),
                      style: IronlyText.body.copyWith(color: t.textSecondary),
                    ),
                    minHeight: 44,
                    semanticsLabel:
                        '${Fmt.shortWeekdayDate(l.date)}, ${Fmt.lift(l, unit)}',
                    trailing: Text(
                      Fmt.lift(l, unit),
                      key: ValueKey('chart-row-${l.date.toKey()}'),
                      style: IronlyText.liftNumber,
                    ),
                  ),
              ],
            ),
          ],
        ],
      ],
    );
  }
}

/// Chấm chú giải: rỗng (Bắt đầu) hoặc đặc (Kết thúc), màu cam.
class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.filled});

  final bool filled;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: filled ? t.chartLine : null,
        border: Border.all(color: t.chartLine, width: 2),
      ),
    );
  }
}

/// "‹ Tháng {mm}/{yyyy} ›": "‹" mờ khi không lùi được, "›" ẩn ở tháng hiện
/// tại (04 Bản 2 S-69).
class _MonthBar extends StatelessWidget {
  const _MonthBar({required this.month, this.onPrevious, this.onNext});

  final YearMonth month;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    final color = context.tokens.accent;
    return Row(
      children: [
        IconButton(
          key: const ValueKey('chart-month-previous'),
          tooltip: S.previousMonth,
          onPressed: onPrevious,
          color: color,
          disabledColor: color.withAlpha(70),
          icon: const Icon(Icons.chevron_left),
        ),
        Expanded(
          child: Text(
            S.chartMonth(month.month, month.year),
            key: const ValueKey('chart-month'),
            textAlign: TextAlign.center,
            style: IronlyText.body.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        SizedBox(
          width: 48,
          height: 48,
          child: onNext == null
              ? null
              : IconButton(
                  key: const ValueKey('chart-month-next'),
                  tooltip: S.nextMonth,
                  onPressed: onNext,
                  color: color,
                  icon: const Icon(Icons.chevron_right),
                ),
        ),
      ],
    );
  }
}

/// Biểu đồ một tháng (UA2-13): trục ngang cả tháng, trục dọc kg (bài máy:
/// số thanh) tự co giãn có khoảng dư; Bắt đầu tròn rỗng nét đứt, Kết thúc
/// tròn đặc nét liền, cùng màu chủ đạo; bằng nhau → điểm đặc to, viền đậm
/// (F22-E3). Nối các buổi trong tháng, không nối qua mốc đổi đơn vị
/// (F22-R9). Chạm một ngày → "{dd/mm} · {a} → {b} kg".
class _LiftChart extends StatefulWidget {
  const _LiftChart({
    super.key,
    required this.chart,
    required this.unit,
    required this.change,
  });

  final MonthlyLiftChart chart;
  final LiftUnit unit;

  /// Mốc đổi đơn vị gần nhất (UA3-13); chỉ vẽ khi rơi vào tháng đang xem.
  final LiftUnitChange? change;

  @override
  State<_LiftChart> createState() => _LiftChartState();
}

class _LiftChartState extends State<_LiftChart> {
  /// Ngày đang chạm.
  int? _selected;

  static const _leftReserved = 40.0;

  /// Bước chia trục kg (đơn vị kg).
  static const _steps = [0.5, 1.0, 2.0, 2.5, 5.0, 10.0, 20.0, 25.0, 50.0];

  /// Bước chia trục số thanh: chỉ số nguyên.
  static const _wholeSteps = [1.0, 2.0, 5.0, 10.0];

  @override
  Widget build(BuildContext context) {
    final chart = widget.chart;
    final t = context.tokens;
    final days = chart.month.lengthInDays;
    final (low, high) = chart.range!;
    final pad = math.max(10, (high - low) * 0.25) / 10;
    var minY = math.max(0, low / 10 - pad).toDouble();
    var maxY = high / 10 + pad;
    final unit = widget.unit;
    final step = (unit == LiftUnit.steps ? _wholeSteps : _steps).firstWhere(
      (s) => (maxY - minY) / s <= 5,
      orElse: () => 100,
    );
    minY = (minY / step).floorToDouble() * step;
    maxY = (maxY / step).ceilToDouble() * step;
    final byDay = {for (final l in chart.logs) l.date.day: l};

    FlSpot spot(LiftLog l, int x10) => FlSpot(l.date.day.toDouble(), x10 / 10);
    final segments = chart.segments(unitChangeOn: widget.change?.on);
    final startBars = [
      for (final seg in segments)
        LineChartBarData(
          spots: [for (final l in seg) spot(l, l.startKgX10)],
          color: t.chartLine,
          barWidth: 2,
          dashArray: const [4, 4],
          dotData: FlDotData(
            getDotPainter: (_, _, _, _) => FlDotCirclePainter(
              radius: 5,
              color: t.surface,
              strokeColor: t.chartLine,
              strokeWidth: 2.5,
            ),
          ),
        ),
    ];
    final endBars = [
      for (final seg in segments)
        LineChartBarData(
          spots: [for (final l in seg) spot(l, l.endKgX10)],
          color: t.chartLine,
          barWidth: 2.5,
          dotData: FlDotData(
            getDotPainter: (s, _, _, _) {
              final l = byDay[s.x.round()];
              final same = l != null && l.startKgX10 == l.endKgX10;
              return FlDotCirclePainter(
                radius: same ? 7.5 : 5,
                color: t.chartLine,
                strokeColor: same ? t.textPrimary : t.chartLine,
                strokeWidth: same ? 3 : 1,
              );
            },
          ),
        ),
    ];
    final bars = [...startBars, ...endBars];
    final selected = _selected;
    final tooltip = <ShowingTooltipIndicators>[
      if (selected != null)
        for (var b = startBars.length; b < bars.length; b++)
          for (final s in bars[b].spots)
            if (s.x.round() == selected)
              ShowingTooltipIndicators([LineBarSpot(bars[b], b, s)]),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final drawWidth = constraints.maxWidth - _leftReserved;
        final dayWidth = drawWidth / days;
        return GestureDetector(
          key: const ValueKey('lift-chart'),
          onTapUp: (d) {
            final x = 0.5 + (d.localPosition.dx - _leftReserved) / dayWidth;
            int? hit;
            for (final day in byDay.keys) {
              if ((day - x).abs() <= 0.75 &&
                  (hit == null || (day - x).abs() < (hit - x).abs())) {
                hit = day;
              }
            }
            setState(() => _selected = hit == _selected ? null : hit);
          },
          // Nhãn trục phóng chữ tối đa 1,5 lần để không đè nhau; con số
          // đầy đủ ở danh sách bên dưới vẫn theo cỡ chữ của iPhone.
          child: SizedBox(
            height: 220,
            child: MediaQuery.withClampedTextScaling(
              maxScaleFactor: 1.5,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: LineChart(
                      duration: Duration.zero,
                      LineChartData(
                        minX: 0.5,
                        maxX: days + 0.5,
                        minY: minY,
                        maxY: maxY,
                        lineBarsData: bars,
                        showingTooltipIndicators: tooltip,
                        lineTouchData: LineTouchData(
                          enabled: false,
                          touchTooltipData: LineTouchTooltipData(
                            getTooltipColor: (_) => t.surfaceRaised,
                            fitInsideHorizontally: true,
                            fitInsideVertically: true,
                            getTooltipItems: (touched) => [
                              for (final spot in touched)
                                if (byDay[spot.x.round()] case final l?)
                                  LineTooltipItem(
                                    S.chartTooltip(
                                      Fmt.dayMonth(l.date),
                                      Fmt.kgNumber(l.startKgX10),
                                      Fmt.kgNumber(l.endKgX10),
                                      Fmt.liftUnit(unit),
                                    ),
                                    IronlyText.caption2.copyWith(
                                      color: t.textPrimary,
                                    ),
                                  )
                                else
                                  null,
                            ],
                          ),
                        ),
                        gridData: FlGridData(
                          drawVerticalLine: false,
                          horizontalInterval: step,
                          getDrawingHorizontalLine: (_) =>
                              FlLine(color: t.chartGrid, strokeWidth: 1),
                        ),
                        borderData: FlBorderData(show: false),
                        // Mốc đổi đơn vị: vạch dọc đứt, không chữ (04 Bản 4
                        // S-69; VoiceOver đọc ở nhãn biểu đồ).
                        extraLinesData: ExtraLinesData(
                          verticalLines: [
                            if (widget.change case final change?
                                when change.on.yearMonth == chart.month)
                              VerticalLine(
                                x: change.on.day.toDouble(),
                                color: t.textSecondary,
                                strokeWidth: 1.5,
                                dashArray: const [4, 4],
                              ),
                          ],
                        ),
                        titlesData: FlTitlesData(
                          rightTitles: const AxisTitles(),
                          topTitles: const AxisTitles(),
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: _leftReserved,
                              interval: step,
                              getTitlesWidget: (value, meta) => SideTitleWidget(
                                meta: meta,
                                child: Text(
                                  Fmt.kgNumber((value * 10).round()),
                                  style: IronlyText.columnLabel.copyWith(
                                    color: t.textPrefill,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 28,
                              interval: 1,
                              getTitlesWidget: (value, meta) {
                                final day = value.round();
                                // Nhãn ngày 1, 5, 10, 15, … (mock S-69-1).
                                if (value != day ||
                                    day < 1 ||
                                    day > days ||
                                    (day != 1 && day % 5 != 0)) {
                                  return const SizedBox.shrink();
                                }
                                return SideTitleWidget(
                                  meta: meta,
                                  child: Text(
                                    '$day',
                                    style: IronlyText.columnLabel.copyWith(
                                      color: t.textPrefill,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  // Đơn vị của trục mức tạ (F22-R41), góc dưới bên trái.
                  Positioned(
                    left: 0,
                    bottom: 4,
                    child: Text(
                      Fmt.liftUnit(unit),
                      key: const ValueKey('chart-axis-unit'),
                      style: IronlyText.columnLabel.copyWith(
                        color: t.textPrefill,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
