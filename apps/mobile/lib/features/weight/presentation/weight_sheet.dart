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
import '../../../core/widgets/labeled_field.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/toast.dart';
import '../../../core/widgets/unsaved_changes.dart';
import '../../../data/sync/sync_providers.dart';
import '../../me/presentation/calorie_proposal_sheet.dart';
import '../application/weight_edits.dart';

/// Mở S-41 cho tuần [week]. [edit] = chế độ sửa (chạm dòng đã ghi ở S-40):
/// có "Xóa số cân này", không hỏi thay thế.
Future<void> showWeightSheet(
  BuildContext context,
  LocalDate week, {
  bool edit = false,
}) => showAppSheet<void>(
  context,
  enableDrag: false,
  builder: (_) => WeightSheet(week: week, edit: edit, host: context),
);

/// S-41 — Ghi / sửa số cân (04 S-41): F07-V1 lỗi dưới ô; tuần đã có số thì
/// hỏi thay thế (F07-R1); chênh hơn 5 kg thì hỏi xác nhận (F07-V2); xóa qua
/// hộp xác nhận, không xóa số cân duy nhất (F07-R3).
class WeightSheet extends ConsumerStatefulWidget {
  const WeightSheet({
    super.key,
    required this.week,
    required this.edit,
    required this.host,
  });

  final LocalDate week;
  final bool edit;

  /// Màn hình mở bảng; hiện thông báo nhanh sau khi bảng đóng.
  final BuildContext host;

  @override
  ConsumerState<WeightSheet> createState() => _WeightSheetState();
}

class _WeightSheetState extends ConsumerState<WeightSheet> {
  final _input = TextEditingController();
  String _initial = '';
  bool _loaded = false;
  String? _error;
  WeightLog _log = WeightLog(const []);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final log = WeightLog(await ref.read(weightRepositoryProvider).all());
    if (!mounted) return;
    final existing = log.at(widget.week);
    setState(() {
      _log = log;
      _loaded = true;
      if (widget.edit && existing != null) {
        _initial = Fmt.kgNumber(existing.kgX10);
        _input.text = _initial;
      }
    });
  }

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  String get _range => Fmt.weekRange(widget.week, widget.week.addDays(6));

  Future<void> _save() async {
    final kgX10 = WeightRules.parseKgX10(_input.text);
    if (!WeightRules.isValidKgX10(kgX10)) {
      setState(() => _error = S.invalidWeight);
      return;
    }
    final existing = _log.at(widget.week);
    if (!widget.edit && existing != null) {
      final ok = await _confirm(
        title: S.replaceWeight(Fmt.kg(existing.kgX10)),
        cancel: S.cancel,
        action: S.replace,
        key: 'confirm-replace',
      );
      if (!ok) return;
    }
    final big = _log.bigChange(widget.week, kgX10!);
    if (big != null) {
      final ok = await _confirm(
        title: S.bigWeightChange(Fmt.kg(big)),
        cancel: S.editAgain,
        action: S.save,
        key: 'confirm-big-change',
      );
      if (!ok) return;
    }
    final WeightChange change;
    try {
      change = await ref.read(weightEditsProvider).log(widget.week, kgX10);
    } on WeightException catch (e, st) {
      await ref.read(errorReporterProvider).report(e, st, reason: 'weight');
      return;
    }
    if (!mounted) return;
    Navigator.of(context).pop();
    if (widget.host.mounted) {
      showToast(widget.host, S.weightSaved(Fmt.kg(kgX10)));
      // F07-AC6: số cân mới nhất đổi → mức calo cập nhật hoặc đề xuất.
      showCalorieOutcome(widget.host, change.calorie);
    }
  }

  Future<void> _delete() async {
    if (!_log.canDelete(widget.week)) {
      showToast(context, S.keepOneWeight);
      return;
    }
    final ok = await _confirm(
      title: S.deleteWeightConfirm(Fmt.dayMonth(widget.week)),
      cancel: S.cancel,
      action: S.delete,
      key: 'confirm-delete-weight',
      destructive: true,
    );
    if (!ok) return;
    final WeightChange change;
    try {
      change = await ref.read(weightEditsProvider).delete(widget.week);
    } on WeightException catch (e, st) {
      await ref.read(errorReporterProvider).report(e, st, reason: 'weight');
      return;
    }
    if (!mounted) return;
    Navigator.of(context).pop();
    // F07-E2: xóa số cân mới nhất → tính lại mức calo.
    if (widget.host.mounted) showCalorieOutcome(widget.host, change.calorie);
  }

  Future<bool> _confirm({
    required String title,
    required String cancel,
    required String action,
    required String key,
    bool destructive = false,
  }) async =>
      await showAppDialog<bool>(
        context,
        builder: (dialogContext) => AlertDialog(
          title: Text(title),
          actions: [
            OutlinedButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(cancel),
            ),
            if (destructive)
              TextButton(
                key: ValueKey(key),
                style: TextButton.styleFrom(
                  foregroundColor: Theme.of(dialogContext).colorScheme.error,
                ),
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: Text(action),
              )
            else
              FilledButton(
                key: ValueKey(key),
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: Text(action),
              ),
          ],
        ),
      ) ??
      false;

  @override
  Widget build(BuildContext context) {
    final existing = _log.at(widget.week);
    return UnsavedChangesGuard(
      dirty: _loaded && _input.text != _initial,
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          16,
          24,
          16,
          16 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Heading(
              S.weightSheetTitle(_range),
              style: context.text.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            if (!widget.edit && existing != null) ...[
              const SizedBox(height: 4),
              Text(
                S.weekAlreadyLogged(Fmt.kg(existing.kgX10)),
                style: context.text.bodyLarge?.copyWith(
                  color: context.palette.textSecondary,
                ),
              ),
            ],
            const SizedBox(height: 20),
            LabeledField(
              key: const ValueKey('weight-input'),
              label: S.fieldWeight,
              controller: _input,
              error: _error,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp('[0-9.,]')),
              ],
              suffix: Padding(
                padding: const EdgeInsets.only(right: 16),
                child: Text(S.unitKg, style: context.text.bodyLarge),
              ),
              onChanged: (_) => setState(() => _error = null),
            ),
            const SizedBox(height: 24),
            PrimaryButton(
              label: S.save,
              onPressed: () => _loaded ? _save() : null,
            ),
            if (widget.edit) ...[
              const SizedBox(height: 8),
              TextButton(
                key: const ValueKey('weight-delete'),
                style: TextButton.styleFrom(
                  foregroundColor: context.colors.error,
                  textStyle: context.text.titleMedium,
                ),
                onPressed: _delete,
                child: const Text(S.deleteWeight),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
