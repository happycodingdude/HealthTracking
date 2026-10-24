import 'dart:math' as math;

import 'package:domain/domain.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/strings_vi.dart';
import '../../../app/theme.dart';
import '../../../app/time_ticker.dart';
import '../../../core/formatters.dart';
import '../../../core/widgets/heading.dart';
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
    final palette = context.palette;
    final earliest = view?.earliest;
    final chart = view?.chart;
    final change = view?.unitChange;
    // Đơn vị hiện tại của bài (F21-R47: số cũ hiện theo đơn vị mới).
    final units = ref.watch(exerciseUnitsProvider).value;
    final unit = exercise == null ? null : displayUnit(units, exercise.id);

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
                key: const ValueKey('chart-back'),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.only(right: 12),
                ),
                onPressed: () => context.pop(),
                icon: const Icon(Icons.chevron_left),
                label: Text(
                  widget.from == ChartFrom.progress
                      ? S.backProgress
                      : S.backExerciseDetail,
                ),
              ),
            ),
            if (exercise != null) ...[
              const SizedBox(height: 8),
              Heading(
                exercise.nameVi,
                style: context.text.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 12,
                children: [
                  Text(
                    '${Fmt.muscle(exercise.group)} · '
                    '${Fmt.region(exercise.region)}',
                    style: context.text.bodyLarge?.copyWith(
                      color: palette.textSecondary,
                    ),
                  ),
                  TextButton(
                    key: const ValueKey('chart-view-exercise'),
                    style: TextButton.styleFrom(
                      textStyle: context.text.titleMedium,
                    ),
                    onPressed: _viewExercise,
                    child: const Text(S.viewExercise),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 8),
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
            const SizedBox(height: 12),
            if (chart != null && unit != null) ...[
              Container(
                key: const ValueKey('chart-card'),
                padding: const EdgeInsets.fromLTRB(8, 16, 16, 12),
                decoration: BoxDecoration(
                  color: palette.card,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: palette.border),
                ),
                child: chart.isEmpty
                    ? SizedBox(
                        height: 200,
                        child: Center(
                          child: Text(
                            S.chartMonthEmpty,
                            key: const ValueKey('chart-month-empty'),
                            textAlign: TextAlign.center,
                            style: context.text.bodyLarge?.copyWith(
                              color: palette.textSecondary,
                            ),
                          ),
                        ),
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
                          const SizedBox(height: 8),
                          ExcludeSemantics(
                            child: Text(
                              S.chartLegendUnit(Fmt.liftUnitFull(unit)),
                              key: const ValueKey('chart-legend'),
                              textAlign: TextAlign.center,
                              style: context.text.bodyMedium?.copyWith(
                                color: palette.textSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
              ),
              if (!chart.isEmpty) ...[
                const SizedBox(height: 24),
                Semantics(
                  header: true,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 4, bottom: 8),
                    child: Text(
                      S.chartSessions.toUpperCase(),
                      style: context.text.labelLarge?.copyWith(
                        color: palette.textSecondary,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ),
                ),
                Card(
                  key: const ValueKey('chart-list'),
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    children: [
                      for (final (i, l) in chart.logs.reversed.indexed) ...[
                        if (i > 0) const Divider(height: 1),
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                          // Chữ lớn không đủ một dòng thì mức tạ xuống dưới.
                          child: OverflowBar(
                            alignment: MainAxisAlignment.spaceBetween,
                            overflowAlignment: OverflowBarAlignment.start,
                            spacing: 8,
                            children: [
                              Text(
                                change != null && l.date.isBefore(change.on)
                                    ? '${Fmt.shortWeekdayDate(l.date)} '
                                          '${S.beforeUnitChange}'
                                    : Fmt.shortWeekdayDate(l.date),
                                key: ValueKey('chart-date-${l.date.toKey()}'),
                                style: context.text.bodyLarge,
                              ),
                              Text(
                                Fmt.lift(l, unit),
                                key: ValueKey('chart-row-${l.date.toKey()}'),
                                style: context.text.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ],
          ],
        ),
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
    final color = context.colors.primary;
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
            style: context.text.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
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
    final colors = context.colors;
    final palette = context.palette;
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
          color: colors.primary,
          barWidth: 2,
          dashArray: const [4, 4],
          dotData: FlDotData(
            getDotPainter: (_, _, _, _) => FlDotCirclePainter(
              radius: 5,
              color: palette.card,
              strokeColor: colors.primary,
              strokeWidth: 2.5,
            ),
          ),
        ),
    ];
    final endBars = [
      for (final seg in segments)
        LineChartBarData(
          spots: [for (final l in seg) spot(l, l.endKgX10)],
          color: colors.primary,
          barWidth: 2.5,
          dotData: FlDotData(
            getDotPainter: (s, _, _, _) {
              final l = byDay[s.x.round()];
              final same = l != null && l.startKgX10 == l.endKgX10;
              return FlDotCirclePainter(
                radius: same ? 7.5 : 5,
                color: colors.primary,
                strokeColor: same ? colors.onPrimaryContainer : colors.primary,
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
                            getTooltipColor: (_) => colors.inverseSurface,
                            fitInsideHorizontally: true,
                            fitInsideVertically: true,
                            getTooltipItems: (touched) => [
                              for (final t in touched)
                                if (byDay[t.x.round()] case final l?)
                                  LineTooltipItem(
                                    S.chartTooltip(
                                      Fmt.dayMonth(l.date),
                                      Fmt.kgNumber(l.startKgX10),
                                      Fmt.kgNumber(l.endKgX10),
                                      Fmt.liftUnit(unit),
                                    ),
                                    context.text.bodyMedium!.copyWith(
                                      color: colors.onInverseSurface,
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
                              FlLine(color: palette.border, strokeWidth: 1),
                        ),
                        borderData: FlBorderData(show: false),
                        // Mốc đổi đơn vị: đường dọc nét đứt vàng nhạt, nhãn "Đổi
                        // sang {đơn vị}" (F22-R42, UA3-13).
                        extraLinesData: ExtraLinesData(
                          verticalLines: [
                            if (widget.change case final change?
                                when change.on.yearMonth == chart.month)
                              VerticalLine(
                                x: change.on.day.toDouble(),
                                color: palette.reference,
                                strokeWidth: 1.5,
                                dashArray: const [4, 4],
                                label: VerticalLineLabel(
                                  show: true,
                                  alignment: Alignment.topRight,
                                  padding: const EdgeInsets.only(
                                    left: 6,
                                    top: 2,
                                  ),
                                  style: context.text.bodySmall?.copyWith(
                                    color: palette.reference,
                                    backgroundColor: palette.referenceContainer,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  labelResolver: (_) =>
                                      S.changeUnitTo(Fmt.liftUnit(change.to)),
                                ),
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
                                  style: context.text.bodySmall?.copyWith(
                                    color: palette.textSecondary,
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
                                    style: context.text.bodySmall?.copyWith(
                                      color: palette.textSecondary,
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
                      style: context.text.bodySmall?.copyWith(
                        color: palette.textSecondary,
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
