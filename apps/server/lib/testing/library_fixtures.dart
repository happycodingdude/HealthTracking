import 'dart:convert';

import 'package:domain/domain.dart';

import '../src/library/library_file.dart';

/// Dữ liệu thư viện chuẩn cho test (06 Bản 2 §6.9.2), độc lập với file thật.

/// Mã bài của fixture: `<vùng>-<dụng cụ Bản 2>-<hậu tố>`, ví dụ
/// `chest-upper-free_weight-a` → `chest-upper-free-weight-a`. [e] là giá trị
/// [LegacyEquipment] (thư viện kiểu Bản 2).
String fixtureId(MuscleRegion r, String e, [String suffix = 'a']) =>
    '${r.id}-$e-$suffix'.replaceAll('_', '-');

Map<String, Object?> fixtureEntry(
  MuscleRegion r,
  String e, {
  String suffix = 'a',
  int? durationSeconds = 45,
  String? youtubeId,
  List<String>? steps,
}) {
  final id = fixtureId(r, e, suffix);
  return {
    'id': id,
    'muscleGroup': r.group.name,
    'muscleRegion': r.id,
    'equipment': e,
    'nameVi': 'Bài $e ${r.id} $suffix',
    'nameEn': 'Exercise $id',
    'video': {
      'youtubeId':
          youtubeId ??
          'fx${(r.index * 10 + _kinds.indexOf(e)).toString().padLeft(6, '0')}$suffix'
              .padRight(11, '0')
              .substring(0, 11),
      'channel': 'Kênh thử',
      'durationSeconds': durationSeconds,
    },
    'guide': {
      'steps': steps ?? ['Bước một', 'Bước hai', 'Bước ba'],
      'safety': ['Giữ lưng thẳng', 'Dừng khi đau'],
    },
    'approvedAt': '2026-10-11',
  };
}

const _kinds = [
  LegacyEquipment.machine,
  LegacyEquipment.freeWeight,
  LegacyEquipment.bodyweight,
];

/// `libraryMin`: thư viện kiểu Bản 2, 13 vùng × (1 máy + 1 tạ) + 3 bài bụng =
/// 29 bài, không có vùng chân.
Map<String, Object?> libraryMinJson({int libraryVersion = 1}) => {
  'libraryVersion': libraryVersion,
  'exercises': [
    for (final r in MuscleRegion.values)
      if (r.group == MuscleGroup.abs)
        fixtureEntry(r, LegacyEquipment.bodyweight)
      else if (r.group != MuscleGroup.legs) ...[
        fixtureEntry(r, LegacyEquipment.machine),
        fixtureEntry(r, LegacyEquipment.freeWeight),
      ],
  ],
};

LibraryFile libraryMin() => LibraryFile.parse(jsonEncode(libraryMinJson()));
