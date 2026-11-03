@Tags(['golden'])
library;

import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/ui/components/components.dart';
import 'package:mobile/ui/theme.dart';

import '../support/golden.dart';

/// 06 Bản 5 VS55-T04 (golden): `FeelGlyph` 6 dạng — Thoải mái / Vừa / Mệt ×
/// hôm nay (cam) / buổi trước (xám) — 04 Bản 5 §6.1, UD5-01. Phóng 4× để
/// thấy rõ 3 vạch 3 × 5 / 8 / 12 cách 2.
void main() {
  testWidgets('VS55-T04: FeelGlyph 6 dạng', (tester) async {
    setPhoneSurface(tester, size: const Size(240, 140));
    applyVariant(tester, GoldenVariant.all.first);
    await tester.pumpWidget(
      goldenHost(
        GoldenVariant.all.first,
        Builder(
          builder: (context) => ColoredBox(
            color: context.tokens.surface,
            child: Center(
              child: Transform.scale(
                scale: 4,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final previous in const [false, true])
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            for (final f in Feel.values)
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 2,
                                ),
                                child: FeelGlyph(f, previous: previous),
                              ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/feel_glyph.png'),
    );
  });
}
