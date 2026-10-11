// Báo cáo AC → test (ED-02, 06 §6.9.3; 06 Bản 2 §6.9.3: gộp cả `03` Bản 2).
//
// Đọc mã AC trong spec của từng bản (03: Fxx-ACn, LIB-ACn; 04: UX-ACn; 05:
// TAC-nn, TAC2-nn) và tìm mã đó trong tên/nội dung các file *_test.dart. In
// bảng Markdown cho từng bản: AC nào đã có test, AC nào chưa.
// Chạy: dart run tool/ac_report.dart
//
// `docs/` không được đưa lên git, nên trên CI không có spec: khi đó chỉ liệt
// kê các mã AC tìm thấy trong test, không có tổng số AC của spec.
import 'dart:io';

/// Spec của từng bản: đường dẫn → mẫu mã AC.
const _releases = {
  'Bản 1': {
    'docs/specs/v1/03-feature-specifications.md': r'\*\*(F\d{2}-AC\d+):\*\*',
    'docs/specs/v1/04-ux-ui-specifications.md': r'\*\*(UX-AC\d+):\*\*',
    'docs/specs/v1/05-technical-architecture.md': r'\*\*(TAC-\d+):\*\*',
  },
  'Bản 2': {
    'docs/specs/v2/03-feature-specifications.md':
        r'\*\*((?:F\d{2}|LIB)-AC\d+):\*\*',
    'docs/specs/v2/04-ux-ui-specifications.md': r'\*\*(UX-AC\d+):\*\*',
    'docs/specs/v2/05-technical-architecture.md': r'\*\*(TAC2-\d+):\*\*',
  },
};

/// Mã AC xuất hiện trong test (dùng khi không có spec).
final _acInTest = RegExp(
  r'\b(F\d{2}-AC\d+|LIB-AC\d+|UX-AC\d+|TAC2?-\d+)(?!\d)',
);

/// AC Bản 2 viết sẵn trong spec Bản 1 (kế hoạch cũ), không tính vào Bản 1.
bool _oldRelease2InV1(String ac) =>
    RegExp(r'^F1[2-4]-').hasMatch(ac) || ac == 'UX-AC19' || ac == 'UX-AC20';

void main() {
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

  List<String> coveredBy(String ac) {
    final pattern = RegExp('${RegExp.escape(ac)}(?!\\d)');
    return [
      for (final e in tests.entries)
        if (pattern.hasMatch(e.value)) e.key.split('/').last,
    ];
  }

  final out = StringBuffer()
    ..writeln('## Báo cáo AC → test (ED-02)')
    ..writeln();

  final hasSpecs = _releases.values.every(
    (specs) => specs.keys.every((p) => File(p).existsSync()),
  );
  if (!hasSpecs) {
    final found = {
      for (final t in tests.values)
        for (final m in _acInTest.allMatches(t)) m.group(1)!,
    }.toList()..sort();
    out
      ..writeln(
        'Không có spec trong repo (`docs/` không đưa lên git): chỉ liệt kê '
        '**${found.length}** mã AC tìm thấy trong test.',
      )
      ..writeln()
      ..writeln('| AC | Test |')
      ..writeln('|---|---|');
    for (final ac in found) {
      out.writeln('| $ac | ${coveredBy(ac).toSet().join(', ')} |');
    }
    stdout.write(out);
    return;
  }

  for (final release in _releases.entries) {
    final acs = <String>[];
    for (final spec in release.value.entries) {
      final text = File(spec.key).readAsStringSync();
      acs.addAll(RegExp(spec.value).allMatches(text).map((m) => m.group(1)!));
    }
    if (release.key == 'Bản 1') acs.removeWhere(_oldRelease2InV1);
    final covered = {for (final ac in acs) ac: coveredBy(ac)};
    final done = acs.where((a) => covered[a]!.isNotEmpty).length;
    out
      ..writeln('### ${release.key}: **$done/${acs.length}** AC đã có test')
      ..writeln()
      ..writeln('| AC | Test |')
      ..writeln('|---|---|');
    for (final ac in acs) {
      final files = covered[ac]!;
      out.writeln(
        '| $ac | ${files.isEmpty ? '—' : files.toSet().join(', ')} |',
      );
    }
    out.writeln();
  }
  stdout.write(out);
}
