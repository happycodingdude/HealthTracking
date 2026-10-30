import 'package:domain/domain.dart';
import 'package:flutter/material.dart';

import '../../../app/strings_vi.dart';
import '../../../core/formatters.dart';
import '../../../ui/components/components.dart';
import '../../../ui/theme.dart';

/// Một dòng buổi / ngày (04 Bản 4 S-20 danh sách tuần, S-25): bên trái tên
/// nhóm cơ 14 / 500 (hoặc "Nghỉ" chữ phụ, "Nghỉ + Tay sau" với phần cam) và
/// "Thứ · giờ" chữ phụ; bên phải dấu hiệu trạng thái (03 Bản 4 §6.4). Ở S-25
/// [compact] = "T2 19" chữ phụ · nhóm cơ · dấu hiệu.
class DayLine extends StatelessWidget {
  const DayLine({
    super.key,
    required this.date,
    required this.day,
    required this.now,
    this.compact = false,
    this.onTap,
  });

  final LocalDate date;

  /// null với chủ nhật (luôn nghỉ, không có bản ghi).
  final PlanDay? day;
  final DateTime now;

  /// Dạng S-25: cột ngày "T2 19" bên trái.
  final bool compact;
  final VoidCallback? onTap;

  /// Dấu hiệu và nhãn VoiceOver của buổi / ngày.
  static (GlyphStatus, String)? glyphOf(PlanDay? d, DateTime now) {
    if (d == null) return null;
    final status = SessionStatus.derive(d, now);
    if (status != null) {
      final (g, label) = switch (status.state) {
        SessionState.done => (GlyphStatus.done, S.sessionDone),
        SessionState.awaitingMark => (GlyphStatus.pending, S.statusAwaiting),
        SessionState.upcoming => (GlyphStatus.upcoming, S.statusUpcoming),
        SessionState.skipped => (GlyphStatus.skipped, S.sessionSkipped),
        SessionState.autoSkipped => (GlyphStatus.skipped, S.statusAutoSkipped),
      };
      return (g, status.locked ? '$label, ${S.statusLocked}' : label);
    }
    if (d.extraMuscles != null) return (GlyphStatus.extra, S.extraSession);
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final d = day;
    final extra = d?.extraMuscles;
    final glyph = glyphOf(d, now);
    final workout = d != null && d.isWorkout;
    final Widget title = workout
        ? Text(
            Fmt.musclesTitle(SessionRules.musclesOf(d)),
            style: IronlyText.body,
          )
        : Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: S.rest,
                  style: TextStyle(color: t.textSecondary),
                ),
                if (extra != null)
                  TextSpan(
                    text: ' + ${Fmt.musclesTitle(extra)}',
                    style: TextStyle(color: t.accent),
                  ),
              ],
            ),
            style: IronlyText.body,
          );
    final info = workout
        ? '${Fmt.weekday(date)} · ${Fmt.time(d.time!)}'
        : Fmt.weekday(date);
    final semantics = [
      Fmt.weekdayDate(date),
      workout
          ? '${Fmt.muscles(SessionRules.musclesOf(d))} · ${Fmt.time(d.time!)}'
          : extra != null
          ? S.restWithExtra(Fmt.muscles(extra))
          : S.rest,
      if (glyph != null) glyph.$2,
      if (d?.source == DaySource.override) S.overridden,
    ].join(', ');
    final trailing = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (d?.source == DaySource.override) ...[
          const OverrideDot(label: S.overridden),
          const SizedBox(width: TokenSpace.s2),
        ],
        if (glyph != null)
          StatusGlyph(glyph.$1, label: glyph.$2)
        else
          const SizedBox(width: TokenSize.glyph),
      ],
    );
    if (compact) {
      return Semantics(
        button: onTap != null,
        label: semantics,
        child: ExcludeSemantics(
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: TokenSize.cardPadding,
                vertical: TokenSpace.s3,
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 52,
                    child: Text(
                      '${S.weekdaysShort[date.weekday - 1]} ${date.day}',
                      style: IronlyText.body.copyWith(color: t.textSecondary),
                    ),
                  ),
                  Expanded(child: title),
                  trailing,
                ],
              ),
            ),
          ),
        ),
      );
    }
    return Semantics(
      button: onTap != null,
      label: semantics,
      child: ExcludeSemantics(
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: TokenSize.cardPadding,
              vertical: TokenSpace.s3,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      title,
                      Text(info, style: IronlyText.caption),
                    ],
                  ),
                ),
                trailing,
              ],
            ),
          ),
        ),
      ),
    );
  }
}
