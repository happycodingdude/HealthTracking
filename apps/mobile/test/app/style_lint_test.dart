import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// 05 Bản 4 AP-16, TAC4-03; 06 Bản 4 VS43-T06: màn hình và thành phần chỉ
/// đọc màu, cỡ chữ từ token sinh ra — không `Color(0x…)`, không `Colors.`,
/// không `fontSize:` số rời. Danh sách ngoại lệ rỗng.
void main() {
  final banned = {
    'Color(0x': RegExp(r'\bColor\(0x'),
    'Colors.': RegExp(r'\bColors\.'),
    'fontSize: <số>': RegExp(r'fontSize:\s*\d'),
  };

  test('VS43-T06: lib/features/** và lib/ui/components/** không có màu / cỡ '
      'chữ rời', () {
    final problems = <String>[];
    for (final dir in ['lib/features', 'lib/ui/components']) {
      for (final file in Directory(dir).listSync(recursive: true)) {
        if (file is! File || !file.path.endsWith('.dart')) continue;
        final lines = file.readAsLinesSync();
        for (final (i, line) in lines.indexed) {
          final code = line.split('//').first;
          for (final e in banned.entries) {
            if (e.value.hasMatch(code)) {
              problems.add('${file.path}:${i + 1}: ${e.key}');
            }
          }
        }
      }
    }
    expect(problems, isEmpty, reason: problems.join('\n'));
  });
}
