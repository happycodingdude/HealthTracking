import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/app/strings_vi.dart';
import 'package:mobile/app/third_party_licenses.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'VS31-T05 (06 Bản 2): giấy phép MIT của bộ sơ đồ cơ nằm cùng chỗ với '
    'giấy phép các thư viện khác, đủ dòng bản quyền và nội dung giấy phép',
    () async {
      registerThirdPartyLicenses();
      final entries = await LicenseRegistry.licenses
          .where((e) => e.packages.contains(S.bodyMapLicense))
          .toList();

      expect(entries, hasLength(1));
      final text = entries.single.paragraphs.map((p) => p.text).join('\n');
      expect(text, contains('MIT License'));
      expect(
        text,
        contains('Copyright (c) 2026 Jsplice / MuscleMap contributors'),
      );
      expect(text, contains('Permission is hereby granted, free of charge'));
      expect(text, contains('The above copyright notice and this permission'));
    },
  );
}
