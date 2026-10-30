// Kiểm tra quy tắc code ở 06 §6.4.4 mà analyzer không tự kiểm được:
// 1. packages/domain không import Flutter, Drift, postgres, dart:io, dart:ui.
// 2. Không có chuỗi tiếng Việt trong apps/mobile/lib ngoài app/strings_vi.dart.
//
// Chạy: dart run tool/lint.dart
import 'dart:io';

final _forbiddenDomainImports = RegExp(
  r'''^\s*(import|export)\s+['"](package:flutter|package:drift|package:postgres|dart:io|dart:ui)''',
  multiLine: true,
);

// Chữ Latin có dấu (Latin-1 Supplement, Latin Extended A/B, Latin Extended Additional).
final _vietnamese = RegExp(r'[À-ɏḀ-ỿ]');

void main() {
  final problems = <String>[];

  for (final file in _dartFiles('packages/domain/lib')) {
    final src = file.readAsStringSync();
    for (final m in _forbiddenDomainImports.allMatches(src)) {
      problems.add('${file.path}: domain không được import "${m.group(2)}"');
    }
  }

  for (final file in _dartFiles('apps/mobile/lib')) {
    final path = file.path.replaceAll(r'\', '/');
    // lib/dev/: dữ liệu mô tả cho công cụ duyệt (06 Bản 4 ED4-04), không
    // hiện trên màn hình.
    if (path.endsWith('lib/app/strings_vi.dart') ||
        path.endsWith('.g.dart') ||
        path.contains('/lib/dev/')) {
      continue;
    }
    for (final literal in stringLiterals(file.readAsStringSync())) {
      if (_vietnamese.hasMatch(literal)) {
        problems.add(
          '$path: chuỗi tiếng Việt phải nằm trong strings_vi.dart: "$literal"',
        );
      }
    }
  }

  if (problems.isNotEmpty) {
    stderr.writeln(problems.join('\n'));
    exit(1);
  }
  stdout.writeln('lint: OK');
}

Iterable<File> _dartFiles(String dir) {
  final d = Directory(dir);
  if (!d.existsSync()) return const [];
  return d
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'));
}

/// Trả về nội dung các string literal trong mã Dart, bỏ qua comment.
List<String> stringLiterals(String src) {
  final out = <String>[];
  var i = 0;
  while (i < src.length) {
    final c = src[i];
    if (src.startsWith('//', i)) {
      final end = src.indexOf('\n', i);
      i = end < 0 ? src.length : end;
      continue;
    }
    if (src.startsWith('/*', i)) {
      final end = src.indexOf('*/', i + 2);
      i = end < 0 ? src.length : end + 2;
      continue;
    }
    if (c == "'" || c == '"') {
      final raw = i > 0 && src[i - 1] == 'r';
      final triple = src.startsWith(c * 3, i);
      final quote = triple ? c * 3 : c;
      var j = i + quote.length;
      final buf = StringBuffer();
      while (j < src.length && !src.startsWith(quote, j)) {
        if (!raw && src[j] == r'\' && j + 1 < src.length) {
          buf.write(src[j + 1]);
          j += 2;
          continue;
        }
        buf.write(src[j]);
        j++;
      }
      out.add(buf.toString());
      i = j + quote.length;
      continue;
    }
    i++;
  }
  return out;
}
