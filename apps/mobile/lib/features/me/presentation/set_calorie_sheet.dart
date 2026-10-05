import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../app/strings_vi.dart';
import '../../../app/theme.dart';
import '../../../core/formatters.dart';
import '../../../core/widgets/app_sheet.dart';
import '../../../core/widgets/heading.dart';
import '../../../core/widgets/labeled_field.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/unsaved_changes.dart';

/// "Đặt mức khác" (S-04, S-52): ô nhập đuôi "kcal" (F02-V1). Dưới ngưỡng an
/// toàn → hộp cảnh báo F02-R5 trước khi lưu ("Vẫn lưu" · "Sửa lại"). Trả mức
/// Bạn đặt, null khi đóng.
Future<int?> showSetCalorieSheet(
  BuildContext context, {
  required Sex sex,
  int? initial,
}) => showAppSheet<int>(
  context,
  enableDrag: false,
  builder: (_) => SetCalorieSheet(sex: sex, initial: initial),
);

class SetCalorieSheet extends StatefulWidget {
  const SetCalorieSheet({super.key, required this.sex, this.initial});

  final Sex sex;
  final int? initial;

  @override
  State<SetCalorieSheet> createState() => _SetCalorieSheetState();
}

class _SetCalorieSheetState extends State<SetCalorieSheet> {
  late final _controller = TextEditingController(
    text: widget.initial == null ? '' : Fmt.integer(widget.initial!),
  );
  late final _initialText = _controller.text;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final kcal = CalorieRules.parseKcal(_controller.text);
    if (!CalorieRules.isValidManual(kcal)) {
      setState(() => _error = S.invalidManualKcal);
      return;
    }
    final navigator = Navigator.of(context);
    if (CalorieRules.isBelowSafetyFloor(kcal!, widget.sex) &&
        !await _confirmLow()) {
      return;
    }
    navigator.pop(kcal);
  }

  /// F02-R5: "Vẫn lưu" → true, "Sửa lại" → false.
  Future<bool> _confirmLow() async {
    final floor = Fmt.integer(CalorieRules.safetyFloor(widget.sex));
    return await showAppDialog<bool>(
          context,
          builder: (dialogContext) => AlertDialog(
            title: const Text(S.lowCalorieTitle),
            content: Text(S.lowCalorieWarning(floor)),
            actions: [
              OutlinedButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text(S.editAgain),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: const Text(S.saveAnyway),
              ),
            ],
          ),
        ) ??
        false;
  }

  @override
  Widget build(BuildContext context) {
    return UnsavedChangesGuard(
      dirty: _controller.text != _initialText,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Heading(
              S.setCalorieTitle,
              style: context.text.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 16),
            LabeledField(
              label: S.fieldDailyCalorie,
              controller: _controller,
              error: _error,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
              ],
              suffix: Padding(
                padding: const EdgeInsets.only(right: 16),
                child: Align(
                  alignment: Alignment.centerRight,
                  widthFactor: 1,
                  child: Text(
                    S.unitKcal,
                    style: context.text.bodyLarge?.copyWith(
                      color: context.palette.textSecondary,
                    ),
                  ),
                ),
              ),
              textInputAction: TextInputAction.done,
              onChanged: (_) => setState(() => _error = null),
              onSubmitted: (_) => _save(),
            ),
            const SizedBox(height: 24),
            PrimaryButton(label: S.save, onPressed: _save),
          ],
        ),
      ),
    );
  }
}
