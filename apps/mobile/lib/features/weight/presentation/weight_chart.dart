import 'dart:math' as math;

import 'package:domain/domain.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../app/strings_vi.dart';
import '../../../core/formatters.dart';
import '../../../ui/theme.dart';

/// Biểu đồ cân nặng 8 tuần (04 Bản 4 S-40, F07-R6, UA-13): đường cam, điểm
/// đặc, điểm mới nhất rỗng, đường ngắt ở tuần không ghi; trục mờ, chỉ nhãn
/// đầu – cuối; vuốt ngang xem tuần cũ hơn; chạm điểm xem số cân và tuần.
/// Con số, trục, mốc như Bản 1 (F4-R8).
class WeightChart extends StatefulWidget {
  const WeightChart({super.key, required this.weeks, required this.log});

  /// Các tuần từ tuần thiết lập đến tuần hiện tại, cũ → mới.
  final List<LocalDate> weeks;
  final WeightLog log;

  /// UA-13: số tuần hiện cùng lúc.
  static const visibleWeeks = 8;

  @override
  State<WeightChart> createState() => _WeightChartState();
}

class _WeightChartState extends State<WeightChart> {
  /// Số tuần đã lùi về quá khứ so với tuần hiện tại (0 = 8 tuần gần nhất).
  double _offset = 0;

  /// Chỉ số tuần đang chạm để xem số cân.
  int? _selected;

  static const _rightReserved = 36.0;

  int get _count => widget.weeks.length;

  double get _maxOffset =>
      math.max(0, _count - WeightChart.visibleWeeks).toDouble();

  /// Khoảng đệm hai bên (tính theo tuần) để điểm ở mép không bị cắt.
  static const _pad = 0.35;

  ({double minX, double maxX}) get _window {
    final last = _count - 1 - _offset;
    return (
      minX: last - (WeightChart.visibleWeeks - 1) - _pad,
      maxX: last + _pad,
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final index = {for (var i = 0; i < _count; i++) widget.weeks[i]: i};
    final spots = <({int i, int kgX10})>[
      for (final p in widget.log.points)
        if (index[p.week] case final i?) (i: i, kgX10: p.kgX10),
    ];
    final latestIndex = spots.isEmpty ? null : spots.last.i;
    final (:minX, :maxX) = _window;
    final visible = [
      for (final s in spots)
        if (s.i >= minX - 1 && s.i <= maxX + 1) s.kgX10,
    ];
    final range = visible.isEmpty ? [for (final s in spots) s.kgX10] : visible;
    final lo = range.isEmpty ? 0 : ((range.reduce(math.min) - 2) / 10).floor();
    final hi = range.isEmpty ? 1 : ((range.reduce(math.max) + 2) / 10).ceil();
    final step = math.max(1, ((hi - lo) / 4).ceil());
    final minY = (lo / step).floor() * step;
    final maxY = math.max((hi / step).ceil() * step, minY + step);
    final interval = step.toDouble();

    // Đường ngắt ở tuần không ghi (F07-R6): mỗi đoạn là các tuần liền nhau.
    final segments = <List<FlSpot>>[];
    for (final s in spots) {
      final spot = FlSpot(s.i.toDouble(), s.kgX10 / 10);
      if (segments.isNotEmpty && segments.last.last.x == s.i - 1) {
        segments.last.add(spot);
      } else {
        segments.add([spot]);
      }
    }
    final bars = [
      for (final seg in segments)
        LineChartBarData(
          spots: seg,
          color: t.chartLine,
          barWidth: 2.5,
          dotData: FlDotData(
            // Điểm mới nhất rỗng, còn lại đặc (04 Bản 4 S-40).
            getDotPainter: (spot, _, _, _) => FlDotCirclePainter(
              radius: spot.x == latestIndex ? 5.5 : 4,
              color: spot.x == latestIndex ? t.surface : t.chartLine,
              strokeColor: t.chartLine,
              strokeWidth: 2,
            ),
          ),
        ),
    ];
    final selected = _selected;
    final tooltip = <ShowingTooltipIndicators>[
      if (selected != null)
        for (var b = 0; b < bars.length; b++)
          for (final s in bars[b].spots)
            if (s.x == selected)
              ShowingTooltipIndicators([LineBarSpot(bars[b], b, s)]),
    ];
    final firstVisible = math.max(0, minX.ceil());
    final lastVisible = math.min(_count - 1, maxX.floor());

    // Cỡ chữ lớn (TA4-04): chừa chỗ cho nhãn trục theo tỷ lệ chữ.
    final scale = MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 2.0);
    final rightReserved = _rightReserved * scale;
    return LayoutBuilder(
      builder: (context, constraints) {
        final drawWidth = constraints.maxWidth - rightReserved;
        final weekWidth = drawWidth / (maxX - minX);
        return GestureDetector(
          key: const ValueKey('weight-chart'),
          onHorizontalDragUpdate: (d) => setState(() {
            _offset = (_offset + d.delta.dx / weekWidth).clamp(0, _maxOffset);
          }),
          onHorizontalDragEnd: (_) =>
              setState(() => _offset = _offset.roundToDouble()),
          onTapUp: (d) {
            final x = minX + d.localPosition.dx / weekWidth;
            final hit = spots
                .where((s) => (s.i - x).abs() <= 0.5)
                .map((s) => s.i)
                .firstOrNull;
            setState(() => _selected = hit == _selected ? null : hit);
          },
          child: SizedBox(
            // Cỡ chữ lớn: cao hơn để nhãn trục không chồng nhau (TA4-04).
            height: 160 * scale,
            child: LineChart(
              duration: Duration.zero,
              LineChartData(
                minX: minX,
                maxX: maxX,
                minY: minY.toDouble(),
                maxY: maxY.toDouble(),
                clipData: const FlClipData.horizontal(),
                lineBarsData: bars,
                showingTooltipIndicators: tooltip,
                lineTouchData: LineTouchData(
                  enabled: false,
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipColor: (_) => t.surfaceRaised,
                    getTooltipItems: (touched) => [
                      for (final tt in touched)
                        LineTooltipItem(
                          '${Fmt.kg((tt.y * 10).round())}\n'
                          '${S.weekLabel(Fmt.dayMonth(widget.weeks[tt.x.round()]))}',
                          IronlyText.caption2,
                        ),
                    ],
                  ),
                ),
                gridData: FlGridData(
                  drawVerticalLine: false,
                  horizontalInterval: interval,
                  getDrawingHorizontalLine: (_) =>
                      FlLine(color: t.chartGrid, strokeWidth: 1),
                ),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  leftTitles: const AxisTitles(),
                  topTitles: const AxisTitles(),
                  rightTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: rightReserved,
                      interval: interval,
                      getTitlesWidget: (value, meta) => SideTitleWidget(
                        meta: meta,
                        child: Text(
                          Fmt.integer(value.round()),
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
                      reservedSize: 22 * scale,
                      interval: 1,
                      getTitlesWidget: (value, meta) {
                        final i = value.round();
                        // Chỉ nhãn đầu – cuối của khung đang xem.
                        if (value != i ||
                            i < 0 ||
                            i >= _count ||
                            (i != firstVisible && i != lastVisible)) {
                          return const SizedBox.shrink();
                        }
                        return SideTitleWidget(
                          meta: meta,
                          child: Text(
                            Fmt.dayMonth(widget.weeks[i]),
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
        );
      },
    );
  }
}
