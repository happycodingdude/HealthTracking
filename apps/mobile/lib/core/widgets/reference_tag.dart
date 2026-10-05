import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/strings_vi.dart';
import '../../app/theme.dart';
import 'app_sheet.dart';
import 'heading.dart';

/// Đường dẫn S-55 "Về gợi ý tham khảo" (F10-R4).
const aboutReferencePath = '/reference';

/// 4 ý chính của thông báo tham khảo (F10-R1): S-02, S-55, bảng trượt của
/// nhãn "tham khảo".
class DisclaimerPoints extends StatelessWidget {
  const DisclaimerPoints({super.key});

  static const points = [
    S.disclaimerPoint1,
    S.disclaimerPoint2,
    S.disclaimerPoint3,
    S.disclaimerPoint4,
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final point in points)
          Padding(
            padding: const EdgeInsets.only(bottom: 20),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ExcludeSemantics(
                  child: CircleAvatar(
                    radius: 18,
                    backgroundColor: context.colors.primaryContainer,
                    child: Icon(
                      Icons.check,
                      size: 20,
                      color: context.colors.primary,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(point, style: context.text.bodyLarge),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Nhãn nhỏ màu vàng nhạt "tham khảo" (04 §6.13.2, F10-R2). Chạm → bảng trượt
/// nhắc lại ý chính của F10-R1, kèm "Xem đầy đủ" → S-55.
class ReferenceTag extends StatelessWidget {
  const ReferenceTag({super.key});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Semantics(
      button: true,
      label: S.referenceTag,
      child: ExcludeSemantics(
        child: InkWell(
          key: const ValueKey('reference-tag'),
          borderRadius: BorderRadius.circular(8),
          onTap: () => showAppSheet<void>(
            context,
            builder: (_) => const _ReferenceSheet(),
          ),
          child: ConstrainedBox(
            // Vùng chạm 44 điểm (04 §6.17), nhãn vẫn nhỏ.
            constraints: const BoxConstraints(minHeight: 44),
            child: Center(
              widthFactor: 1,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: palette.referenceContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  S.referenceTag,
                  style: context.text.labelLarge?.copyWith(
                    color: palette.reference,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ReferenceSheet extends StatelessWidget {
  const _ReferenceSheet();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Heading(
            S.aboutReferenceTitle,
            style: context.text.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 16),
          const DisclaimerPoints(),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: () {
                final router = GoRouter.of(context);
                Navigator.of(context).pop();
                router.push(aboutReferencePath);
              },
              child: const Text(S.seeFull),
            ),
          ),
        ],
      ),
    );
  }
}
