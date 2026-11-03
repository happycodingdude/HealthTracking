@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/app/strings_vi.dart';
import 'package:mobile/ui/components/components.dart';
import 'package:mobile/ui/theme.dart';

import '../support/golden.dart';

/// 06 Bản 5 VS56-T04 (golden): `PauseGlyph` (đứng rời chữ phụ, cam, cỡ ô
/// lịch, trong vòng `StatusGlyph`), `DateField` (sửa được / chỉ xem / có câu
/// lỗi), banner tạm dừng, ô lịch tạm dừng — 04 Bản 5 §6.1, §6.2, UD5-03.
void main() {
  testWidgets('VS56-T04: PauseGlyph, DateField, PauseBanner, ô lịch tạm dừng', (
    tester,
  ) async {
    setPhoneSurface(tester, size: const Size(390, 520));
    applyVariant(tester, GoldenVariant.normal);
    await tester.pumpWidget(
      goldenHost(
        GoldenVariant.normal,
        Builder(
          builder: (context) => Material(
            color: context.tokens.surface,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Row(
                    children: [
                      PauseGlyph(),
                      SizedBox(width: 16),
                      PauseGlyph(accent: true),
                      SizedBox(width: 16),
                      PauseGlyph.small(),
                      SizedBox(width: 16),
                      StatusGlyph(GlyphStatus.paused, label: S.statusPaused),
                      SizedBox(width: 16),
                      StatusGlyph(
                        GlyphStatus.paused,
                        label: S.statusPaused,
                        size: TokenSize.glyphStrip,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  DateField(
                    label: S.pauseFrom,
                    value: S.todayDayMonth('03/11'),
                    onTap: () {},
                  ),
                  const SizedBox(height: 8),
                  const DateField(label: S.pauseFrom, value: 'T3 03/11'),
                  const SizedBox(height: 8),
                  DateField(
                    label: S.pauseTo,
                    value: 'T2 02/11',
                    error: S.pauseEndBeforeStart,
                    onTap: () {},
                  ),
                  const SizedBox(height: 16),
                  PauseBanner(until: 'CN 08/11', onEnd: () {}),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: 120,
                    child: MonthGrid(
                      weekdayLabels: const ['T4', 'T5', 'T6'],
                      leading: 0,
                      cells: const [
                        (
                          dateKey: '2026-11-04',
                          day: 4,
                          kind: MonthCellKind.paused,
                          extra: false,
                          overridden: false,
                          semantics: 'Thứ 4, 04/11: Lưng, Tạm dừng',
                        ),
                        (
                          dateKey: '2026-11-05',
                          day: 5,
                          kind: MonthCellKind.rest,
                          extra: false,
                          overridden: false,
                          semantics: 'Nghỉ',
                        ),
                        (
                          dateKey: '2026-11-06',
                          day: 6,
                          kind: MonthCellKind.paused,
                          extra: false,
                          overridden: false,
                          semantics: 'Thứ 6, 06/11: Vai, Tạm dừng',
                        ),
                      ],
                      onTap: (_) {},
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/pause_components.png'),
    );
  });
}
