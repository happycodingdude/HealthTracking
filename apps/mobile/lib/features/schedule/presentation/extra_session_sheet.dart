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

/// Mở S-24 cho ngày [date]: thêm khi [ExtraSessionRules.canAdd], sửa / xóa
/// khi [ExtraSessionRules.canEdit] (chỉ hôm nay, F05-R64).
Future<void> showExtraSessionSheet(BuildContext context, LocalDate date) =>
    showIronlySheet<void>(
      context,
      // Có lựa chọn chưa lưu: tự bắt cử chỉ vuốt để hỏi trước (Q-2).
      enableDrag: false,
      builder: (_) => ExtraSessionSheet(date: date, host: context),
    );

/// S-24 — Buổi tập thêm (04 Bản 5 S-24): tiêu đề ngày; bộ viên nhóm cơ; nút
/// cam "Lưu" lưu ngay (Bản 5 bỏ hộp "Sau khi lưu, buổi này không sửa được
/// nữa", F05-R64). Khi sửa (ngày đã có buổi tập thêm): viên nhóm cơ điền sẵn,
/// "Lưu" đổi nhóm cơ, chữ đỏ "Xóa buổi thêm" — dùng được đến hết ngày. Lỗi
/// chưa chọn nhóm cơ: câu đỏ giữ nguyên.
class ExtraSessionSheet extends ConsumerStatefulWidget {
  const ExtraSessionSheet({super.key, required this.date, required this.host});

  final LocalDate date;

  /// Màn hình mở bảng; thông báo nhanh hiện ở đây sau khi bảng đóng.
  final BuildContext host;

  @override
  ConsumerState<ExtraSessionSheet> createState() => _ExtraSessionSheetState();
}

class _ExtraSessionSheetState extends ConsumerState<ExtraSessionSheet> {
  List<MuscleGroup>? _muscles;
  bool _showError = false;

  Future<void> _delete() async {
    final edit = ref.read(editExtraSessionProvider);
    final reporter = ref.read(errorReporterProvider);
    Navigator.of(context).pop();
    try {
      await edit(widget.date, null);
    } on ExtraException catch (e, st) {
      await reporter.report(e, st, reason: 'extra_session_delete');
    }
  }

  Future<void> _save(PlanDay day) async {
    final muscles = _muscles ?? day.extraMuscles ?? const [];
    if (muscles.isEmpty) {
      setState(() => _showError = true);
      return;
    }
    final editing = SessionLock.extra(day);
    final today = LocalDate.fromDateTime(ref.read(nowProvider));
    final add = ref.read(addExtraSessionProvider);
    final edit = ref.read(editExtraSessionProvider);
    final reporter = ref.read(errorReporterProvider);
    Navigator.of(context).pop();
    try {
      if (editing) {
        await edit(widget.date, muscles);
        return;
      }
      await add(widget.date, muscles);
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
    final now = ref.watch(nowProvider);
    if (day == null || day.isWorkout) return const SizedBox(height: 120);
    final editing = SessionLock.extra(day);
    final saved = day.extraMuscles ?? const <MuscleGroup>[];
    final muscles = _muscles ?? saved;
    final dirty = editing
        ? _muscles != null && !_same(_muscles!, saved)
        : muscles.isNotEmpty;
    return UnsavedChangesGuard(
      dirty: dirty,
      child: IronlySheet(
        key: const ValueKey('extra-sheet'),
        title: Fmt.weekdayDate(widget.date),
        footer: IronlyButton.primary(
          key: const ValueKey('extra-save'),
          label: S.save,
          enabled: !editing || dirty,
          onPressed: () => _save(day),
        ),
        children: [
          MusclePicker(
            selected: muscles,
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
          if (editing && ExtraSessionRules.canEdit(day, now))
            Padding(
              padding: const EdgeInsets.only(top: TokenSpace.s4),
              child: IronlyButton.danger(
                key: const ValueKey('extra-delete'),
                label: S.deleteExtraSession,
                onPressed: _delete,
              ),
            ),
        ],
      ),
    );
  }

  static bool _same(List<MuscleGroup> a, List<MuscleGroup> b) {
    final x = MuscleGroup.ordered(a), y = MuscleGroup.ordered(b);
    return x.length == y.length &&
        [for (var i = 0; i < x.length; i++) x[i] == y[i]].every((v) => v);
  }
}
