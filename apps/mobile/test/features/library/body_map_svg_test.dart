import 'dart:io';

import 'package:domain/domain.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/library/presentation/body_map.dart';

/// Các nhóm `<g id=…>` của một file SVG: id → các `d` của `<path>` bên trong.
Map<String, List<String>> _groups(String svg) => {
  for (final m in RegExp(
    r'<g id="([a-z_]+)">(.*?)</g>',
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

  test('ED2-10: 4 file SVG nằm trong assets, có viewBox, không có fill, '
      'stroke, style (app tự tô)', () {
    expect(files, hasLength(4));
    for (final MapEntry(:key, :value) in files.entries) {
      expect(value, contains('viewBox="0 0 1024 1536"'), reason: '$key');
      for (final banned in ['fill=', 'stroke', 'style=']) {
        expect(value, isNot(contains(banned)), reason: '$key: $banned');
      }
    }
  });

  // 3 vùng chân vào cùng 4 SVG Bản 3 ở VS-33 (VS33-T03).
  test('ED2-10: đủ 16 id Bản 2 (10 mặt trước, 6 mặt sau) cùng body và '
      'other_muscles; mỗi vùng không rỗng và có đủ hai bên', () {
    final front = [
      for (final r in MuscleRegion.values)
        if (r.view == BodyView.front && r.group != MuscleGroup.legs) r.id,
    ];
    final back = [
      for (final r in MuscleRegion.values)
        if (r.view == BodyView.back && r.group != MuscleGroup.legs) r.id,
    ];
    expect((front.length, back.length), (10, 6));
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
      'màu trung tính, các vùng khác màu cơ; không đổi hình', () {
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
    expect(fills, hasLength(12));
    expect(fills['chest_mid'], '#0a7c66');
    expect(fills['body'], '#eeeeee');
    expect(fills['other_muscles'], '#cccccc');
    expect(fills['chest_upper'], '#cccccc');
    expect(
      out.replaceAll(RegExp(r' fill="#[0-9a-f]{6}"'), ''),
      svg,
      reason: 'chỉ thêm fill, không sửa path',
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
}
