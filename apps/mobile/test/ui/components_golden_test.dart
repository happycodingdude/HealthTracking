@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/ui/components/components.dart';
import 'package:mobile/ui/gallery.dart';

import '../support/golden.dart';

/// 06 Bản 4 VS43-T07: golden cho từng thành phần ở mọi trạng thái (trang
/// gallery), theme tối × cỡ chữ mặc định + lớn nhất; hộp xác nhận, bảng trượt
/// riêng.
void main() {
  for (final v in GoldenVariant.all) {
    testWidgets('VS43-T07: gallery thành phần ${v.name}', (tester) async {
      setPhoneSurface(tester, size: const Size(390, 2400));
      applyVariant(tester, v);
      await tester.pumpWidget(
        goldenHost(v, const ComponentGallery(showBack: false)),
      );
      // Nút "Loading" có vòng xoay vô hạn: không pumpAndSettle.
      await tester.pump(const Duration(milliseconds: 300));
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/components_${v.name}.png'),
      );
    });

    testWidgets('VS43-T07: hộp xác nhận ${v.name}', (tester) async {
      setPhoneSurface(tester);
      applyVariant(tester, v);
      await tester.pumpWidget(
        goldenHost(
          v,
          Scaffold(
            body: Builder(
              builder: (context) => Center(
                child: IronlyButton.gray(
                  label: 'open',
                  onPressed: () => showIronlyDialog<void>(
                    context,
                    builder: (_) => IronlyDialog(
                      title: 'Dialog title',
                      body: 'Body text kept verbatim from the spec.',
                      secondaryLabel: 'Cancel',
                      onSecondary: () {},
                      primaryLabel: 'Confirm',
                      onPrimary: () {},
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/dialog_${v.name}.png'),
      );
    });

    testWidgets('VS43-T07: bảng trượt ${v.name}', (tester) async {
      setPhoneSurface(tester);
      applyVariant(tester, v);
      await tester.pumpWidget(
        goldenHost(
          v,
          Scaffold(
            body: Builder(
              builder: (context) => Center(
                child: IronlyButton.gray(
                  label: 'open',
                  onPressed: () => showIronlySheet<void>(
                    context,
                    builder: (_) => IronlySheet(
                      title: 'Sheet title',
                      footer: IronlyButton.primary(
                        label: 'Save',
                        onPressed: () {},
                      ),
                      children: const [Text('Sheet body')],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/sheet_${v.name}.png'),
      );
    });
  }
}
