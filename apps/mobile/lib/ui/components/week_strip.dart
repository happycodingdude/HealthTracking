import 'package:flutter/material.dart';

import '../keys.dart';
import '../theme.dart';
import 'status_glyph.dart';

/// Một ngày trên dải tuần.
typedef WeekStripDay = ({
  String dateKey,
  String label,
  GlyphStatus status,
  String semantics,
  bool highlighted,
});

/// Dải 6 vòng T2 → T7 với dấu hiệu từng ngày (04 Bản 4 S-10 thẻ Tuần này,
/// S-25). Nhãn ngày 10 chữ phụ, hôm nay cam. Cỡ chữ lớn nhất: hai hàng.
class WeekStrip extends StatelessWidget {
  const WeekStrip({
    super.key,
    required this.days,
    this.glyphSize = TokenSize.glyphStrip,
    this.onTap,
  });

  final List<WeekStripDay> days;
  final double glyphSize;
  final ValueChanged<WeekStripDay>? onTap;

  static const stackedScale = 2.0;

  @override
  Widget build(BuildContext context) {
    final stacked = MediaQuery.textScalerOf(context).scale(1) >= stackedScale;
    final cells = [for (final d in days) _Cell(d, glyphSize, onTap)];
    if (stacked && cells.length > 3) {
      return Column(
        children: [
          Row(children: cells.sublist(0, 3)),
          const SizedBox(height: TokenSpace.s3),
          Row(children: cells.sublist(3)),
        ],
      );
    }
    return Row(children: cells);
  }
}

class _Cell extends StatelessWidget {
  const _Cell(this.day, this.size, this.onTap);

  final WeekStripDay day;
  final double size;
  final ValueChanged<WeekStripDay>? onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Expanded(
      child: Semantics(
        container: true,
        button: onTap != null,
        label: '${day.label}: ${day.semantics}',
        child: ExcludeSemantics(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onTap == null ? null : () => onTap!(day),
            child: Column(
              key: K.weekCell(day.dateKey),
              children: [
                StatusGlyph(day.status, label: day.semantics, size: size),
                const SizedBox(height: 5),
                Text(
                  day.label,
                  style: IronlyText.caption.copyWith(
                    fontSize: TokenType.widgetCaption,
                    color: day.highlighted ? t.accent : t.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
