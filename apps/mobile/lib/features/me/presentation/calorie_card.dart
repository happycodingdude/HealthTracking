import 'package:domain/domain.dart';
import 'package:flutter/material.dart';

import '../../../app/strings_vi.dart';
import '../../../core/formatters.dart';
import '../../../ui/components/components.dart';
import '../../../ui/theme.dart';
import '../application/calorie_view.dart';

/// Thẻ mức calo (S-04, S-52, 04 Bản 4): số lớn 34 "2.210" + "kcal"; thanh
/// chọn Tự động | Tự đặt (chọn = cam); dưới ngưỡng an toàn: số đỏ + câu cảnh
/// báo giữ nguyên (F02-E1/E2). Không nhãn "tham khảo", không "Cách app ước
/// tính" (FR4-04, FR4-05).
class CalorieCard extends StatelessWidget {
  const CalorieCard({
    super.key,
    required this.view,
    this.onAuto,
    this.onManual,
  });

  final CalorieView view;

  /// Chạm "Tự động" khi đang Tự đặt → dùng lại ước tính của app (F02-AC6).
  /// null (S-04): không có thanh chọn, nút đặt mức nằm dưới thẻ.
  final VoidCallback? onAuto;

  /// Chạm "Tự đặt" → bảng đặt mức (F02-R4).
  final VoidCallback? onManual;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final note = view.note;
    final manual = view.mode == CalorieMode.manual;
    return IronlyCard(
      key: const ValueKey('calorie-card'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            label: Fmt.kcal(view.kcal),
            child: ExcludeSemantics(
              child: Text.rich(
                key: const ValueKey('calorie-kcal'),
                textAlign: TextAlign.center,
                TextSpan(
                  children: [
                    TextSpan(
                      text: Fmt.integer(view.kcal),
                      style: IronlyText.numberLarge.copyWith(
                        color: view.belowSafetyFloor ? t.danger : null,
                      ),
                    ),
                    TextSpan(text: ' ${S.unitKcal}', style: IronlyText.caption),
                  ],
                ),
              ),
            ),
          ),
          if (onManual != null) ...[
            const SizedBox(height: TokenSpace.s3),
            SegmentBar<CalorieMode>(
              items: const [CalorieMode.auto, CalorieMode.manual],
              selected: view.mode,
              label: (m) =>
                  m == CalorieMode.auto ? S.calorieAuto : S.calorieManualShort,
              keyOf: (m) => ValueKey(
                m == CalorieMode.auto
                    ? (manual ? 'use-app-estimate' : 'calorie-auto')
                    : 'set-other-level',
              ),
              style: SegmentStyle.accent,
              onSelected: (m) => m == CalorieMode.auto
                  ? (manual ? onAuto?.call() : null)
                  : onManual?.call(),
            ),
          ],
          if (note != null) ...[
            const SizedBox(height: TokenSpace.s2),
            Text(
              switch (note) {
                CalorieNote.raisedToSafetyFloor => S.noteRaisedToFloor,
                CalorieNote.maintenanceBelowSafetyFloor =>
                  S.noteMaintenanceBelowFloor,
              },
              key: const ValueKey('calorie-note'),
              style: IronlyText.caption.copyWith(color: t.danger),
            ),
          ],
        ],
      ),
    );
  }
}
