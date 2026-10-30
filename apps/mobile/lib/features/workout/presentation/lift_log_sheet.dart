import 'dart:async';

import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../app/strings_vi.dart';
import '../../../core/formatters.dart';
import '../../../core/widgets/unsaved_changes.dart';
import '../../../ui/components/components.dart';
import '../../../ui/theme.dart';
import '../application/lift_log_draft.dart';
import '../application/lift_log_edits.dart';
import '../application/lift_unit.dart';
import '../application/session_providers.dart';

/// Mở S-64 cho bài [exercise] trong buổi ngày [date], từ hàng số ở Hôm nay /
/// Buổi tập hoặc khu cuối trang S-67. Bài bụng mở dạng chỉ có ô ghi chú.
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
  return showIronlySheet<void>(
    context,
    enableDrag: false,
    builder: (_) => LiftLogSheet(args: args, host: host),
  );
}

/// S-64 — Ghi mức tạ (04 Bản 4 S-64): tên bài 15 / 600; lần ghi đầu thanh
/// chọn kg | nấc máy; hai khối Bắt đầu / Kết thúc, mỗi khối nút −bước · ô số
/// 26 / 600 với đơn vị nhỏ · nút +bước (số điền sẵn mờ, đã sửa trắng, ô đang
/// nhập viền cam); ô ghi chú (dòng trên: ghi chú buổi trước mờ; dưới: ghi
/// chú hôm nay); nút cam Lưu; khi sửa: "Xóa mức tạ" đỏ. Không dòng hướng
/// dẫn, không dòng "Buổi trước … → …". Câu lỗi giữ nguyên, đỏ dưới ô. Quy tắc
/// như Bản 3 (F21, F26): Lưu một lần cho mức tạ và ghi chú; sau 00:00 → hộp
/// "đã khóa"; đóng khi có thay đổi chưa lưu → hỏi.
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

  /// Ô đang nhập (viền cam).
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
    // Hai ô trống, ghi chú không đổi: đóng, không lưu gì.
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
        await showIronlyDialog<bool>(
          context,
          builder: (dialogContext) => IronlyDialog(
            key: const ValueKey('lift-delete-confirm'),
            title: S.deleteLiftConfirm,
            secondaryLabel: S.cancel,
            onSecondary: () => Navigator.of(dialogContext).pop(false),
            primaryLabel: S.delete,
            primaryKey: const ValueKey('lift-delete-confirm-ok'),
            destructive: true,
            onPrimary: () => Navigator.of(dialogContext).pop(true),
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

  /// Ghi; xong thì đóng bảng và báo câu của [action]. Ngoài cửa sổ (đã qua
  /// 00:00): hộp "đã khóa" → "Đã hiểu" → đóng bảng.
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
        await reporter.report(e, st, reason: 'lift_log');
      }
    }
    if (mounted) Navigator.of(context).pop();
    if (toast != null && host.mounted) showToast(host, toast);
  }

  Future<void> _showLocked() => showIronlyDialog<void>(
    context,
    builder: (dialogContext) => IronlyDialog(
      key: const ValueKey('lift-locked'),
      title: S.liftAndNoteLocked,
      primaryLabel: S.understood,
      primaryKey: const ValueKey('lift-locked-ok'),
      onPrimary: () => Navigator.of(dialogContext).pop(),
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
    final error = draft.error;
    final warning = draft.warning;
    final unit = draft.unit;
    final unitError = error == LiftInputError.unitMissing;

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
      child: IronlySheet(
        title: args.exercise.nameVi,
        footer: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            IronlyButton.primary(
              key: const ValueKey('lift-save'),
              label: S.save,
              onPressed: _save,
            ),
            if (args.existing != null && !draft.noteOnly) ...[
              const SizedBox(height: TokenSpace.s1),
              IronlyButton.danger(
                key: const ValueKey('lift-delete'),
                label: S.deleteLift,
                onPressed: _delete,
              ),
            ],
          ],
        ),
        children: [
          if (!draft.noteOnly) ...[
            if (draft.choosingUnit) ...[
              SegmentBar<LiftUnit>(
                key: const ValueKey('lift-unit-bar'),
                items: LiftUnit.values,
                selected: unit,
                style: SegmentStyle.accent,
                background: context.tokens.surfaceRaised,
                label: Fmt.liftUnitFull,
                keyOf: (u) => ValueKey('lift-unit-${u.wire}'),
                onSelected: _draft.chooseUnit,
              ),
              if (unitError) ...[
                const SizedBox(height: 6),
                _ErrorText(Fmt.liftError(LiftInputError.unitMissing, null)),
              ],
              const SizedBox(height: TokenSpace.s4),
            ],
            field(LiftField.start),
            const SizedBox(height: TokenSpace.s3),
            field(LiftField.end),
            if (error != null && !unitError) ...[
              const SizedBox(height: TokenSpace.s2),
              _ErrorText(Fmt.liftError(error, unit)),
            ],
            if ((warning, unit) case (final w?, final u?)) ...[
              const SizedBox(height: TokenSpace.s3),
              _WarningBox(w, u),
            ],
            const SizedBox(height: TokenSpace.s3),
          ],
          _NoteBox(
            controller: _note,
            onChanged: _editNote,
            previous: args.previousNote,
          ),
        ],
      ),
    );
  }
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
      style: IronlyText.error,
    ),
  );
}

