import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/app/strings_vi.dart';
import 'package:yaml/yaml.dart';

void main() {
  final spec =
      (loadYaml(File('test/spec_strings.yaml').readAsStringSync()) as YamlMap)
          .cast<String, String>();

  test(
    'UR-12/ED-12: mọi câu trong spec_strings.yaml đúng nguyên văn trong strings_vi.dart',
    () {
      for (final entry in spec.entries) {
        expect(S.catalog[entry.key], entry.value, reason: entry.key);
      }
    },
  );

  test(
    'ED-12: mọi câu hằng trong strings_vi.dart đều có nguồn trong spec_strings.yaml',
    () {
      expect(S.catalog.keys.toSet().difference(spec.keys.toSet()), isEmpty);
    },
  );

  test('UR-14, S-56: câu có tham số', () {
    expect(S.greeting('Minh'), 'Chào Minh');
    expect(S.syncedAt('18:42'), 'Đã đồng bộ lúc 18:42');
  });

  test('OB-1, mock S-03, S-04/S-52, F02-R5: câu có tham số', () {
    expect(S.stepOf(2), 'Bước 2/5');
    expect(S.ageYears(30), '30 tuổi');
    expect(S.belowMaintenance('690'), 'Thấp hơn mức duy trì khoảng 690 kcal');
    expect(
      S.lowCalorieWarning('1.500'),
      'Mức này thấp hơn ngưỡng an toàn tham khảo (1.500 kcal). Thực đơn gợi ý vẫn sẽ dùng tối thiểu 1.500 kcal.',
    );
  });

  test('F03-V2, F03-V3, S-20: câu có tham số', () {
    expect(S.missingTimeFor('Thứ 6'), 'Vui lòng chọn giờ tập cho Thứ 6');
    expect(S.missingMusclesFor('Thứ 6'), 'Vui lòng chọn nhóm cơ cho Thứ 6');
    expect(S.monthTitle(10, 2026), 'Tháng 10/2026');
    expect(S.nextMonthNotice(11), 'Lịch tháng 11 sẽ có từ 01/11');
    expect(S.nextMonthNotice(1), 'Lịch tháng 1 sẽ có từ 01/01');
  });

  test('F08-E2: câu chạm trần ngân sách', () {
    expect(
      S.budgetPaused(11),
      'Gợi ý AI tạm dừng đến ngày 1/11 vì đã dùng hết ngân sách tháng này.',
    );
  });
}
