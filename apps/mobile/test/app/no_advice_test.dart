import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// 06 Bản 2 VS28-T06: UX-AC39, F10-AC23, F22-AC4 — câu chữ của S-63, S-64,
/// S-67 khu mức tạ, S-68, S-69 không mang nghĩa khuyên tăng giảm tạ, xếp hạng
/// hay kết luận. Câu cảnh báo F21-R8 dùng nguyên văn `03` nên được loại ra.
/// 06 Bản 3 VS37-T05: UX-AC62 — thêm câu chữ Bản 3 (S-63, S-64, S-67, S-68,
/// S-69, S-70, S-71, S-72, S-73).
void main() {
  final source = File('lib/app/strings_vi.dart').readAsStringSync();

  /// Câu chữ giữa hai mốc chú thích, bỏ chú thích code và câu cảnh báo
  /// nguyên văn F21-R8 / F21-R45 (UA2-11).
  String block(String from, String to) {
    final start = source.indexOf(from);
    final end = source.indexOf(to);
    expect(start, greaterThan(0));
    expect(end, greaterThan(start));
    return source
        .substring(start, end)
        .split('\n')
        .where((l) => !l.contains('liftEnd') && !l.trim().startsWith('//'))
        .join('\n')
        .toLowerCase()
        .replaceAll(RegExp("'mức tạ kết thúc [^']*'"), '');
  }

  void expectNoAdvice(String text) {
    for (final word in [
      'nên',
      'hãy',
      'tốt hơn',
      'yếu',
      'tăng tạ',
      'giảm tạ',
      'mục tiêu',
      'xu hướng',
      'xếp hạng',
      'kỷ lục',
      'chúc mừng',
    ]) {
      expect(
        RegExp(
          '(^|[^\\p{L}])$word([^\\p{L}]|\$)',
          unicode: true,
        ).hasMatch(text),
        isFalse,
        reason: word,
      );
    }
  }

  test('UX-AC39: không có từ khuyên hay kết luận trong câu chữ mức tạ, Tiến '
      'bộ, biểu đồ', () {
    expectNoAdvice(
      block('// S-63 Buổi tập, S-64 Ghi mức tạ', '// Hình món ăn'),
    );
  });

  test('UX-AC62: câu chữ Bản 3 (ghi chú, đơn vị, hộp đổi đơn vị, mốc biểu '
      'đồ, widget, thẻ màn hình khóa) không khuyên, xếp hạng, kết luận', () {
    final text = block(
      '// Bản 3 — câu chữ',
      'static const Map<String, String> catalog',
    );
    expect(text, contains('đổi sang'));
    expectNoAdvice(text);
  });
}
