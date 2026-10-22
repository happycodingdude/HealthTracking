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
import '../../../core/widgets/toast.dart';
import '../../../core/widgets/unsaved_changes.dart';
import '../application/lift_log_draft.dart';
import '../application/lift_log_edits.dart';
import '../application/lift_unit.dart';
import '../application/session_providers.dart';

/// Từ mức phóng chữ này trở lên, hai ô số xếp dọc (04 Bản 2 §6.13).
const _stackedScale = 1.6;

/// Mở S-64 cho bài [exercise] trong buổi ngày [date], từ dòng bài ở S-63 hoặc
/// nút "Ghi mức tạ" / "Sửa" ở S-67 (NAV-12, UR2-03): cùng một bảng. [existing]
/// = bản ghi của buổi (chế độ sửa). Đóng bảng thì về đúng màn vừa mở nó.
Future<void> showLiftLogSheet(
  BuildContext context, {
  required LocalDate date,
  required Exercise exercise,
  LiftLog? existing,
}) {
  final container = ProviderScope.containerOf(context, listen: false);
  final logs = container.read(allLiftLogsProvider).value ?? const <LiftLog>[];
  final args = (
    date: date,
    exercise: exercise,
    existing: existing,
    previous: LiftLogRules.previousSession(logs, exercise.id, date),
    unit: container.read(exerciseUnitsProvider).value?[exercise.id]?.unit,
  );
  // Thông báo nhanh và hộp thoại sau khi bảng đóng dùng Navigator gốc.
  final host = Navigator.of(context, rootNavigator: true).context;
  return showAppSheet<void>(
    context,
    enableDrag: false,
    builder: (_) => LiftLogSheet(args: args, host: host),
  );
}

/// S-64 — Ghi mức tạ (04 Bản 2 S-64, P7): tên bài, buổi trước, hai ô số có
/// − / +, khu cảnh báo, nút Lưu; chế độ sửa có "Xóa mức tạ". Nút Lưu luôn
/// bấm được, lỗi hiện đỏ dưới ô (P4). Lưu sau 00:00 → hộp "Mức tạ của buổi
/// này đã khóa lúc 00:00." (F21-R12).
class LiftLogSheet extends ConsumerStatefulWidget {
  const LiftLogSheet({super.key, required this.args, required this.host});

  final LiftDraftArgs args;
  final BuildContext host;

  @override
  ConsumerState<LiftLogSheet> createState() => _LiftLogSheetState();
}

class _LiftLogSheetState extends ConsumerState<LiftLogSheet> {
  late final LiftDraft _initial;
  late final Map<LiftField, TextEditingController> _controllers;
  final _focus = {for (final f in LiftField.values) f: FocusNode()};

  /// Ô đang nhập (viền màu chủ đạo).
  LiftField? _active;
  bool _busy = false;

  LiftLogDraft get _draft =>
      ref.read(liftLogDraftProvider(widget.args).notifier);

