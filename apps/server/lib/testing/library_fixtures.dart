import 'dart:convert';

import 'package:domain/domain.dart';

import '../src/library/library_file.dart';

/// Dữ liệu thư viện chuẩn cho test (06 Bản 2 §6.9.2), độc lập với file thật.

/// Mã bài của fixture: `<vùng>-<dụng cụ>-<hậu tố>`, ví dụ
/// `chest-upper-free_weight-a` → `chest-upper-free-weight-a`.
String fixtureId(MuscleRegion r, Equipment e, [String suffix = 'a']) =>
    '${r.id}-${e.wire}-$suffix'.replaceAll('_', '-');

Map<String, Object?> fixtureEntry(
  MuscleRegion r,
  Equipment e, {
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
    'equipment': e.wire,
    'nameVi': 'Bài ${e.wire} ${r.id} $suffix',
    'nameEn': 'Exercise $id',
    'video': {
      'youtubeId':
          youtubeId ??
          'fx${(r.index * 10 + e.index).toString().padLeft(6, '0')}$suffix'
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

/// `libraryMin`: 13 vùng × (1 máy + 1 tạ) + 3 bài bụng = 29 bài.
Map<String, Object?> libraryMinJson({int libraryVersion = 1}) => {
  'libraryVersion': libraryVersion,
  'exercises': [
    for (final r in MuscleRegion.values)
      if (r.group == MuscleGroup.abs)
        fixtureEntry(r, Equipment.bodyweight)
      else ...[
        fixtureEntry(r, Equipment.machine),
        fixtureEntry(r, Equipment.freeWeight),
      ],
  ],
};

LibraryFile libraryMin() => LibraryFile.parse(jsonEncode(libraryMinJson()));

/// `libraryMissingFree`: `libraryMin` thiếu bài tạ ở Ngực trên (TAC2-12).
LibraryFile libraryMissingFree() {
  final json = libraryMinJson();
  (json['exercises']! as List).removeWhere(
    (e) =>
        (e as Map)['id'] ==
        fixtureId(MuscleRegion.chestUpper, Equipment.freeWeight),
  );
  return LibraryFile.parse(jsonEncode(json));
}
