import 'package:flutter/material.dart';

import '../../app/strings_vi.dart';
import '../../ui/components/components.dart';
import '../../ui/theme.dart';

/// Đường dẫn S-55 "Về gợi ý tham khảo" (F10-R4).
const aboutReferencePath = '/reference';

/// 4 ý chính của thông báo tham khảo (F10-R1): S-02, S-55 (Bản 4 bỏ nhãn
/// "tham khảo" và bảng trượt của nhãn, FR4-05).
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
    final t = context.tokens;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (i, point) in points.indexed)
          Padding(
            padding: EdgeInsets.only(bottom: i == points.length - 1 ? 0 : 10),
            child: IronlyCard(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ExcludeSemantics(
                    child: CircleIcon(
                      Icons.check,
                      size: 32,
                      color: t.accent,
                      background: t.accentSoft,
                    ),
                  ),
                  const SizedBox(width: TokenSpace.s3),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(point, style: IronlyText.body),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