  @override
  void initState() {
    super.initState();
    _initial = ref.read(liftLogDraftProvider(widget.args));
    _controllers = {
      for (final f in LiftField.values)
        f: TextEditingController(text: _initial.text(f)),
    };
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
    await _run(() async {
      final log = await ref
          .read(saveLiftLogProvider)
          .call(
            args.date,
            args.exercise.id,
            start: draft.start,
            end: draft.end,
            unit: draft.unit,
          );
      return S.liftSaved(
        Fmt.kgNumber(log.startKgX10),
        Fmt.kgNumber(log.endKgX10),
        Fmt.liftUnit(draft.unit),
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
      title: const Text(S.liftLockedAtMidnight, textAlign: TextAlign.center),
      actions: [
        FilledButton(
          key: const ValueKey('lift-locked-ok'),
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: const Text(S.understood),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final draft = ref.watch(liftLogDraftProvider(widget.args));
    final args = widget.args;
    final palette = context.palette;
    final previous = draft.previous;
    final stacked = MediaQuery.textScalerOf(context).scale(1) >= _stackedScale;
    final error = draft.error;
    final warning = draft.warning;
    final unit = draft.unit;
    Widget box(LiftField f) => _KgBox(
      key: ValueKey('lift-box-${f.name}'),
      field: f,
      unit: unit,
      controller: _controllers[f]!,
      focusNode: _focus[f]!,
      active: _active == f,
      canStep: draft.canStep(f),
      onStep: (delta) => _step(f, delta),
      onChanged: (text) => _draft.edit(f, text),
    );

    return UnsavedChangesGuard(
      dirty: draft.start != _initial.start || draft.end != _initial.end,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
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
              previous == null
                  ? S.liftFirstTime
                  : S.liftPrevious(
                      Fmt.dayMonth(previous.date),
                      Fmt.kgNumber(previous.startKgX10),
                      Fmt.kgNumber(previous.endKgX10),
                      Fmt.liftUnit(unit),
                    ),
              key: const ValueKey('lift-previous'),
              style: context.text.bodyLarge?.copyWith(
                color: palette.textSecondary,
              ),
            ),
            const SizedBox(height: 20),
            if (stacked) ...[
              box(LiftField.start),
              const SizedBox(height: 12),
              box(LiftField.end),
            ] else
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(child: box(LiftField.start)),
                    const SizedBox(width: 12),
                    Expanded(child: box(LiftField.end)),
                  ],
                ),
              ),
            const SizedBox(height: 8),
            if (error != null)
              Semantics(
                liveRegion: true,
                child: Text(
                  _errorText(error, unit),
                  key: const ValueKey('lift-error'),
                  style: context.text.bodyLarge?.copyWith(
                    color: context.colors.error,
                  ),
                ),
              )
            else
              Text(
                unit == LiftUnit.steps
                    ? S.liftStepGuideFirst('1 ${S.unitSteps}')
                    : S.liftStepHint,
                style: context.text.bodyMedium?.copyWith(
                  color: palette.textSecondary,
                ),
              ),
            if (warning != null) ...[
              const SizedBox(height: 16),
              _WarningBox(warning, unit),
            ],
            const SizedBox(height: 20),
            PrimaryButton(
              key: const ValueKey('lift-save'),
              label: S.save,
              onPressed: _save,
            ),
            if (args.existing != null) ...[
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
    );
  }

  static String _errorText(LiftInputError e, LiftUnit unit) =>
      Fmt.liftError(e, unit);
}

/// Ô số "Bắt đầu" / "Kết thúc": nút −, con số lớn kèm "kg", nút + (04 Bản 2
/// §6.10). Chạm con số để gõ bằng bàn phím số có dấu phẩy; nhận "," và ".",
/// luôn hiện "," (UR-10). Bài với máy: con số kèm "thanh", bàn phím số không
/// có dấu phẩy, chỉ nhận chữ số.
class _KgBox extends StatelessWidget {
  const _KgBox({
    super.key,
    required this.field,
    required this.unit,
    required this.controller,
    required this.focusNode,
    required this.active,
    required this.canStep,
    required this.onStep,
    required this.onChanged,
  });

  final LiftField field;
  final LiftUnit unit;
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool active;
  final bool canStep;
  final ValueChanged<int> onStep;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final label = field == LiftField.start ? S.liftStart : S.liftEnd;
    final steps = unit == LiftUnit.steps;
    final numberStyle = context.text.headlineMedium?.copyWith(
      fontWeight: FontWeight.w700,
    );
    final secondary = context.palette.textSecondary;
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 10, 8, 12),
      decoration: BoxDecoration(
        color: context.palette.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: active ? colors.primary : context.palette.border,
          width: active ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Text(
              label,
              style: context.text.bodyLarge?.copyWith(color: secondary),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              _StepButton(
                key: ValueKey('lift-${field.name}-minus'),
                icon: Icons.remove,
                label: '$label, ${S.liftDecrease}',
                onStep: canStep ? () => onStep(-1) : null,
              ),
              Expanded(
                child: SizedBox(
                  // Cao theo cỡ chữ để con số không bị thu nhỏ ở cỡ chữ lớn.
                  height: MediaQuery.textScalerOf(
                    context,
                  ).scale(40).clamp(52, 110).toDouble(),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Con số hiện bằng chữ tự thu nhỏ cho vừa giữa hai nút
                      // 44 điểm ("72,5 kg", "122,5 kg").
                      ExcludeSemantics(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
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
                                    style: controller.text.isEmpty
                                        ? numberStyle?.copyWith(
                                            color: secondary,
                                            fontWeight: FontWeight.w400,
                                          )
                                        : numberStyle,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    Fmt.liftUnit(unit),
                                    style: context.text.bodyLarge?.copyWith(
                                      color: secondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      // Ô nhập trong suốt phủ lên: chạm con số để gõ bằng bàn
                      // phím số có dấu phẩy.
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
              _StepButton(
                key: ValueKey('lift-${field.name}-plus'),
                icon: Icons.add,
                label: '$label, ${S.liftIncrease}',
                onStep: canStep ? () => onStep(1) : null,
              ),
            ],
          ),
        ],
      ),
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

/// Nút − / + tròn tối thiểu 44 điểm (04 Bản 2 §6.10, §6.13); giữ để chạy
/// nhanh. null = chưa có số (UA2-10): biểu tượng mờ như "‹" ở S-69.
class _StepButton extends StatefulWidget {
  const _StepButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onStep,
  });

  final IconData icon;
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
    final color = context.colors.primary;
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
                  (_) => widget.onStep?.call(),
                ),
          onLongPressEnd: (_) => _stop(),
          onLongPressCancel: _stop,
          child: IconButton.outlined(
            constraints: const BoxConstraints.tightFor(width: 44, height: 44),
            padding: EdgeInsets.zero,
            style: IconButton.styleFrom(
              side: BorderSide(color: context.palette.border),
              foregroundColor: color,
              disabledForegroundColor: color.withAlpha(70),
            ),
            onPressed: onStep,
            icon: Icon(widget.icon),
          ),
        ),
      ),
    );
  }
}

/// Khu cảnh báo (04 Bản 2 §6.10, UA2-11): nền vàng nhạt, viền vàng, chữ tối,
/// không có nút, câu nguyên văn F21-R8. Không dùng đỏ (UA-15).
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
