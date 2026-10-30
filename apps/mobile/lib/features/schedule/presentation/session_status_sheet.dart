import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/strings_vi.dart';
import '../../../app/time_ticker.dart';
import '../../../core/formatters.dart';
import '../../../ui/components/components.dart';
import '../../../ui/theme.dart';
import '../application/schedule_providers.dart';
import 'session_marking.dart';

/// Mở S-23 cho buổi ngày [date] (từ dấu tích / gạch góc trên Hôm nay).
Future<void> showSessionStatusSheet(BuildContext context, LocalDate date) =>
    showIronlySheet<void>(
      context,
      builder: (_) => SessionStatusSheet(date: date, host: context),
    );

/// S-23 — Sửa trạng thái buổi / nhóm cơ (04 Bản 4 S-23): tiêu đề ngày, thanh
/// chọn Đã tập / Không tập (mục chọn cam), bộ viên nhóm cơ, Lưu. Quy tắc giữ
/// nguyên Bản 2: buổi "Đã tập" đã chốt khi lưu (UR2-06) và nhóm cơ thực tế =
/// nhóm cơ của lịch nên thanh chọn và viên nhóm cơ mờ; buổi "Không tập" đổi
/// được sang Đã tập trong 7 ngày (F05-R27, qua hộp S-65); quá 7 ngày: mờ
/// (F4-R6).
class SessionStatusSheet extends ConsumerStatefulWidget {
  const SessionStatusSheet({super.key, required this.date, required this.host});

  final LocalDate date;
  final BuildContext host;

  @override
  ConsumerState<SessionStatusSheet> createState() => _SessionStatusSheetState();
}

class _SessionStatusSheetState extends ConsumerState<SessionStatusSheet> {
  DayMark? _chosen;

  @override
  Widget build(BuildContext context) {
    final day = ref.watch(dayProvider(widget.date)).value;
    final now = ref.watch(nowProvider);
    if (day == null) return const SizedBox(height: 120);
    final current = day.mark == DayMark.done ? DayMark.done : DayMark.skipped;
    final situation = OverrideRules.situation(widget.date, day, now);
    final canChange = situation == DaySituation.changeToDone;
    final chosen = _chosen ?? current;
    final muscles = SessionRules.musclesOf(day);

    return IronlySheet(
      key: const ValueKey('status-sheet'),
      title: Fmt.weekdayDate(widget.date),
      footer: IronlyButton.primary(
        key: const ValueKey('status-save'),
        label: S.save,
        enabled: canChange && chosen != current,
        onPressed: () {
          final host = widget.host;
          Navigator.of(context).pop();
          if (host.mounted) SessionMarking.done(host, day);
        },
      ),
      children: [
        SegmentBar<DayMark>(
          key: const ValueKey('status-bar'),
          items: const [DayMark.done, DayMark.skipped],
          selected: chosen,
          style: SegmentStyle.accent,
          enabled: canChange,
          label: (m) => m == DayMark.done ? S.sessionDone : S.sessionSkipped,
          keyOf: (m) => ValueKey('status-${m.name}'),
          onSelected: (m) => setState(() => _chosen = m),
        ),
        const SizedBox(height: TokenSpace.s4),
        Text(S.muscleGroups, style: IronlyText.caption),
        const SizedBox(height: TokenSpace.s2),
        Wrap(
          spacing: TokenSpace.s2,
          runSpacing: TokenSpace.s2,
          children: [
            for (final m in MuscleGroup.pickerOrder)
              IronlyChip(
                key: ValueKey('muscle-${m.name}'),
                label: Fmt.muscle(m),
                selected: muscles.contains(m),
                enabled: false,
                onTap: null,
              ),
          ],
        ),
      ],
    );
  }
}
