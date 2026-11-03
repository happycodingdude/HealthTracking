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

/// Mở S-23 cho buổi hôm nay [date] (từ dấu tích / gạch góc trên Hôm nay,
/// từ S-21 hôm nay). Chỉ mở cho hôm nay (04 Bản 5 S-23, UR5-05).
Future<void> showSessionStatusSheet(BuildContext context, LocalDate date) =>
    showIronlySheet<void>(
      context,
      builder: (_) => SessionStatusSheet(date: date, host: context),
    );

/// Mục của thanh chọn S-23: "Đã tập" | "Không tập" | "Chưa đánh dấu"
/// (UA5-04, FC5-13).
enum _Status { done, skipped, unmarked }

/// S-23 — Sửa trạng thái buổi (04 Bản 5 S-23): tiêu đề ngày, dòng "Nhóm cơ ·
/// giờ" chữ phụ, thanh chọn ba mục (mục chọn cam) — "Đã tập" mờ khi chưa đến
/// giờ tập và chưa tới gym (FC5-02) —, bộ viên nhóm cơ (chỉ hiển thị, không
/// mờ như mock; sửa nhóm cơ trước giờ tập ở S-21, F05-R68), nút cam "Lưu". Đổi qua lại và bỏ
/// đánh dấu được đến hết ngày (F05-R61, F05-R62); hết ngày thì đóng bảng.
class SessionStatusSheet extends ConsumerStatefulWidget {
  const SessionStatusSheet({super.key, required this.date, required this.host});

  final LocalDate date;
  final BuildContext host;

  @override
  ConsumerState<SessionStatusSheet> createState() => _SessionStatusSheetState();
}

class _SessionStatusSheetState extends ConsumerState<SessionStatusSheet> {
  _Status? _chosen;

  static _Status _of(DayMark? mark) => switch (mark) {
    DayMark.done => _Status.done,
    DayMark.skipped => _Status.skipped,
    null => _Status.unmarked,
  };

  @override
  Widget build(BuildContext context) {
    final day = ref.watch(dayProvider(widget.date)).value;
    final now = ref.watch(nowProvider);
    if (day == null || !day.isWorkout) return const SizedBox(height: 120);
    final open = DayLock.isOpen(widget.date, now);
    final current = _of(day.mark);
    final chosen = _chosen ?? current;
    final muscles = SessionRules.musclesOf(day);
    bool allowed(_Status s) => switch (s) {
      _Status.done => open && !now.isBefore(SessionRules.opensAt(day)),
      _Status.skipped || _Status.unmarked => open,
    };

    return IronlySheet(
      key: const ValueKey('status-sheet'),
      title: Fmt.weekdayDate(widget.date),
      footer: IronlyButton.primary(
        key: const ValueKey('status-save'),
        label: S.save,
        enabled: open && chosen != current && allowed(chosen),
        onPressed: () {
          final host = widget.host;
          Navigator.of(context).pop();
          if (!host.mounted) return;
          switch (chosen) {
            case _Status.done:
              SessionMarking.done(host, day);
            case _Status.skipped:
              SessionMarking.skipped(host, day);
            case _Status.unmarked:
              SessionMarking.unmark(host, day);
          }
        },
      ),
      children: [
        Text(
          '${Fmt.musclesTitle(muscles)} · ${Fmt.time(day.time!)}',
          key: const ValueKey('status-summary'),
          style: IronlyText.caption,
        ),
        const SizedBox(height: TokenSpace.s4),
        SegmentBar<_Status>(
          key: const ValueKey('status-bar'),
          items: _Status.values,
          selected: chosen,
          style: SegmentStyle.accent,
          enabled: open,
          itemEnabled: allowed,
          oneLine: true,
          label: (s) => switch (s) {
            _Status.done => S.sessionDone,
            _Status.skipped => S.sessionSkipped,
            _Status.unmarked => S.unmarked,
          },
          keyOf: (s) => ValueKey('status-${s.name}'),
          onSelected: (s) => setState(() => _chosen = s),
        ),
        const SizedBox(height: TokenSpace.s4),
        Text(S.muscleGroups, style: IronlyText.caption),
        const SizedBox(height: TokenSpace.s2),
        Wrap(
          spacing: TokenSpace.s2,
          runSpacing: TokenSpace.s2,
          children: [
            for (final m in MuscleGroup.pickerOrder)
              // Chỉ hiển thị nhóm cơ của buổi (mock S-23 Bản 5: không mờ);
              // sửa nhóm cơ trước giờ tập làm ở S-21 (F05-R68).
              IronlyChip(
                key: ValueKey('muscle-${m.name}'),
                label: Fmt.muscle(m),
                selected: muscles.contains(m),
                onTap: null,
              ),
          ],
        ),
      ],
    );
  }
}
