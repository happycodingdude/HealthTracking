import 'dart:async';

import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../app/strings_vi.dart';
import '../../../app/theme.dart';
import '../../../core/formatters.dart';
import '../../../core/widgets/app_sheet.dart';
import '../../../core/widgets/heading.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/section_bar.dart';
import '../../../core/widgets/toast.dart';
import '../../../core/widgets/unsaved_changes.dart';
import '../application/lift_log_draft.dart';
import '../application/lift_log_edits.dart';
import '../application/lift_unit.dart';
import '../application/session_providers.dart';

/// Mở S-64 cho bài [exercise] trong buổi ngày [date], từ dòng bài ở S-63 hoặc
/// khu cuối trang S-67 (NAV-12, NAV-17): cùng một bảng. Bài bụng mở dạng chỉ
/// có ô ghi chú (S-64-4). Đóng bảng thì về đúng màn vừa mở nó.
Future<void> showLiftLogSheet(
  BuildContext context, {
  required LocalDate date,
  required Exercise exercise,
}) {
  final container = ProviderScope.containerOf(context, listen: false);
  final logs = container.read(allLiftLogsProvider).value ?? const <LiftLog>[];
  final notes =
      container.read(allExerciseNotesProvider).value ?? const <ExerciseNote>[];
  LiftLog? existing;
  ExerciseNote? note;
  for (final l in logs) {
    if (l.date == date && l.exerciseId == exercise.id) existing = l;
  }
  for (final n in notes) {
    if (n.date == date && n.exerciseId == exercise.id) note = n;
  }
  final args = (
    date: date,
    exercise: exercise,
    existing: existing,
    previous: LiftLogRules.previousSession(logs, exercise.id, date),
    unit: container.read(exerciseUnitsProvider).value?[exercise.id]?.unit,
    note: note,
    previousNote: ExerciseNoteRules.previous(
      notes: notes,
      logs: logs,
      exercise: exercise,
      date: date,
    ),
  );
  // Thông báo nhanh và hộp thoại sau khi bảng đóng dùng Navigator gốc.
  final host = Navigator.of(context, rootNavigator: true).context;
  return showAppSheet<void>(
    context,
    enableDrag: false,
    builder: (_) => LiftLogSheet(args: args, host: host),
  );
}

/// S-64 — Ghi mức tạ (04 Bản 3 §6.6): tên bài, buổi trước; lần ghi đầu thanh
/// chọn kg | nấc máy; hai ô số xếp dọc, mỗi ô −bước · số · +bước; cảnh báo;
/// ghi chú buổi trước; ô ghi chú; Lưu (một lần cho cả mức tạ và ghi chú,
/// F21-R49); chế độ sửa có "Xóa mức tạ". Nút Lưu luôn bấm được, lỗi đỏ dưới
/// chỗ sai. Lưu sau 00:00 → hộp "Mức tạ và ghi chú của buổi này đã khóa lúc
/// 00:00." (F26-E4). Đóng khi có thay đổi chưa lưu → hỏi (UA3-03).
class LiftLogSheet extends ConsumerStatefulWidget {
  const LiftLogSheet({super.key, required this.args, required this.host});

  final LiftDraftArgs args;
  final BuildContext host;

  @override
  ConsumerState<LiftLogSheet> createState() => _LiftLogSheetState();
}

class _LiftLogSheetState extends ConsumerState<LiftLogSheet> {
  late final Map<LiftField, TextEditingController> _controllers;
  late final TextEditingController _note;
  final _focus = {for (final f in LiftField.values) f: FocusNode()};

  /// Ô đang nhập (viền màu chủ đạo).
  LiftField? _active;
  bool _busy = false;

  LiftLogDraft get _draft =>
      ref.read(liftLogDraftProvider(widget.args).notifier);

  @override
  void initState() {
    super.initState();
    final initial = ref.read(liftLogDraftProvider(widget.args));
    _controllers = {
      for (final f in LiftField.values)
        f: TextEditingController(text: initial.text(f)),
    };
    _note = TextEditingController(text: initial.note);
    for (final f in LiftField.values) {
      _focus[f]!.addListener(() {
        if (_focus[f]!.hasFocus) setState(() => _active = f);
      });
    }
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    _note.dispose();
    for (final n in _focus.values) {
      n.dispose();
    }
    super.dispose();
  }

  void _step(LiftField f, int delta) {
    _draft.step(f, delta);
    final text = ref.read(liftLogDraftProvider(widget.args)).text(f);
    _controllers[f]!.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
    setState(() => _active = f);
  }

