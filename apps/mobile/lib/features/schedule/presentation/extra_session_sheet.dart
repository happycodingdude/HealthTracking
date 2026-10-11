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
import '../../today/application/mark_session.dart';
import '../application/schedule_providers.dart';
import 'muscle_picker.dart';
import 'session_marking.dart';

/// Mở S-24 cho ngày [date]. Chỉ gọi khi [ExtraSessionRules.canAdd].
Future<void> showExtraSessionSheet(BuildContext context, LocalDate date) =>
    showAppSheet<void>(
      context,
      // Có lựa chọn chưa lưu: tự bắt cử chỉ vuốt để hỏi trước (Q-2).
      enableDrag: false,
      builder: (_) => ExtraSessionSheet(date: date, host: context),
    );

/// S-24 — Buổi tập thêm (04 Bản 2 S-24): chỉ thêm. Bộ chọn nhóm cơ (F05-V21),
/// "Lưu" → S-65 "Lưu buổi tập thêm?" → lưu và khóa ngay (F05-R33, F05-R34).
/// Không có chế độ sửa, không có nút xóa. Không tính vào kế hoạch tuần.
class ExtraSessionSheet extends ConsumerStatefulWidget {
  const ExtraSessionSheet({super.key, required this.date, required this.host});

  final LocalDate date;

  /// Màn hình mở bảng; thông báo nhanh hiện ở đây sau khi bảng đóng.
  final BuildContext host;

  @override
  ConsumerState<ExtraSessionSheet> createState() => _ExtraSessionSheetState();
}

class _ExtraSessionSheetState extends ConsumerState<ExtraSessionSheet> {
  List<MuscleGroup> _muscles = const [];
  bool _showError = false;

  Future<void> _save() async {
    if (_muscles.isEmpty) {
      setState(() => _showError = true);
      return;
    }
    final muscles = _muscles;
    final today = LocalDate.fromDateTime(ref.read(nowProvider));
    final confirmed = await confirmLock(
      context,
      title: S.extraConfirmTitle,
      today: widget.date == today,
    );
    if (!confirmed || !mounted) return;
    final add = ref.read(addExtraSessionProvider);
    final reporter = ref.read(errorReporterProvider);
    Navigator.of(context).pop();
    try {
      await add(widget.date, muscles, confirmed: confirmed);
    } on ExtraException catch (e, st) {
      // Bảng chỉ mở khi thêm được; lỗi ở đây là vừa qua hạn khi đang mở.
      await reporter.report(e, st, reason: 'extra_session');
      return;
    }
    // Nút "Ghi mức tạ" của thông báo này làm ở VS-27 (FA2-11).
    if (widget.host.mounted) {
      showToast(widget.host, S.extraLogged(Fmt.muscles(muscles)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final day = ref.watch(dayProvider(widget.date)).value;
    if (day == null || day.isWorkout) return const SizedBox(height: 120);
    final palette = context.palette;

    return UnsavedChangesGuard(
      dirty: _muscles.isNotEmpty,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Heading(
              S.extraSheetTitle(
                Fmt.weekday(widget.date),
                Fmt.dayMonth(widget.date),
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
            PrimaryButton(
              key: const ValueKey('extra-save'),
              label: S.save,
              onPressed: _save,
            ),
          ],
        ),
      ),
    );
  }
}