/// Một khối số (04 Bản 4 S-64): nhãn 11 chữ phụ; hàng nút vuông "−2,5" (52,
/// thẻ nổi) · ô số 26 / 600 với đơn vị nhỏ · nút "+2,5" (nấc: ±1). Chạm vào
/// số để gõ: kg bàn phím số có dấu phẩy; nấc chỉ chữ số. Chưa chọn đơn vị:
/// nút mờ, không tác dụng.
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
    final label = field == LiftField.start ? S.liftStart : S.liftEnd;
    final u = unit;
    final step = u == null ? null : LiftKg.format(LiftStep.of(u));
    final stepText = u == null ? null : LiftFormat.value(LiftStep.of(u), u);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: IronlyText.caption),
        const SizedBox(height: 6),
        Row(
          children: [
            _StepButton(
              key: ValueKey('lift-${field.name}-minus'),
              text: step == null ? '−' : '−$step',
              label: stepText == null
                  ? label
                  : '$label, ${S.liftDecreaseBy(stepText)}',
              onStep: u == null ? null : () => onStep(-1),
            ),
            const SizedBox(width: TokenSpace.s2),
            Expanded(
              child: BigNumberField(
                name: 'lift-${field.name}',
                controller: controller,
                focusNode: focusNode,
                unit: u == null ? null : Fmt.liftUnit(u),
                active: active,
                gray: gray,
                decimal: u != LiftUnit.steps,
                onChanged: onChanged,
                height: TokenSize.stepButton,
                semanticsLabel: label,
                background: context.tokens.surfaceRaised,
              ),
            ),
            const SizedBox(width: TokenSpace.s2),
            _StepButton(
              key: ValueKey('lift-${field.name}-plus'),
              text: step == null ? '+' : '+$step',
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

/// Nút −bước / +bước: ô vuông 52 thẻ nổi, chữ "−2,5" / "+1"; giữ để chạy
/// nhanh, mỗi bước rung nhẹ. null = chưa chọn đơn vị: mờ, không tác dụng.
class _StepButton extends StatefulWidget {
  const _StepButton({
    super.key,
    required this.text,
    required this.label,
    required this.onStep,
  });

  final String text;
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
    final t = context.tokens;
    final onStep = widget.onStep;
    final radius = BorderRadius.circular(TokenRadius.field);
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
          child: Opacity(
            opacity: onStep == null ? IronlyButton.disabledOpacity : 1,
            child: Material(
              color: t.surfaceRaised,
              borderRadius: radius,
              child: InkWell(
                borderRadius: radius,
                onTap: onStep == null ? null : _fire,
                child: SizedBox(
                  width: TokenSize.stepButton,
                  height: TokenSize.stepButton,
                  child: Center(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Text(
                          widget.text,
                          style: IronlyText.body.copyWith(
                            fontWeight: FontWeight.w600,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Ô ghi chú (04 Bản 4 S-64): thẻ nổi bo 8, icon ghi chú trái; dòng trên là
/// ghi chú buổi trước "20/10: …" mờ 11 (nếu có), dưới là ghi chú hôm nay
/// trắng 12. Không gõ thêm khi đủ 200 ký tự; dán dài cắt còn 200 (F26-V1).
class _NoteBox extends StatelessWidget {
  const _NoteBox({
    required this.controller,
    required this.onChanged,
    required this.previous,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final ExerciseNote? previous;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Container(
      padding: const EdgeInsets.fromLTRB(
        TokenSpace.s3,
        TokenSpace.s2,
        TokenSpace.s3,
        TokenSpace.s2,
      ),
      decoration: BoxDecoration(
        color: t.surfaceRaised,
        borderRadius: BorderRadius.circular(TokenRadius.row),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 10, right: TokenSpace.s2),
            child: Icon(
              Icons.sticky_note_2_outlined,
              size: 16,
              color: t.textSecondary,
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (previous != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      S.notePrevious(
                        Fmt.dayMonth(previous!.date),
                        previous!.text,
                      ),
                      key: const ValueKey('note-previous'),
                      style: IronlyText.caption.copyWith(color: t.textPrefill),
                    ),
                  ),
                TextField(
                  key: const ValueKey('note-input'),
                  controller: controller,
                  onChanged: onChanged,
                  minLines: 1,
                  maxLines: 4,
                  keyboardType: TextInputType.multiline,
                  textCapitalization: TextCapitalization.sentences,
                  inputFormatters: [_NoteLengthFormatter()],
                  style: IronlyText.caption2,
                  cursorColor: t.accent,
                  decoration: InputDecoration(
                    hintText: S.noteHint,
                    hintStyle: IronlyText.caption2.copyWith(
                      color: t.textPrefill,
                    ),
                    filled: false,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 8),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
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

/// Khu cảnh báo (04 Bản 4 §6.9): banner thẻ viền cam, câu nguyên văn F21-R45
/// theo đơn vị, không nút.
class _WarningBox extends StatelessWidget {
  const _WarningBox(this.warning, this.unit);

  final EndWarning warning;
  final LiftUnit unit;

  @override
  Widget build(BuildContext context) {
    final n = Fmt.kgNumber(warning.diffX10);
    final u = Fmt.liftUnit(unit);
    return IronlyBanner(
      key: ValueKey('lift-warning-${warning.kind.name}'),
      text: warning.kind == EndWarningKind.lower
          ? S.liftEndLower(n, u)
          : S.liftEndMuchHigher(n, u),
    );
  }
}
