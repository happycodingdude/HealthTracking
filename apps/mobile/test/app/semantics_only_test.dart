import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:yaml/yaml.dart';

/// 06 Bản 4 ED4-03, VS43-T05: câu chữ bị bỏ khỏi màn hình theo 01 Bản 4
/// (cờ `semanticsOnly` trong spec_strings.yaml) chỉ còn dùng làm nhãn
/// VoiceOver — mọi chỗ dùng `S.<key>` trong lib/ phải nằm trong tham số nhãn
/// (`label:`, `semanticLabel:`, `semantics:`, `semanticsLabel:`), không trong
/// `Text(`. Và mọi `StatusGlyph(` phải truyền `label:`.
void main() {
  final yaml = loadYaml(File('test/spec_strings.yaml').readAsStringSync());
  final semanticsOnly = ((yaml as YamlMap)['semanticsOnly'] as YamlList)
      .cast<String>();

  Iterable<File> dartFiles() => Directory('lib')
      .listSync(recursive: true)
      .whereType<File>()
      .where(
        (f) =>
            f.path.endsWith('.dart') &&
            !f.path.endsWith('strings_vi.dart') &&
            !f.path.endsWith('.g.dart'),
      );

  test('ED4-03: câu semanticsOnly không xuất hiện dưới dạng Text', () {
    final labelArg = RegExp(
      r'(label|semanticLabel|semantics|semanticsLabel|tooltip|hint):\s*$',
    );
    final problems = <String>[];
    for (final file in dartFiles()) {
      final src = file.readAsStringSync();
      for (final key in semanticsOnly) {
        for (final m in RegExp('\\bS\\.$key\\b').allMatches(src)) {
          // Ngữ cảnh ngay trước chỗ dùng: tham số nhãn (có thể qua xuống
          // dòng) hoặc hàm bọc nhãn.
          final before = src
              .substring((m.start - 60).clamp(0, src.length), m.start)
              .replaceAll(RegExp(r'\s+'), ' ')
              .trimRight();
          final ok =
              labelArg.hasMatch(before) ||
              RegExp(
                r'(label|semantics|Label)\s*[:=(]\s*\(?$',
              ).hasMatch(before);
          if (!ok) {
            final line = src.substring(0, m.start).split('\n').length;
            problems.add('${file.path}:$line: S.$key ngoài nhãn VoiceOver');
          }
        }
      }
    }
    expect(problems, isEmpty, reason: problems.join('\n'));
  });

  test('TD4-07: mọi StatusGlyph có label', () {
    final problems = <String>[];
    for (final file in dartFiles()) {
      if (file.path.endsWith('status_glyph.dart')) continue;
      final src = file.readAsStringSync();
      for (final m in RegExp(r'StatusGlyph\(').allMatches(src)) {
        // Tìm tới dấu đóng ngoặc tương ứng.
        var depth = 0;
        var end = m.end - 1;
        for (var i = m.end - 1; i < src.length; i++) {
          if (src[i] == '(') depth++;
          if (src[i] == ')') {
            depth--;
            if (depth == 0) {
              end = i;
              break;
            }
          }
        }
        final call = src.substring(m.start, end + 1);
        if (!call.contains('label:')) {
          final line = src.substring(0, m.start).split('\n').length;
          problems.add('${file.path}:$line: StatusGlyph thiếu label');
        }
      }
    }
    expect(problems, isEmpty, reason: problems.join('\n'));
  });

  test('ED4-03: mọi khóa semanticsOnly có trong strings_vi.dart', () {
    final src = File('lib/app/strings_vi.dart').readAsStringSync();
    for (final key in semanticsOnly) {
      expect(src.contains(' $key '), isTrue, reason: key);
    }
  });
}
