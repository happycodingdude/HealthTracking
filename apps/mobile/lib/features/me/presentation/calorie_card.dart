import 'package:domain/domain.dart';
import 'package:flutter/material.dart';

import '../../../app/strings_vi.dart';
import '../../../app/theme.dart';
import '../../../core/formatters.dart';
import '../../../core/widgets/app_sheet.dart';
import '../../../core/widgets/heading.dart';
import '../../../core/widgets/reference_tag.dart';
import '../application/calorie_view.dart';

/// Thẻ mức calo (S-04, S-52): chế độ, nhãn "tham khảo" (F02-R11), con số lớn,
/// dòng giải thích, ghi chú F02-E1/E2, liên kết "Cách app ước tính".
class CalorieCard extends StatelessWidget {
  const CalorieCard({super.key, required this.view});

  final CalorieView view;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final below = view.belowMaintenance;
    final note = view.note;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
      decoration: BoxDecoration(
        color: palette.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _Chip(
                view.mode == CalorieMode.auto ? S.calorieAuto : S.calorieManual,
                color: context.colors.onPrimaryContainer,
                background: context.colors.primaryContainer,
              ),
              const ReferenceTag(),
              if (view.belowSafetyFloor)
                _Chip(
                  S.belowSafetyFloor,
                  color: palette.attention,
                  background: palette.attentionContainer,
                ),
            ],
          ),
          const SizedBox(height: 8),
          Semantics(
            label: Fmt.kcal(view.kcal),
            child: ExcludeSemantics(
              child: Text.rich(
                key: const ValueKey('calorie-kcal'),
                TextSpan(
                  children: [
                    TextSpan(
                      text: Fmt.integer(view.kcal),
                      style: context.text.displayMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    TextSpan(
                      text: ' ${S.unitKcal}',
                      style: context.text.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (below != null) ...[
            const SizedBox(height: 12),
            Text(
              S.belowMaintenance(Fmt.integer(below)),
              style: context.text.bodyLarge?.copyWith(
                color: palette.textSecondary,
              ),
            ),
          ],
          if (note != null) ...[
            const SizedBox(height: 12),
            Text(
              switch (note) {
                CalorieNote.raisedToSafetyFloor => S.noteRaisedToFloor,
                CalorieNote.maintenanceBelowSafetyFloor =>
                  S.noteMaintenanceBelowFloor,
              },
              key: const ValueKey('calorie-note'),
              style: context.text.bodyLarge,
            ),
          ],
          const SizedBox(height: 4),
          TextButton(
            style: TextButton.styleFrom(padding: EdgeInsets.zero),
            onPressed: () => showAppSheet<void>(
              context,
              builder: (sheetContext) => Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Heading(
                      S.howEstimated,
                      style: sheetContext.text.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      S.howEstimatedBody,
                      style: sheetContext.text.bodyLarge,
                    ),
                  ],
                ),
              ),
            ),
            child: const Text(S.howEstimated),
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip(this.label, {required this.color, required this.background});

  final String label;
  final Color color;
  final Color background;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    decoration: BoxDecoration(
      color: background,
      borderRadius: BorderRadius.circular(10),
    ),
    child: Text(
      label,
      style: context.text.labelLarge?.copyWith(
        color: color,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}
