import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// 06 Bản 2 VS28-T06: UX-AC39, F10-AC23, F22-AC4 — câu chữ của S-63, S-64,
/// S-67 khu mức tạ, S-68, S-69 không mang nghĩa khuyên tăng giảm tạ, xếp hạng
/// hay kết luận. Câu cảnh báo F21-R8 dùng nguyên văn `03` nên được loại ra.
void main() {
  test('UX-AC39: không có từ khuyên hay kết luận trong câu chữ mức tạ, Tiến '
      'bộ, biểu đồ', () {
    final source = File('lib/app/strings_vi.dart').readAsStringSync();
    final start = source.indexOf('// S-63 Buổi tập, S-64 Ghi mức tạ');
    final end = source.indexOf('// Hình món ăn');
    expect(start, greaterThan(0));
    expect(end, greaterThan(start));
    final block = source
        .substring(start, end)
        .split('\n')
        // Câu cảnh báo nguyên văn F21-R8 (UA2-11) và chú thích code.
        .where((l) => !l.contains('liftEnd') && !l.trim().startsWith('//'))
        .join('\n')
        .toLowerCase();
    // Bỏ phần cảnh báo nguyên văn (hai dòng sau tên hàm).
    final withoutWarnings = block.replaceAll(
      RegExp("'mức tạ kết thúc [^']*'"),
      '',
    );
    for (final word in [
      'nên',
      'tốt hơn',
      'yếu',
      'tăng tạ',
      'giảm tạ',
      'mục tiêu',
      'xu hướng',
      'xếp hạng',
    ]) {
      expect(
        RegExp(
          '(^|[^\\p{L}])$word([^\\p{L}]|\$)',
          unicode: true,
        ).hasMatch(withoutWarnings),
        isFalse,
        reason: word,
      );
    }
  });
}
