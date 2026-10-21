/// File SQL chia đoạn bằng dòng `-- migrate:commit` (05 Bản 3 §6.7.3): mỗi
/// đoạn chạy trong một transaction riêng, vì giá trị enum thêm bằng `ALTER
/// TYPE … ADD VALUE` phải được commit trước khi dùng.
abstract final class SqlScript {
  static const commitMarker = '-- migrate:commit';

  /// Các đoạn của [sql] theo thứ tự, bỏ đoạn chỉ có khoảng trắng/ghi chú.
  static List<String> segments(String sql) {
    final out = <String>[];
    final current = StringBuffer();
    void flush() {
      final text = current.toString();
      final meaningful = text
          .split('\n')
          .map((l) => l.trim())
          .any((l) => l.isNotEmpty && !l.startsWith('--'));
      if (meaningful) out.add(text);
      current.clear();
    }

    for (final line in sql.split('\n')) {
      if (line.trim() == commitMarker) {
        flush();
      } else {
        current.writeln(line);
      }
    }
    flush();
    return out;
  }
}
