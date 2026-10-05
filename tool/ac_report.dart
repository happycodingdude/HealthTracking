// Báo cáo AC → test (ED-02, 06 §6.9.3).
//
// Đọc mã AC trong spec (03: Fxx-ACn, 04: UX-ACn, 05: TAC-nn) và tìm mã đó
// trong tên/nội dung các file *_test.dart. In bảng Markdown: AC nào đã có test,
// AC nào chưa. Chạy: dart run tool/ac_report.dart
import 'dart:io';

const _specs = {
  'docs/specs/03-feature-specifications.md': r'\*\*(F\d{2}-AC\d+):\*\*',
  'docs/specs/04-ux-ui-specifications.md': r'\*\*(UX-AC\d+):\*\*',
  'docs/specs/05-technical-architecture.md': r'\*\*(TAC-\d+):\*\*',
};

/// AC của Bản 2, không tính vào Bản 1.
bool _isRelease2(String ac) =>
    RegExp(r'^F1[2-4]-').hasMatch(ac) || ac == 'UX-AC19' || ac == 'UX-AC20';

void main() {
  final acs = <String>[];
  for (final entry in _specs.entries) {
    final text = File(entry.key).readAsStringSync();
    acs.addAll(RegExp(entry.value).allMatches(text).map((m) => m.group(1)!));
  }

  final tests = <String, String>{};
  for (final dir in ['packages', 'apps']) {
    for (final f in Directory(
      dir,
    ).listSync(recursive: true).whereType<File>()) {
      if (f.path.endsWith('_test.dart') && !f.path.contains('/.dart_tool/')) {
        tests[f.path] = f.readAsStringSync();
      }
    }
  }

  final covered = <String, List<String>>{};
  for (final ac in acs) {
    final pattern = RegExp('${RegExp.escape(ac)}(?!\\d)');
    covered[ac] = [
      for (final e in tests.entries)
        if (pattern.hasMatch(e.value)) e.key.split('/').last,
    ];
  }

  final release1 = acs.where((a) => !_isRelease2(a)).toList();
  final done = release1.where((a) => covered[a]!.isNotEmpty).length;
  final out = StringBuffer()
    ..writeln('## Báo cáo AC → test (ED-02)')
    ..writeln()
    ..writeln('Bản 1: **$done/${release1.length}** AC đã có test.')
    ..writeln()
    ..writeln('| AC | Test |')
    ..writeln('|---|---|');
  for (final ac in release1) {
    final files = covered[ac]!;
    out.writeln('| $ac | ${files.isEmpty ? '—' : files.toSet().join(', ')} |');
  }
  stdout.write(out);
}
