import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../app/strings_vi.dart';
import '../../../core/formatters.dart';
import '../../../core/widgets/unsaved_changes.dart';
import '../../../data/sync/sync_providers.dart';
import '../../../ui/components/components.dart';
import '../../../ui/theme.dart';
import '../../me/presentation/calorie_proposal_sheet.dart';
import '../application/weight_edits.dart';

/// Mở S-41 cho tuần [week]. [edit] = chế độ sửa (chạm dòng đã ghi ở S-40):
/// có "Xóa số cân này", không hỏi thay thế.
Future<void> showWeightSheet(
  BuildContext context,
  LocalDate week, {
  bool edit = false,
}) => showIronlySheet<void>(
  context,
  enableDrag: false,
  builder: (_) => WeightSheet(week: week, edit: edit, host: context),
);

/// S-41 — Ghi / sửa số cân (04 Bản 4 S-41): tiêu đề = khoảng tuần; một ô số
/// lớn 30 viền cam, "kg" nhỏ; nút cam "Lưu"; khi sửa "Xóa số cân này" đỏ.
/// Hộp chênh 5 kg ("Sửa lại" / "Lưu"), hộp ghi đè, hộp xóa giữ câu Bản 1.
/// Quy tắc F07 như Bản 1: lỗi đỏ dưới ô; không xóa số cân duy nhất.
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
  final _focus = FocusNode();
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
    _focus.dispose();
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
      await showIronlyDialog<bool>(
        context,
        builder: (dialogContext) => IronlyDialog(
          title: title,
          secondaryLabel: cancel,
          onSecondary: () => Navigator.of(dialogContext).pop(false),
          primaryLabel: action,
          primaryKey: ValueKey(key),
          destructive: destructive,
          onPrimary: () => Navigator.of(dialogContext).pop(true),
        ),
      ) ??
      false;

  @override
  Widget build(BuildContext context) {
    return UnsavedChangesGuard(
      dirty: _loaded && _input.text != _initial,
      child: IronlySheet(
        title: _range,
        footer: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            IronlyButton.primary(
              key: const ValueKey('weight-save'),
              label: S.save,
              onPressed: () => _loaded ? _save() : null,
            ),
            if (widget.edit) ...[
              const SizedBox(height: TokenSpace.s1),
              IronlyButton.danger(
                key: const ValueKey('weight-delete'),
                label: S.deleteWeight,
                onPressed: _delete,
              ),
            ],
          ],
        ),
        children: [
          BigNumberField(
            name: 'weight',
            controller: _input,
            focusNode: _focus,
            unit: S.unitKg,
            active: true,
            style: IronlyText.numberField,
            height: 72,
            semanticsLabel: S.fieldWeight,
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
                  key: const ValueKey('weight-error'),
                  style: IronlyText.error,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
