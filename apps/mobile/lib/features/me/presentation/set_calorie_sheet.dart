import 'package:domain/domain.dart';
import 'package:flutter/material.dart';

import '../../../app/strings_vi.dart';
import '../../../core/formatters.dart';
import '../../../core/widgets/unsaved_changes.dart';
import '../../../ui/components/components.dart';
import '../../../ui/theme.dart';

/// "Tự đặt" (S-04, S-52, 04 Bản 4): bảng trượt một ô số lớn đuôi "kcal"
/// (F02-V1). Dưới ngưỡng an toàn → hộp cảnh báo F02-R5 trước khi lưu ("Vẫn
/// lưu" · "Sửa lại"). Trả mức Bạn đặt, null khi đóng.
Future<int?> showSetCalorieSheet(
  BuildContext context, {
  required Sex sex,
  int? initial,
}) => showIronlySheet<int>(
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
  final _focus = FocusNode();
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
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
    return await showIronlyDialog<bool>(
          context,
          builder: (dialogContext) => IronlyDialog(
            key: const ValueKey('low-calorie-dialog'),
            title: S.lowCalorieTitle,
            body: S.lowCalorieWarning(floor),
            secondaryLabel: S.editAgain,
            onSecondary: () => Navigator.of(dialogContext).pop(false),
            primaryLabel: S.saveAnyway,
            primaryKey: const ValueKey('low-calorie-save'),
            onPrimary: () => Navigator.of(dialogContext).pop(true),
          ),
        ) ??
        false;
  }

  @override
  Widget build(BuildContext context) {
    return UnsavedChangesGuard(
      dirty: _controller.text != _initialText,
      child: IronlySheet(
        title: S.setCalorieTitle,
        footer: IronlyButton.primary(
          key: const ValueKey('calorie-save'),
          label: S.save,
          onPressed: _save,
        ),
        children: [
          BigNumberField(
            name: 'daily-calorie',
            controller: _controller,
            focusNode: _focus,
            unit: S.unitKcal,
            active: true,
            decimal: false,
            style: IronlyText.numberField,
            height: 72,
            semanticsLabel: S.fieldDailyCalorie,
            background: context.tokens.surfaceRaised,
            onChanged: (_) => setState(() => _error = null),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 6, left: 2),
              child: Semantics(
                liveRegion: true,
                child: Text(
                  _error!,
                  key: const ValueKey('field-daily-calorie-error'),
                  style: IronlyText.error,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
