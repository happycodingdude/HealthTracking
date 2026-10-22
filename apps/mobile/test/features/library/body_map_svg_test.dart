import 'dart:convert';
import 'dart:io';

import 'package:domain/domain.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/library/presentation/body_map.dart';

/// Các nhóm `<g id=…>` của một file SVG: id → các `d` của `<path>` bên trong.
Map<String, List<String>> _groups(String svg) => {
  for (final m in RegExp(
    r'<g id="([a-z_]+)"[^>]*>(.*?)</g>',
    dotAll: true,
  ).allMatches(svg))
    m.group(1)!: [
      for (final p in RegExp(r'<path d="([^"]+)"').allMatches(m.group(2)!))
        p.group(1)!,
    ],
};

/// Tâm ngang khung bao của một path (tọa độ tuyệt đối x y xen kẽ).
double _centerX(String d) {
  final nums = [
    for (final n in RegExp(r'-?\d+(\.\d+)?').allMatches(d))
      double.parse(n.group(0)!),
  ];
  final xs = [for (var i = 0; i < nums.length; i += 2) nums[i]];
  return (xs.reduce((a, b) => a < b ? a : b) +
          xs.reduce((a, b) => a > b ? a : b)) /
      2;
}

void main() {
  final files = {
    for (final sex in Sex.values)
      for (final view in BodyView.values)
        (sex, view): File(
          'assets/body_map/${BodyMap.fileOf(sex, view)}.svg',
        ).readAsStringSync(),
  };

  test('ED2-10, IR3-08: 4 file SVG Bản 3 nằm trong assets nguyên văn gói '
      'duyệt, có viewBox, không có stroke, style; fill chỉ trên thẻ nhóm (app '
      'ghi đè khi tô)', () {
    expect(files, hasLength(4));
    for (final MapEntry(:key, :value) in files.entries) {
      expect(value, contains('viewBox="0 0 1024 1536"'), reason: '$key');
      expect(value, contains('19 regions'), reason: '$key');
      for (final banned in ['stroke', 'style=', '<path fill']) {
        expect(value, isNot(contains(banned)), reason: '$key: $banned');
      }
    }
  });

  test('VS33-T03, TD3-19: đủ 19 id (11 mặt trước: 10 + quads; 8 mặt sau: 6 + '
      'hamstrings, calves) cùng body và other_muscles; mỗi vùng không rỗng và '
      'có đủ hai bên', () {
    final front = [
      for (final r in MuscleRegion.values)
        if (r.view == BodyView.front) r.id,
    ];
    final back = [
      for (final r in MuscleRegion.values)
        if (r.view == BodyView.back) r.id,
    ];
    expect((front.length, back.length), (11, 8));
    for (final MapEntry(key: (sex, view), :value) in files.entries) {
      final groups = _groups(value);
      final regions = view == BodyView.front ? front : back;
      expect(groups.keys.toSet(), {
        'body',
        'other_muscles',
        ...regions,
      }, reason: '$sex $view');
      expect(groups['body'], isNotEmpty);
      expect(groups['other_muscles'], isNotEmpty);
      for (final id in regions) {
        final centers = groups[id]!.map(_centerX).toList();
        expect(
          centers.where((x) => x < 512),
          isNotEmpty,
          reason: '$sex $view $id: bên trái',
        );
        expect(
          centers.where((x) => x > 512),
          isNotEmpty,
          reason: '$sex $view $id: bên phải',
        );
      }
    }
  });

  test('BodyMapPainter: vùng của bài màu chủ đạo, body và other_muscles '
      'màu trung tính, các vùng khác màu cơ (ghi đè fill có sẵn); không đổi '
      'hình', () {
    const highlight = Color(0xFF0A7C66);
    const body = Color(0xFFEEEEEE);
    const muscle = Color(0xFFCCCCCC);
    final svg = files[(Sex.female, BodyView.front)]!;
    final out = BodyMapPainter.colorize(
      svg,
      regionId: MuscleRegion.chestMid.id,
      highlight: highlight,
      body: body,
      muscle: muscle,
    );
    final fills = {
      for (final m in RegExp(
        r'<g id="([a-z_]+)" fill="(#[0-9a-f]{6})">',
      ).allMatches(out))
        m.group(1)!: m.group(2)!,
    };
    expect(fills, hasLength(13));
    expect(fills['chest_mid'], '#0a7c66');
    expect(fills['body'], '#eeeeee');
    expect(fills['other_muscles'], '#cccccc');
    expect(fills['chest_upper'], '#cccccc');
    String groupsOnly(String s) =>
        s.replaceAll(RegExp(r'<g id="([a-z_]+)"[^>]*>'), '<g>');
    expect(
      groupsOnly(out),
      groupsOnly(svg),
      reason: 'chỉ thay thẻ mở của nhóm, không sửa path',
    );
    expect(
      identical(
        BodyMapPainter.colorize(
          svg,
          regionId: MuscleRegion.chestMid.id,
          highlight: highlight,
          body: body,
          muscle: muscle,
        ),
        out,
      ),
      isTrue,
      reason: 'cache theo (file, vùng, màu)',
    );
  });

  test('F18-AC45, VS33-T04: vùng không có bài (lưng dưới, cơ cánh tay và cẳng '
      'tay) không bao giờ được tô — app chỉ tô vùng của một bài', () {
    final library =
        (jsonDecode(File('../../data/v3__exercises.json').readAsStringSync())
                as Map)['exercises']!
            as List;
    final used = {for (final e in library) (e as Map)['muscleRegion']};
    expect(used, isNot(contains(MuscleRegion.backLower.id)));
    expect(used, isNot(contains(MuscleRegion.brachialisForearm.id)));
    expect(used, hasLength(17));
    // Mọi chỗ vẽ sơ đồ cơ trong app đều lấy vùng từ một bài.
    final calls = <String>[];
    for (final f in Directory('lib').listSync(recursive: true)) {
      if (f is! File || !f.path.endsWith('.dart')) continue;
      final src = f.readAsStringSync();
      for (final m in RegExp(
        r'BodyMap\(\s*region:\s*([^,)]+)',
      ).allMatches(src)) {
        calls.add('${f.path}: ${m.group(1)}');
      }
    }
    expect(calls, isNotEmpty);
    for (final c in calls) {
      expect(c, endsWith('.region'), reason: c);
    }
  });
}
