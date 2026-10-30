import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../app/strings_vi.dart';
import '../../../app/time_ticker.dart';
import '../../../core/formatters.dart';
import '../../../core/widgets/unsaved_changes.dart';
import '../../../ui/components/components.dart';
import '../../../ui/theme.dart';
import '../../today/application/mark_session.dart';
import '../../workout/presentation/session_screen.dart';
import '../application/schedule_providers.dart';
import 'muscle_picker.dart';
import 'session_marking.dart';

/// Mở S-24 cho ngày [date]. Chỉ gọi khi [ExtraSessionRules.canAdd].
Future<void> showExtraSessionSheet(BuildContext context, LocalDate date) =>
    showIronlySheet<void>(
      context,
      // Có lựa chọn chưa lưu: tự bắt cử chỉ vuốt để hỏi trước (Q-2).
      enableDrag: false,
      builder: (_) => ExtraSessionSheet(date: date, host: context),
    );

/// S-24 — Buổi tập thêm (04 Bản 4 S-24): tiêu đề ngày; bộ viên nhóm cơ; nút
/// cam "Lưu" → S-65 "Lưu buổi tập thêm?" → lưu và khóa ngay (F05-R33, R34).
/// Không có chế độ sửa, không xóa. Lỗi chưa chọn nhóm cơ: câu đỏ giữ nguyên.
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
      await reporter.report(e, st, reason: 'extra_session');
      return;
    }
    // Lưu cho hôm nay: cửa sổ ghi tạ mở từ lúc lưu (FA2-11); thông báo nhanh
    // có nút "Ghi mức tạ" → Hôm nay (danh sách bài của buổi vừa thêm).
    final host = widget.host;
    if (host.mounted) {
      showToast(
        host,
        S.extraLogged(Fmt.muscles(muscles)),
        action: widget.date == today ? S.logLift : null,
        onAction: () {
          if (host.mounted) openSession(host, widget.date);
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final day = ref.watch(dayProvider(widget.date)).value;
    if (day == null || day.isWorkout) return const SizedBox(height: 120);
    return UnsavedChangesGuard(
      dirty: _muscles.isNotEmpty,
      child: IronlySheet(
        key: const ValueKey('extra-sheet'),
        title: Fmt.weekdayDate(widget.date),
        footer: IronlyButton.primary(
          key: const ValueKey('extra-save'),
          label: S.save,
          onPressed: _save,
        ),
        children: [
          MusclePicker(
            selected: _muscles,
            onChanged: (m) => setState(() {
              _muscles = m;
              if (m.isNotEmpty) _showError = false;
            }),
          ),
          if (_showError)
            Padding(
              padding: const EdgeInsets.only(top: TokenSpace.s2),
              child: Semantics(
                liveRegion: true,
                child: Text(S.missingActualMuscles, style: IronlyText.error),
              ),
            ),
        ],
      ),
    );
  }
}
