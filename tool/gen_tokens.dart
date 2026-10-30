// Sinh token giao diện Bản 4 từ apps/mobile/design/tokens.json (05 Bản 4
// TD4-02, §6.4): một nguồn cho Flutter (lib/ui/tokens.g.dart) và extension
// Swift (ios/IronlyWidgets/Tokens.g.swift).
//
//   dart run tool/gen_tokens.dart           ghi hai file sinh
//   dart run tool/gen_tokens.dart --check   chỉ so sánh; khác → exit 1 (CI)
import 'dart:convert';
import 'dart:io';

const source = 'apps/mobile/design/tokens.json';
const dartOut = 'apps/mobile/lib/ui/tokens.g.dart';
const swiftOut = 'apps/mobile/ios/IronlyWidgets/Tokens.g.swift';

void main(List<String> args) {
  final check = args.contains('--check');
  final json =
      jsonDecode(File(source).readAsStringSync()) as Map<String, Object?>;
  final outputs = {dartOut: generateDart(json), swiftOut: generateSwift(json)};
  var dirty = false;
  for (final e in outputs.entries) {
    final file = File(e.key);
    final current = file.existsSync() ? file.readAsStringSync() : null;
    if (current == e.value) continue;
    dirty = true;
    if (check) {
      stderr.writeln('gen_tokens: ${e.key} không khớp $source');
    } else {
      file.writeAsStringSync(e.value);
      stdout.writeln('gen_tokens: đã ghi ${e.key}');
    }
  }
  if (check) {
    if (dirty) exit(1);
    stdout.writeln('gen_tokens: OK (file sinh khớp $source)');
  } else if (!dirty) {
    stdout.writeln('gen_tokens: không có gì đổi');
  }
}

Map<String, Object?> group(Map<String, Object?> json, String name) =>
    (json[name] as Map).cast<String, Object?>();

String ident(String key) {
  // "1" → "s1" (khoảng cách), còn lại giữ nguyên camelCase.
  if (RegExp(r'^\d').hasMatch(key)) return 's$key';
  return key;
}

String fmtNum(Object? v) {
  final n = v as num;
  return n is int || n == n.roundToDouble() ? n.toInt().toString() : '$n';
}

String generateDart(Map<String, Object?> json) {
  final b = StringBuffer()
    ..writeln('// GENERATED CODE - DO NOT MODIFY BY HAND')
    ..writeln('// Sinh từ $source bằng `dart run tool/gen_tokens.dart`.')
    ..writeln('// ignore_for_file: public_member_api_docs')
    ..writeln()
    ..writeln("import 'dart:ui' show Color;")
    ..writeln()
    ..writeln('/// Màu (04 Bản 4 §6.1).')
    ..writeln('abstract final class TokenColor {');
  for (final e in group(json, 'color').entries) {
    b.writeln(
      '  static const ${ident(e.key)} = Color(0x${argb(e.value as String)});',
    );
  }
  b
    ..writeln('}')
    ..writeln()
    ..writeln('/// Cỡ chữ (điểm, ở mức Dynamic Type mặc định).')
    ..writeln('abstract final class TokenType {');
  for (final e in group(json, 'type').entries) {
    b.writeln('  static const double ${ident(e.key)} = ${fmtNum(e.value)};');
  }
  b
    ..writeln('}')
    ..writeln()
    ..writeln('/// Độ đậm chữ.')
    ..writeln('abstract final class TokenWeight {');
  for (final e in group(json, 'weight').entries) {
    b.writeln('  static const int ${ident(e.key)} = ${fmtNum(e.value)};');
  }
  for (final (name, cls) in [
    ('radius', 'TokenRadius'),
    ('space', 'TokenSpace'),
    ('size', 'TokenSize'),
  ]) {
    b
      ..writeln('}')
      ..writeln()
      ..writeln('abstract final class $cls {');
    for (final e in group(json, name).entries) {
      b.writeln('  static const double ${ident(e.key)} = ${fmtNum(e.value)};');
    }
  }
  b.writeln('}');
  return b.toString();
}

/// "#RRGGBB" | "#AARRGGBB" → "AARRGGBB".
String argb(String hex) {
  final h = hex.replaceFirst('#', '').toUpperCase();
  return h.length == 6 ? 'FF$h' : h;
}

String generateSwift(Map<String, Object?> json) {
  final b = StringBuffer()
    ..writeln('// GENERATED CODE - DO NOT MODIFY BY HAND')
    ..writeln('// Sinh từ $source bằng `dart run tool/gen_tokens.dart`.')
    ..writeln('import SwiftUI')
    ..writeln()
    ..writeln('/// Token Bản 4 (05 Bản 4 TD4-02): màu đặt thẳng, không theo')
    ..writeln('/// chế độ sáng / tối của hệ thống (TA4-08).')
    ..writeln('enum Tokens {')
    ..writeln('  enum color {');
  for (final e in group(json, 'color').entries) {
    final a = argb(e.value as String);
    final alpha = int.parse(a.substring(0, 2), radix: 16) / 255;
    final r = int.parse(a.substring(2, 4), radix: 16) / 255;
    final g = int.parse(a.substring(4, 6), radix: 16) / 255;
    final bl = int.parse(a.substring(6, 8), radix: 16) / 255;
    String f(double v) => v.toStringAsFixed(4);
    b.writeln(
      '    static let ${ident(e.key)} = Color(red: ${f(r)}, green: ${f(g)}, '
      'blue: ${f(bl)}, opacity: ${f(alpha)})',
    );
  }
  b.writeln('  }');
  for (final (name, cls) in [
    ('type', 'type'),
    ('weight', 'weight'),
    ('radius', 'radius'),
    ('space', 'space'),
    ('size', 'size'),
  ]) {
    b
      ..writeln()
      ..writeln('  enum $cls {');
    for (final e in group(json, name).entries) {
      b.writeln('    static let ${ident(e.key)}: CGFloat = ${fmtNum(e.value)}');
    }
    b.writeln('  }');
  }
  b.writeln('}');
  return b.toString();
}
