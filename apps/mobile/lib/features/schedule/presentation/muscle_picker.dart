import 'package:domain/domain.dart';
import 'package:flutter/material.dart';

import '../../../core/formatters.dart';
import '../../../ui/components/components.dart';
import '../../../ui/theme.dart';

/// Bộ chọn nhóm cơ (04 Bản 4 §6.1): 7 viên theo thứ tự bộ chọn, Chân ở cuối
/// (UA3-10), xuống hàng, không cuộn ngang; chọn nhiều; viên chọn nền cam.
class MusclePicker extends StatelessWidget {
  const MusclePicker({
    super.key,
    required this.selected,
    required this.onChanged,
    this.enabled = true,
  });

  final List<MuscleGroup> selected;
  final ValueChanged<List<MuscleGroup>> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: TokenSpace.s2,
      runSpacing: TokenSpace.s2,
      children: [
        for (final m in MuscleGroup.pickerOrder)
          IronlyChip(
            key: ValueKey('muscle-${m.name}'),
            label: Fmt.muscle(m),
            selected: selected.contains(m),
            enabled: enabled,
            onTap: () => onChanged(
              selected.contains(m)
                  ? [
                      for (final s in selected)
                        if (s != m) s,
                    ]
                  : MuscleGroup.ordered([...selected, m]),
            ),
          ),
      ],
    );
  }
}
