import 'package:flutter/material.dart';

import '../keys.dart';
import '../theme.dart';
import 'status_glyph.dart';

/// Loại ô ngày trên lịch tháng (04 Bản 4 S-20).
enum MonthCellKind {
  /// Cam = đã tập.
  done,

  /// Thẻ = ngày tập sắp tới.
  upcoming,

  /// Thẻ nổi + số chữ phụ = không tập.
  skipped,

  /// Viền cam + số cam = hôm nay (chờ đánh dấu, hoặc hôm nay nghỉ).
  today,

  /// Trong suốt + số rất mờ = nghỉ.
  rest,
}

typedef MonthCell = ({
  String dateKey,
  int day,
  MonthCellKind kind,
  bool extra,
  bool overridden,
  String semantics,
});

/// Lưới 7 cột ô vuông bo 8 (04 Bản 4 S-20): hàng T2…CN chữ phụ 10; ô màu
/// theo trạng thái; "+" góc = buổi thêm; chấm dưới = sửa riêng. [leading] =
/// số ô trống trước ngày 1 (thứ 2 = 0). Mỗi ô có nhãn VoiceOver.
class MonthGrid extends StatelessWidget {
  const MonthGrid({
    super.key,
    required this.weekdayLabels,
    required this.leading,
    required this.cells,
    required this.onTap,
    this.extraLabel,
    this.overriddenLabel,
  });

  final List<String> weekdayLabels;
  final int leading;
  final List<MonthCell> cells;
  final ValueChanged<MonthCell> onTap;
  final String? extraLabel;
  final String? overriddenLabel;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final rows = <List<MonthCell?>>[];
    var row = List<MonthCell?>.filled(7, null);
    var col = leading;
    for (final c in cells) {
      row[col] = c;
      col++;
      if (col == 7) {
        rows.add(row);
        row = List<MonthCell?>.filled(7, null);
        col = 0;
      }
    }
    if (col > 0) rows.add(row);
    return Column(
      children: [
        Row(
          children: [
            for (final l in weekdayLabels)
              Expanded(
                child: Text(
                  l,
                  textAlign: TextAlign.center,
                  style: IronlyText.caption.copyWith(
                    fontSize: TokenType.widgetCaption,
                    color: t.textSecondary,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: TokenSpace.s2),
        for (final r in rows)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: [
                for (final c in r)
                  Expanded(
                    child: c == null
                        ? const SizedBox.shrink()
                        : _Cell(
                            cell: c,
                            onTap: () => onTap(c),
                            extraLabel: extraLabel,
                            overriddenLabel: overriddenLabel,
                          ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

class _Cell extends StatelessWidget {
  const _Cell({
    required this.cell,
    required this.onTap,
    this.extraLabel,
    this.overriddenLabel,
  });

  final MonthCell cell;
  final VoidCallback onTap;
  final String? extraLabel;
  final String? overriddenLabel;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final (Color? fill, Color? border, Color text) = switch (cell.kind) {
      MonthCellKind.done => (t.accent, null, t.onAccent),
      MonthCellKind.upcoming => (t.surface, null, t.textPrimary),
      MonthCellKind.skipped => (t.surfaceRaised, null, t.textSecondary),
      MonthCellKind.today => (null, t.accent, t.accent),
      MonthCellKind.rest => (null, null, t.textFaint),
    };
    return Semantics(
      button: true,
      label: cell.semantics,
      child: ExcludeSemantics(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: AspectRatio(
              aspectRatio: 1,
              child: Container(
                key: K.monthCell(cell.dateKey),
                decoration: BoxDecoration(
                  color: fill,
                  borderRadius: BorderRadius.circular(TokenRadius.calendarCell),
                  border: border == null
                      ? null
                      : Border.all(color: border, width: TokenSize.fieldStroke),
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        '${cell.day}',
                        style: IronlyText.body.copyWith(
                          color: text,
                          fontWeight: cell.kind == MonthCellKind.rest
                              ? FontWeight.w400
                              : FontWeight.w600,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                    if (cell.extra)
                      Positioned(
                        top: 1,
                        right: 3,
                        child: Semantics(
                          label: extraLabel,
                          child: Text(
                            '+',
                            style: IronlyText.caption.copyWith(
                              color: cell.kind == MonthCellKind.done
                                  ? t.onAccent
                                  : t.accent,
                              fontWeight: FontWeight.w600,
                              height: 1,
                            ),
                          ),
                        ),
                      ),
                    if (cell.overridden)
                      Positioned(
                        bottom: 3,
                        child: OverrideDot(label: overriddenLabel ?? ''),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
