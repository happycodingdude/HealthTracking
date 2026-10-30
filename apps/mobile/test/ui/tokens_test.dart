import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/ui/tokens.g.dart';

/// 05 Bản 4 TD4-02, TAC4-03: file sinh Dart và Swift khớp `tokens.json`
/// (CI còn chạy `gen_tokens.dart --check`); vài giá trị neo theo 04 Bản 4 §6.1.
void main() {
  final json =
      jsonDecode(File('design/tokens.json').readAsStringSync())
          as Map<String, Object?>;
  final colors = (json['color'] as Map).cast<String, String>();

  int argb(String hex) {
    final h = hex.replaceFirst('#', '');
    return int.parse(h.length == 6 ? 'FF$h' : h, radix: 16);
  }

  test('tokens.g.dart khớp tokens.json (màu)', () {
    expect(TokenColor.bg.toARGB32(), argb(colors['bg']!));
    expect(TokenColor.surface.toARGB32(), argb(colors['surface']!));
    expect(TokenColor.accent.toARGB32(), argb(colors['accent']!));
    expect(TokenColor.danger.toARGB32(), argb(colors['danger']!));
    expect(TokenColor.textSecondary.toARGB32(), argb(colors['textSecondary']!));
  });

  test('04 Bản 4 §6.1: giá trị neo', () {
    expect(colors['bg'], '#121212');
    expect(colors['surface'], '#1E1E1E');
    expect(colors['surfaceRaised'], '#2A2A2A');
    expect(colors['accent'], '#FF6A1A');
    expect(colors['textSecondary'], '#8E8E93');
    expect(TokenType.title, 17);
    expect(TokenType.body, 14);
    expect(TokenType.caption, 11);
    expect(TokenRadius.card, 14);
    expect(TokenRadius.button, 10);
    expect(TokenSize.button, 44);
  });

  test('Tokens.g.swift có cùng tên màu', () {
    final swift = File('ios/IronlyWidgets/Tokens.g.swift').readAsStringSync();
    for (final name in colors.keys) {
      expect(swift.contains('static let $name = Color('), isTrue, reason: name);
    }
  });
}
