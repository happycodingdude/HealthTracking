import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/onboarding/presentation/profile_fields.dart';

import '../../support/golden.dart';

/// Bạn quyết 31/10/2026: không hiện số tuổi ở bánh xe chọn năm sinh và ô
/// Năm sinh (S-03, S-51).
void main() {
  Widget host(Widget child) =>
      goldenHost(GoldenVariant.normal, Scaffold(body: child));

  testWidgets('Bánh xe năm sinh: chỉ có năm, không có số tuổi', (tester) async {
    await tester.pumpWidget(
      host(const BirthYearPicker(first: 1946, last: 2008, initial: 1995)),
    );
    expect(find.text('1995'), findsOneWidget);
    expect(find.textContaining('tuổi'), findsNothing);
  });

  testWidgets('Ô Năm sinh: "1995 ›", không có số tuổi', (tester) async {
    await tester.pumpWidget(
      host(BirthYearField(year: 1995, hasError: false, onTap: () {})),
    );
    expect(find.text('1995'), findsOneWidget);
    expect(find.textContaining('tuổi'), findsNothing);
  });
}
