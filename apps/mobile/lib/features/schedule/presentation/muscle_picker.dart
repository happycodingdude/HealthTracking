import 'package:domain/domain.dart';
import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../core/formatters.dart';

/// Bộ chọn nhóm cơ (04 §6.13.4): 6 nút viên thuốc theo thứ tự PR-02, chọn
/// nhiều; nút đã chọn được tô màu và có dấu tích.
class MusclePicker extends StatelessWidget {
  const MusclePicker({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  final List<MuscleGroup> selected;
  final ValueChanged<List<MuscleGroup>> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final m in MuscleGroup.values)
          _Pill(
            key: ValueKey('muscle-${m.name}'),
            label: Fmt.muscle(m),
            selected: selected.contains(m),
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

class _Pill extends StatelessWidget {
  const _Pill({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: ExcludeSemantics(
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: onTap,
          child: Container(
            constraints: const BoxConstraints(minHeight: 44),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: selected ? colors.primaryContainer : null,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: selected ? colors.primary : context.palette.border,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (selected) ...[
                  Icon(Icons.check, size: 18, color: colors.primary),
                  const SizedBox(width: 4),
                ],
                Flexible(
                  child: Text(
                    label,
                    style: context.text.bodyLarge?.copyWith(
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                      color: selected ? colors.onPrimaryContainer : null,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
