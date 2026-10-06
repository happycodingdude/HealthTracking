import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../app/strings_vi.dart';
import '../../../app/theme.dart';
import '../../../app/time_ticker.dart';
import '../../../core/formatters.dart';
import '../../../core/widgets/app_sheet.dart';
import '../../../core/widgets/heading.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/session_tag.dart';
import '../../../core/widgets/toast.dart';
import '../../../core/widgets/unsaved_changes.dart';
import '../../today/application/mark_session.dart';
import '../application/schedule_providers.dart';
import 'muscle_picker.dart';

/// Mở S-23 cho buổi tập ngày [date] (NAV-5).
Future<void> showMarkSessionSheet(BuildContext context, LocalDate date) =>
    showAppSheet<void>(
      context,
      // Có lựa chọn chưa lưu: tự bắt cử chỉ vuốt để hỏi trước (Q-2).
      enableDrag: false,
      builder: (_) => MarkSessionSheet(date: date),
    );

/// S-23 — Đánh dấu buổi tập (04 §6.8): "Đã tập" / "Không tập"; chọn "Đã tập"
/// thì có bộ chọn nhóm cơ điền sẵn (F05-V1). Chưa đến giờ: chỉ hiện "Đánh dấu
/// được từ {giờ}" (F05-E1). Đã khóa: chỉ xem (F05-E3).
class MarkSessionSheet extends ConsumerStatefulWidget {
  const MarkSessionSheet({super.key, required this.date});

  final LocalDate date;

  @override
  ConsumerState<MarkSessionSheet> createState() => _MarkSessionSheetState();
}

class _MarkSessionSheetState extends ConsumerState<MarkSessionSheet> {
  DayMark? _initialChoice;
  List<MuscleGroup> _initialMuscles = const [];
  DayMark _choice = DayMark.done;
  List<MuscleGroup> _muscles = const [];
  bool _showError = false;

  void _init(PlanDay day) {
    if (_initialChoice != null) return;
    // Chưa đánh dấu: chọn sẵn "Đã tập" với nhóm cơ theo lịch (F05 luồng J-02).
    _initialChoice = day.mark ?? DayMark.done;
    _initialMuscles = day.actualMuscles ?? day.muscles;
    _choice = _initialChoice!;
    _muscles = _initialMuscles;
  }

  bool get _dirty =>
      _choice != _initialChoice ||
      _muscles.length != _initialMuscles.length ||
      _muscles.any((m) => !_initialMuscles.contains(m));

  Future<void> _save() async {
    if (_choice == DayMark.done && _muscles.isEmpty) {
      setState(() => _showError = true);
      return;
    }
    try {
      await ref
          .read(markSessionProvider)
          .call(widget.date, _choice, actual: _muscles);
    } on MarkException catch (e, st) {
      await ref
          .read(errorReporterProvider)
          .report(e, st, reason: 'mark_session');
      return;
    }
    if (!mounted) return;
    showToast(
      context,
      _choice == DayMark.done
          ? S.markedDone(Fmt.muscles(_muscles))
          : S.markedSkipped,
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final day = ref.watch(dayProvider(widget.date)).value;
    final now = ref.watch(nowProvider);
    if (day == null || !day.isWorkout) return const SizedBox(height: 120);
    _init(day);
    final status = SessionStatus.derive(day, now)!;
    final palette = context.palette;
    final editable = status.state != SessionState.upcoming && !status.locked;

    return UnsavedChangesGuard(
      dirty: editable && _dirty,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Heading(
              Fmt.weekdayDate(widget.date),
              style: context.text.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              S.plannedLine(Fmt.muscles(day.muscles), Fmt.time(day.time!)),
              style: context.text.bodyLarge?.copyWith(
                color: palette.textSecondary,
              ),
            ),
            const SizedBox(height: 20),
            if (status.state == SessionState.upcoming)
              Text(
                S.markableFrom(Fmt.time(day.time!)),
                style: context.text.bodyLarge,
              )
            else if (status.locked)
              ..._locked(context, day, status)
            else ...[
              _Choice(
                value: _choice,
                onChanged: (v) => setState(() {
                  _choice = v;
                  _showError = false;
                }),
              ),
              if (_choice == DayMark.done) ...[
                const SizedBox(height: 20),
                Text(
                  S.actualMusclesLabel,
                  style: context.text.bodyLarge?.copyWith(
                    color: palette.textSecondary,
                  ),
                ),
                const SizedBox(height: 12),
                MusclePicker(
                  selected: _muscles,
                  onChanged: (m) => setState(() {
                    _muscles = m;
                    if (m.isNotEmpty) _showError = false;
                  }),
                ),
                if (_showError)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Semantics(
                      liveRegion: true,
                      child: Text(
                        S.missingActualMuscles,
                        style: context.text.bodyMedium?.copyWith(
                          color: context.colors.error,
                        ),
                      ),
                    ),
                  ),
              ],
              const SizedBox(height: 24),
              PrimaryButton(label: S.save, onPressed: _save),
            ],
          ],
        ),
      ),
    );
  }

  List<Widget> _locked(
    BuildContext context,
    PlanDay day,
    SessionStatus status,
  ) => [
    Align(alignment: Alignment.centerLeft, child: SessionTag(status)),
    if (day.mark == DayMark.done && day.actualMuscles != null) ...[
      const SizedBox(height: 12),
      Text(
        Fmt.muscles(day.actualMuscles!),
        style: context.text.titleMedium?.copyWith(fontWeight: FontWeight.w700),
      ),
    ],
    const SizedBox(height: 12),
    Row(
      children: [
        ExcludeSemantics(
          child: Icon(Icons.lock, size: 18, color: context.palette.neutral),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            S.lockedNote,
            style: context.text.bodyLarge?.copyWith(
              color: context.palette.textSecondary,
            ),
          ),
        ),
      ],
    ),
  ];
}

/// Hai lựa chọn "Đã tập" · "Không tập" (mock S-23).
class _Choice extends StatelessWidget {
  const _Choice({required this.value, required this.onChanged});

  final DayMark value;
  final ValueChanged<DayMark> onChanged;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    Widget option(DayMark mark, String label) {
      final selected = value == mark;
      return Expanded(
        child: Semantics(
          button: true,
          selected: selected,
          label: label,
          child: ExcludeSemantics(
            child: InkWell(
              key: ValueKey('choice-${mark.name}'),
              borderRadius: BorderRadius.circular(12),
              onTap: () => onChanged(mark),
              child: Container(
                constraints: const BoxConstraints(minHeight: 44),
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: selected ? palette.card : null,
                  borderRadius: BorderRadius.circular(12),
                  border: selected ? Border.all(color: palette.border) : null,
                ),
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: context.text.titleMedium?.copyWith(
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                    color: selected ? null : palette.textSecondary,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: palette.neutralContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          option(DayMark.done, S.sessionDone),
          option(DayMark.skipped, S.sessionSkipped),
        ],
      ),
    );
  }
}
