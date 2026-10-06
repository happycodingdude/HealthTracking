import 'package:domain/domain.dart';
import 'package:flutter/material.dart';

import '../../../app/strings_vi.dart';
import '../../../app/theme.dart';
import '../../../core/formatters.dart';
import '../../../core/widgets/session_tag.dart';

/// Một ngày trong danh sách S-20 và S-25: "T4 07/10", "Lưng · 18:00" hoặc
/// "Nghỉ", nhãn trạng thái (04 §6.13.3).
class DayLine extends StatelessWidget {
  const DayLine({
    super.key,
    required this.date,
    required this.day,
    required this.now,
    this.highlightToday = true,
  });

  final LocalDate date;

  /// null với chủ nhật (luôn nghỉ, không có bản ghi).
  final PlanDay? day;
  final DateTime now;

  /// Tô nổi bật dòng hôm nay (S-20).
  final bool highlightToday;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final today = LocalDate.fromDateTime(now);
    final d = day;
    final status = d == null ? null : SessionStatus.derive(d, now);
    final past = date.isBefore(today);
    final isToday = highlightToday && date == today;
    final extra = d?.extraMuscles;
    final info = d != null && d.isWorkout
        ? '${Fmt.muscles(d.muscles)} · ${Fmt.time(d.time!)}'
        : extra != null
        // Buổi tập thêm hiện trong dòng của ngày đó (04 S-20, mock S-25).
        ? S.restWithExtra(Fmt.muscles(extra))
        : S.rest;
    final color = past ? palette.textSecondary : null;
    final dateText = Text(
      Fmt.shortWeekdayDate(date),
      style: context.text.bodyLarge?.copyWith(
        fontWeight: FontWeight.w700,
        color: color,
      ),
    );
    final infoText = Text(
      info,
      style: context.text.bodyLarge?.copyWith(
        color: d != null && d.isWorkout ? color : palette.textSecondary,
      ),
    );
    final tags = [
      if (status != null) SessionTag(status),
      if (extra != null) const ExtraSessionTag(),
      if (d?.source == DaySource.override)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: context.colors.primaryContainer,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            S.overridden,
            style: context.text.labelLarge?.copyWith(
              color: context.colors.onPrimaryContainer,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
    ];
    // Cỡ chữ lớn: ngày, nội dung và nhãn xếp dọc, không cắt chữ (UX-AC18).
    final stacked = MediaQuery.textScalerOf(context).scale(1) >= 1.6;
    return Container(
      color: isToday ? context.colors.primaryContainer : null,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: stacked
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                dateText,
                infoText,
                if (tags.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Wrap(spacing: 8, runSpacing: 6, children: tags),
                ],
              ],
            )
          : Row(
              children: [
                SizedBox(width: 96, child: dateText),
                // Nội dung và nhãn không đủ một hàng thì nhãn xuống dưới,
                // không ép nội dung thành cột hẹp (nhãn "Không tập · tự động").
                Expanded(
                  child: Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      infoText,
                      if (tags.isNotEmpty)
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            for (final (i, t) in tags.indexed) ...[
                              if (i > 0) const SizedBox(height: 4),
                              t,
                            ],
                          ],
                        ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}
