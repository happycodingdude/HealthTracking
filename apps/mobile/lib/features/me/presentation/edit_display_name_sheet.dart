import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/strings_vi.dart';
import '../../../core/widgets/app_sheet.dart';
import '../../../core/widgets/labeled_field.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/unsaved_changes.dart';
import '../application/update_display_name.dart';

/// Sửa tên hiển thị (S-56, UA-21): bảng trượt (NAV-5). Đóng khi tên đã sửa
/// mà chưa lưu → hỏi "Bỏ các thay đổi chưa lưu?" (Q-2).
Future<void> showEditDisplayNameSheet(BuildContext context, String current) =>
    showAppSheet<void>(
      context,
      enableDrag: false,
      builder: (_) => EditDisplayNameSheet(current: current),
    );

class EditDisplayNameSheet extends ConsumerStatefulWidget {
  const EditDisplayNameSheet({super.key, required this.current});

  final String current;

  @override
  ConsumerState<EditDisplayNameSheet> createState() =>
      _EditDisplayNameSheetState();
}

class _EditDisplayNameSheetState extends ConsumerState<EditDisplayNameSheet> {
  late final _controller = TextEditingController(text: widget.current);
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final ok = await ref.read(updateDisplayNameProvider).call(_controller.text);
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pop();
    } else {
      setState(() => _error = S.invalidDisplayName);
    }
  }

  bool get _dirty => _controller.text != widget.current;

  @override
  Widget build(BuildContext context) {
    return UnsavedChangesGuard(
      dirty: _dirty,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            LabeledField(
              label: S.fieldDisplayName,
              controller: _controller,
              error: _error,
              textCapitalization: TextCapitalization.words,
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