  Future<void> _save() async {
    if (_busy || !_draft.check()) return;
    final draft = ref.read(liftLogDraftProvider(widget.args));
    final args = widget.args;
    final id = args.exercise.id;
    // Hai ô trống, ghi chú không đổi: đóng, không lưu gì (04 Bản 3 S-64).
    if ((draft.noteOnly || draft.bothEmpty) && !draft.noteChanged) {
      Navigator.of(context).pop();
      return;
    }
    await _run(() async {
      if (draft.noteOnly) {
        await ref
            .read(saveExerciseNoteProvider)
            .call(args.date, id, draft.note);
        return S.noteSaved;
      }
      final saved = await ref
          .read(saveLiftEntryProvider)
          .call(
            args.date,
            id,
            start: draft.start,
            end: draft.end,
            unit: draft.unit,
            note: draft.noteChanged ? draft.note : null,
          );
      final log = saved.log;
      if (log == null) return S.noteSaved;
      return S.liftSaved(
        Fmt.kgNumber(log.startKgX10),
        Fmt.kgNumber(log.endKgX10),
        Fmt.liftUnit(draft.unit ?? LiftUnit.kg),
      );
    });
  }

  Future<void> _delete() async {
    if (_busy) return;
    final confirmed =
        await showAppDialog<bool>(
          context,
          builder: (dialogContext) => AlertDialog(
            key: const ValueKey('lift-delete-confirm'),
            title: const Text(S.deleteLiftConfirm),
            actions: [
              OutlinedButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text(S.cancel),
              ),
              TextButton(
                key: const ValueKey('lift-delete-confirm-ok'),
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
    if (!confirmed || !mounted) return;
    final args = widget.args;
    await _run(() async {
      // Xóa mức tạ không xóa ghi chú (F26-R5).
      await ref.read(deleteLiftLogProvider).call(args.date, args.exercise.id);
      return S.liftDeleted;
    });
  }

  /// Ghi; xong thì đóng bảng và báo [action]'s câu. Ngoài cửa sổ (đã qua
  /// 00:00, FA2-17): hộp "đã khóa" → "Đã hiểu" → đóng bảng; S-63 tự chuyển
  /// chỉ đọc vì cửa sổ tính lại theo giờ.
  Future<void> _run(Future<String> Function() action) async {
    setState(() => _busy = true);
    final host = widget.host;
    final reporter = ref.read(errorReporterProvider);
    String? toast;
    try {
      toast = await action();
    } on LiftException catch (e, st) {
      if (e.error == LiftError.windowClosed) {
        if (mounted) await _showLocked();
      } else {
        // Bảng chỉ mở khi ghi được; lỗi khác ở đây là dữ liệu vừa đổi.
        await reporter.report(e, st, reason: 'lift_log');
      }
    }
    if (mounted) Navigator.of(context).pop();
    if (toast != null && host.mounted) showToast(host, toast);
  }

  Future<void> _showLocked() => showAppDialog<void>(
    context,
    builder: (dialogContext) => AlertDialog(
      key: const ValueKey('lift-locked'),
      title: const Text(S.liftAndNoteLocked, textAlign: TextAlign.center),
      actions: [
        FilledButton(
          key: const ValueKey('lift-locked-ok'),
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: const Text(S.understood),
        ),
      ],
    ),
  );

  void _editNote(String text) {
    _draft.editNote(text);
    final clipped = ref.read(liftLogDraftProvider(widget.args)).note;
    if (clipped != text) {
      _note.value = TextEditingValue(
        text: clipped,
        selection: TextSelection.collapsed(offset: clipped.length),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final draft = ref.watch(liftLogDraftProvider(widget.args));
    final args = widget.args;
    final palette = context.palette;
    final previous = args.previous;
    final error = draft.error;
    final warning = draft.warning;
    final unit = draft.unit;
    final secondary = context.text.bodyLarge?.copyWith(
      color: palette.textSecondary,
    );
    final unitError = error == LiftInputError.unitMissing;
    final previousNote = args.previousNote;

    Widget field(LiftField f) => _StepperField(
      key: ValueKey('lift-box-${f.name}'),
      field: f,
      unit: unit,
      controller: _controllers[f]!,
      focusNode: _focus[f]!,
      active: _active == f,
      gray: draft.isGray(f),
      onStep: (delta) => _step(f, delta),
      onChanged: (text) => _draft.edit(f, text),
    );

    return UnsavedChangesGuard(
      dirty: draft.isDirty,
      title: S.discardChanges,
      keepLabel: S.keepLogging,
      // Nút Lưu ghim ở đáy bảng: bàn phím mở thì ô đang nhập (tự cuộn tới),
      // ô ghi chú và nút Lưu luôn ở trên bàn phím (04 Bản 3 S-64).
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Heading(
                    args.exercise.nameVi,
                    style: context.text.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    draft.noteOnly
                        ? S.liftNoWeight
                        : previous == null
                        ? S.liftFirstTime
                        : S.liftPrevious(
                            Fmt.dayMonth(previous.date),
                            Fmt.kgNumber(previous.startKgX10),
                            Fmt.kgNumber(previous.endKgX10),
                            Fmt.liftUnit(unit ?? LiftUnit.kg),
                          ),
                    key: const ValueKey('lift-previous'),
                    style: secondary,
                  ),
                  if (!draft.noteOnly) ...[
                    if (draft.choosingUnit) ...[
                      const SizedBox(height: 16),
                      Text(S.liftUnitPrompt, style: secondary),
                      const SizedBox(height: 8),
                      SectionBar<LiftUnit>(
                        key: const ValueKey('lift-unit-bar'),
                        items: LiftUnit.values,
                        selected: unit,
                        label: Fmt.liftUnitFull,
                        keyOf: (u) => ValueKey('lift-unit-${u.wire}'),
                        onSelected: _draft.chooseUnit,
                      ),
                      if (unitError) ...[
                        const SizedBox(height: 6),
                        _ErrorText(
                          Fmt.liftError(LiftInputError.unitMissing, null),
                        ),
                      ],
                    ],
                    const SizedBox(height: 16),
                    field(LiftField.start),
                    const SizedBox(height: 12),
                    field(LiftField.end),
                    const SizedBox(height: 8),
                    if (error != null && !unitError)
                      _ErrorText(Fmt.liftError(error, unit))
                    else if (unit != null)
                      Text(
                        draft.prefilled
                            ? S.liftStepGuide(_stepText(unit))
                            : S.liftStepGuideFirst(_stepText(unit)),
                        key: const ValueKey('lift-guide'),
                        textAlign: TextAlign.center,
                        style: context.text.bodyMedium?.copyWith(
                          color: palette.textSecondary,
                        ),
                      ),
                    if ((warning, unit) case (final w?, final u?)) ...[
                      const SizedBox(height: 16),
                      _WarningBox(w, u),
                    ],
                  ],
                  if (previousNote != null) ...[
                    const SizedBox(height: 16),
                    Row(
                      key: const ValueKey('note-previous'),
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(top: 3, right: 6),
                          child: Icon(
                            Icons.sticky_note_2_outlined,
                            size: 16,
                            color: palette.textSecondary,
                          ),
                        ),
                        Expanded(
                          child: Text(
                            S.notePrevious(
                              Fmt.dayMonth(previousNote.date),
                              previousNote.text,
                            ),
                            style: secondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 12),
                  _NoteField(controller: _note, onChanged: _editNote),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                PrimaryButton(
                  key: const ValueKey('lift-save'),
                  label: S.save,
                  onPressed: _save,
                ),
                if (args.existing != null && !draft.noteOnly) ...[
                  const SizedBox(height: 8),
                  TextButton(
                    key: const ValueKey('lift-delete'),
                    style: TextButton.styleFrom(
                      foregroundColor: context.colors.error,
                      textStyle: context.text.titleMedium,
                      minimumSize: const Size(44, 44),
                    ),
                    onPressed: _delete,
                    child: const Text(S.deleteLift),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// "2,5 kg" / "1 nấc" (UA3-06).
  static String _stepText(LiftUnit unit) =>
      LiftFormat.value(LiftStep.of(unit), unit);
}

class _ErrorText extends StatelessWidget {
  const _ErrorText(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    child: Text(
      text,
      key: const ValueKey('lift-error'),
      style: context.text.bodyLarge?.copyWith(color: context.colors.error),
    ),
  );
}

/// Ô số có ±bước (04 Bản 3 §6.10): nhãn ô ở trên; một hàng trọn bề ngang
/// gồm nút −bước 56 điểm nền xanh nhạt · khung số 60 điểm cao (con số lớn
/// kèm đơn vị nhỏ) · nút +bước. Số điền sẵn màu xám, đã sửa màu thường
/// (UA3-06). Chạm vào số để gõ: kg bàn phím số có dấu phẩy (nhận "," và
/// ".", hiện ","); nấc máy chỉ chữ số. Chưa chọn đơn vị: nút không tác dụng.
class _StepperField extends StatelessWidget {
  const _StepperField({
    super.key,
    required this.field,
    required this.unit,
    required this.controller,
    required this.focusNode,
    required this.active,
    required this.gray,
    required this.onStep,
    required this.onChanged,
  });

  final LiftField field;
  final LiftUnit? unit;
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool active;
  final bool gray;
  final ValueChanged<int> onStep;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final palette = context.palette;
    final label = field == LiftField.start ? S.liftStart : S.liftEnd;
    final u = unit;
    final steps = u == LiftUnit.steps;
    final step = u == null ? null : LiftKg.format(LiftStep.of(u));
    final stepText = u == null ? null : LiftFormat.value(LiftStep.of(u), u);
    final numberStyle = context.text.headlineLarge?.copyWith(
      fontSize: 30,
      fontWeight: FontWeight.w700,
      color: gray ? palette.textSecondary : colors.onSurface,
    );
    // Cao theo cỡ chữ để con số không bị thu nhỏ ở cỡ chữ lớn.
    final height = MediaQuery.textScalerOf(
      context,
    ).scale(40).clamp(60, 120).toDouble();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: context.text.bodyLarge?.copyWith(
            color: palette.textSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            _StepButton(
              key: ValueKey('lift-${field.name}-minus'),
              text: step == null ? '−' : '−$step',
              height: height,
              label: stepText == null
                  ? label
                  : '$label, ${S.liftDecreaseBy(stepText)}',
              onStep: u == null ? null : () => onStep(-1),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Container(
                height: height,
                decoration: BoxDecoration(
                  color: palette.card,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: active ? colors.primary : palette.border,
                    width: active ? 2 : 1,
                  ),
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    ExcludeSemantics(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: ListenableBuilder(
                            listenable: controller,
                            builder: (context, _) => Row(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.baseline,
                              textBaseline: TextBaseline.alphabetic,
                              children: [
                                Text(
                                  controller.text.isEmpty
                                      ? '—'
                                      : controller.text,
                                  key: ValueKey('lift-${field.name}-value'),
                                  style: controller.text.isEmpty
                                      ? numberStyle?.copyWith(
                                          color: palette.textSecondary,
                                          fontWeight: FontWeight.w400,
                                        )
                                      : numberStyle,
                                ),
                                if (u != null) ...[
                                  const SizedBox(width: 4),
                                  Text(
                                    Fmt.liftUnit(u),
                                    style: context.text.bodyMedium?.copyWith(
                                      fontSize: 14,
                                      color: palette.textSecondary,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    // Ô nhập trong suốt phủ lên: chạm con số để gõ.
                    Positioned.fill(
                      child: Semantics(
                        label: label,
                        child: TextField(
                          key: ValueKey('lift-${field.name}-input'),
                          controller: controller,
                          focusNode: focusNode,
                          onChanged: onChanged,
                          textAlign: TextAlign.center,
                          showCursor: false,
                          enableInteractiveSelection: false,
                          style: numberStyle?.copyWith(
                            color: Colors.transparent,
                          ),
                          keyboardType: TextInputType.numberWithOptions(
                            decimal: !steps,
                          ),
                          inputFormatters: [
                            if (steps)
                              FilteringTextInputFormatter.digitsOnly
                            else ...[
                              FilteringTextInputFormatter.allow(
                                RegExp('[0-9.,]'),
                              ),
                              _CommaFormatter(),
                            ],
                          ],
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            filled: false,
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 10),
            _StepButton(
              key: ValueKey('lift-${field.name}-plus'),
              text: step == null ? '+' : '+$step',
              height: height,
              label: stepText == null
                  ? label
                  : '$label, ${S.liftIncreaseBy(stepText)}',
              onStep: u == null ? null : () => onStep(1),
            ),
          ],
        ),
      ],
    );
  }
}

/// "." → "," ngay khi gõ (F21-E9: hiểu như nhau, hiển thị bằng dấu phẩy).
class _CommaFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) => newValue.copyWith(text: newValue.text.replaceAll('.', ','));
}

/// Nút −bước / +bước: ô vuông bo góc 56 điểm, nền xanh nhạt, chữ "−2,5" /
/// "+1" (04 Bản 3 §6.10); giữ để chạy nhanh, mỗi bước rung nhẹ. null = chưa
/// chọn đơn vị: mờ, không tác dụng.
class _StepButton extends StatefulWidget {
  const _StepButton({
    super.key,
    required this.text,
    required this.height,
    required this.label,
    required this.onStep,
  });

  final String text;
  final double height;
  final String label;
  final VoidCallback? onStep;

  @override
  State<_StepButton> createState() => _StepButtonState();
}

class _StepButtonState extends State<_StepButton> {
  Timer? _repeat;

  void _stop() {
    _repeat?.cancel();
    _repeat = null;
  }

  void _fire() {
    unawaited(HapticFeedback.selectionClick());
    widget.onStep?.call();
  }

  @override
  void didUpdateWidget(_StepButton old) {
    super.didUpdateWidget(old);
    if (widget.onStep == null) _stop();
  }

  @override
  void dispose() {
    _stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final onStep = widget.onStep;
    final colors = context.colors;
    return Semantics(
      button: true,
      enabled: onStep != null,
      label: widget.label,
      child: ExcludeSemantics(
        child: GestureDetector(
          onLongPressStart: onStep == null
              ? null
              : (_) => _repeat = Timer.periodic(
                  const Duration(milliseconds: 120),
                  (_) => _fire(),
                ),
          onLongPressEnd: (_) => _stop(),
          onLongPressCancel: _stop,
          child: SizedBox(
            width: 56,
            height: widget.height,
            child: TextButton(
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                backgroundColor: colors.primaryContainer,
                foregroundColor: colors.primary,
                disabledBackgroundColor: colors.primaryContainer.withAlpha(90),
                disabledForegroundColor: colors.primary.withAlpha(90),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                textStyle: context.text.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              onPressed: onStep == null ? null : _fire,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(widget.text),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Ô ghi chú (04 Bản 3 §6.10): gợi ý "Ghi chú cho hôm nay", bộ đếm "{n}/200"
/// góc phải; cao dần theo nội dung tới 4 dòng rồi cuộn trong ô. Không gõ
/// thêm khi đủ 200 ký tự; dán dài cắt còn 200 (F26-V1, E1).
class _NoteField extends StatelessWidget {
  const _NoteField({required this.controller, required this.onChanged});

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Stack(
      children: [
        TextField(
          key: const ValueKey('note-input'),
          controller: controller,
          onChanged: onChanged,
          minLines: 1,
          maxLines: 4,
          keyboardType: TextInputType.multiline,
          textCapitalization: TextCapitalization.sentences,
          inputFormatters: [_NoteLengthFormatter()],
          decoration: InputDecoration(
            hintText: S.noteHint,
            hintStyle: context.text.bodyLarge?.copyWith(
              color: palette.textSecondary,
            ),
            contentPadding: const EdgeInsets.fromLTRB(16, 16, 72, 16),
          ),
        ),
        Positioned(
          top: 12,
          right: 14,
          child: ListenableBuilder(
            listenable: controller,
            builder: (context, _) => Text(
              S.noteCounter(ExerciseNoteRules.length(controller.text)),
              key: const ValueKey('note-counter'),
              style: context.text.bodySmall?.copyWith(
                color: palette.textSecondary,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Giữ tối đa 200 ký tự người đọc thấy (F26-V1, E1).
class _NoteLengthFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final clipped = ExerciseNoteRules.clip(newValue.text);
    if (clipped == newValue.text) return newValue;
    return TextEditingValue(
      text: clipped,
      selection: TextSelection.collapsed(offset: clipped.length),
    );
  }
}

/// Khu cảnh báo (04 Bản 3 §6.6): nền vàng nhạt, viền vàng, chữ tối, không có
/// nút, câu nguyên văn F21-R45 theo đơn vị. Không dùng đỏ (UA-15).
class _WarningBox extends StatelessWidget {
  const _WarningBox(this.warning, this.unit);

  final EndWarning warning;
  final LiftUnit unit;

  @override
  Widget build(BuildContext context) {
    final n = Fmt.kgNumber(warning.diffX10);
    final u = Fmt.liftUnit(unit);
    return Semantics(
      liveRegion: true,
      child: Container(
        key: ValueKey('lift-warning-${warning.kind.name}'),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: context.palette.referenceContainer,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: context.palette.reference.withAlpha(90)),
        ),
        child: Text(
          warning.kind == EndWarningKind.lower
              ? S.liftEndLower(n, u)
              : S.liftEndMuchHigher(n, u),
          style: context.text.bodyLarge?.copyWith(
            color: context.colors.onSurface,
          ),
        ),
      ),
    );
  }
}
