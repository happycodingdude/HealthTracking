import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/strings_vi.dart';
import '../../../ui/components/components.dart';
import '../application/update_display_name.dart';

/// Sửa tên hiển thị (S-56, UA-21): bảng trượt (NAV-5). Chạm ngoài / vuốt
/// xuống khi chưa lưu → đóng, bỏ thay đổi, không hỏi (Bạn yêu cầu 06/11/2026).
Future<void> showEditDisplayNameSheet(BuildContext context, String current) =>
    showIronlySheet<void>(
      context,
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

  @override
  Widget build(BuildContext context) {
    return IronlySheet(
      title: S.fieldDisplayName,
      footer: IronlyButton.primary(
        key: const ValueKey('display-name-save'),
        label: S.save,
        onPressed: _save,
      ),
      children: [
        IronlyTextField(
          name: 'display-name',
          hint: S.fieldDisplayName,
          controller: _controller,
          error: _error,
          textCapitalization: TextCapitalization.words,
          textInputAction: TextInputAction.done,
          onChanged: (_) => setState(() => _error = null),
          onSubmitted: (_) => _save(),
        ),
      ],
    );
  }
}
