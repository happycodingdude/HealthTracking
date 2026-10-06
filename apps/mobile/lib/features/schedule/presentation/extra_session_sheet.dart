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
import '../../../core/widgets/toast.dart';
import '../../../core/widgets/unsaved_changes.dart';
import '../../today/application/log_extra_session.dart';
import '../application/schedule_providers.dart';
import 'muscle_picker.dart';

/// Mở S-24 cho ngày [date]. Chỉ gọi khi [ExtraSessionRules.canLog] (F05-AC6).
Future<void> showExtraSessionSheet(BuildContext context, LocalDate date) =>
    showAppSheet<void>(
      context,
      // Có lựa chọn chưa lưu: tự bắt cử chỉ vuốt để hỏi trước (Q-2).
      enableDrag: false,
      builder: (_) => ExtraSessionSheet(date: date),
    );

/// S-24 — Buổi tập thêm (04 S-24): bộ chọn nhóm cơ (F05-V2), "Lưu"; khi sửa
/// có thêm "Xóa buổi tập thêm" qua hộp xác nhận (NAV-6). Không tính vào kế
/// hoạch tuần (F05-R12).
class ExtraSessionSheet extends ConsumerStatefulWidget {
  const ExtraSessionSheet({super.key, required this.date});

  final LocalDate date;

  @override
  ConsumerState<ExtraSessionSheet> createState() => _ExtraSessionSheetState();
}

class _ExtraSessionSheetState extends ConsumerState<ExtraSessionSheet> {
  List<MuscleGroup>? _initial;
  List<MuscleGroup> _muscles = const [];
  bool _showError = false;

  void _init(PlanDay day) {
    if (_initial != null) return;
    _initial = day.extraMuscles ?? const [];
    _muscles = _initial!;
  }

  bool get _editing => _initial?.isNotEmpty ?? false;

  bool get _dirty =>
      _muscles.length != _initial!.length ||
      _muscles.any((m) => !_initial!.contains(m));

  /// false khi không ghi được (đã báo lỗi kỹ thuật).
  Future<bool> _log(List<MuscleGroup>? muscles) async {
    try {
      await ref.read(logExtraSessionProvider).call(widget.date, muscles);
      return true;
    } on ExtraException catch (e, st) {
      // Bảng chỉ mở khi ghi được; lỗi ở đây là vừa qua hạn khi đang mở.
      await ref
          .read(errorReporterProvider)
          .report(e, st, reason: 'extra_session');
      return false;
    }
  }

  Future<void> _save() async {
    if (_muscles.isEmpty) {
      setState(() => _showError = true);
      return;
    }
    if (!await _log(_muscles) || !mounted) return;
    showToast(context, S.markedDone(Fmt.muscles(_muscles)));
    Navigator.of(context).pop();
  }

  Future<void> _delete() async {
    final confirmed = await _confirmDelete(context, widget.date);
    if (!confirmed || !mounted) return;
    if (!await _log(null) || !mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final day = ref.watch(dayProvider(widget.date)).value;
    final now = ref.watch(nowProvider);
    if (day == null || day.isWorkout) return const SizedBox(height: 120);
    _init(day);
    final palette = context.palette;
    final editable = ExtraSessionRules.canLog(day, now);

    return UnsavedChangesGuard(
      dirty: editable && _dirty,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Heading(
              S.extraSessionTitle(
                Fmt.weekdayDate(widget.date),
                today: widget.date == LocalDate.fromDateTime(now),
              ),
              style: context.text.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              S.extraNotCounted,
              style: context.text.bodyLarge?.copyWith(
                color: palette.textSecondary,
              ),
            ),
            const SizedBox(height: 20),
            if (!editable)
              Text(
                S.lockedNote,
                style: context.text.bodyLarge?.copyWith(
                  color: palette.textSecondary,
                ),
              )
            else ...[
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
              const SizedBox(height: 24),
              PrimaryButton(label: S.save, onPressed: _save),
              if (_editing) ...[
                const SizedBox(height: 8),
                TextButton(
                  key: const ValueKey('extra-delete'),
                  style: TextButton.styleFrom(
                    foregroundColor: context.colors.error,
                    textStyle: context.text.titleMedium,
                  ),
                  onPressed: _delete,
                  child: const Text(S.deleteExtraSession),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

/// Hộp xác nhận xóa buổi tập thêm (NAV-6, 04 §6.13.1: nút xóa chữ đỏ).
Future<bool> _confirmDelete(BuildContext context, LocalDate date) async =>
    await showAppDialog<bool>(
      context,
      builder: (dialogContext) => AlertDialog(
        title: Text(S.deleteExtraConfirm(Fmt.weekdayDate(date))),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text(S.cancel),
          ),
          TextButton(
            key: const ValueKey('extra-delete-confirm'),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(dialogContext).colorScheme.error,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text(S.delete),
          ),
        ],
      ),
    ) ??
    false;
