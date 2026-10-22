import 'dart:convert';

import 'package:domain/domain.dart';

import '../src/library/library_file.dart';

/// Dữ liệu thư viện chuẩn cho test (06 Bản 3 §6.11.2): `library28` = cấu trúc
/// của `data/v3__exercises.json` với đúng 28 `id` thật theo thứ tự thư viện
/// (03 Bản 3 §6.12), nội dung giả (tên, video, hướng dẫn).
const library28Ids = <(String, MuscleRegion)>[
  ('chest-mid-machine-pec-deck', MuscleRegion.chestMid),
  ('chest-mid-free-weight-flat-barbell-bench-press', MuscleRegion.chestMid),
  ('chest-upper-machine-incline-machine-chest-press', MuscleRegion.chestUpper),
  ('chest-chest-lower-decline-plate-loaded-press', MuscleRegion.chestLower),
  ('back-back-mid-standing-cable-row-bar', MuscleRegion.backMid),
  ('lats-machine-lat-pulldown', MuscleRegion.lats),
  ('back-mid-machine-seated-cable-row', MuscleRegion.backMid),
  ('back-back-mid-plate-loaded-row-machine', MuscleRegion.backMid),
  ('delt-front-machine-machine-shoulder-press', MuscleRegion.deltFront),
  (
    'delt-front-free-weight-seated-dumbbell-shoulder-press',
    MuscleRegion.deltFront,
  ),
  ('shoulders-delt-side-plate-loaded-lateral-raise', MuscleRegion.deltSide),
  ('delt-side-machine-cable-lateral-raise', MuscleRegion.deltSide),
  ('shoulders-delt-rear-cable-face-pull', MuscleRegion.deltRear),
  ('delt-rear-machine-reverse-pec-deck', MuscleRegion.deltRear),
  ('biceps-biceps-incline-dumbbell-curl', MuscleRegion.biceps),
  ('biceps-biceps-cable-bar-curl', MuscleRegion.biceps),
  ('biceps-machine-machine-preacher-curl', MuscleRegion.biceps),
  (
    'triceps-triceps-lateral-medial-single-arm-cable-pushdown',
    MuscleRegion.tricepsLateralMedial,
  ),
  (
    'triceps-lateral-medial-machine-cable-triceps-pushdown',
    MuscleRegion.tricepsLateralMedial,
  ),
  (
    'triceps-long-free-weight-overhead-dumbbell-triceps-extension',
    MuscleRegion.tricepsLong,
  ),
  ('abs-lower-bodyweight-hanging-leg-raise', MuscleRegion.absLower),
  ('abs-mid-bodyweight-forearm-plank', MuscleRegion.absMid),
  ('obliques-bodyweight-side-plank', MuscleRegion.obliques),
  ('legs-quads-leg-press', MuscleRegion.quads),
  ('legs-quads-seated-leg-extension', MuscleRegion.quads),
  ('legs-hamstrings-lying-leg-curl', MuscleRegion.hamstrings),
  ('legs-hamstrings-barbell-romanian-deadlift', MuscleRegion.hamstrings),
  ('legs-calves-standing-calf-raise-machine', MuscleRegion.calves),
];

/// Mã video giả, ổn định theo [id] (11 ký tự).
String fixtureVideoId(String id) {
  var h = 0;
  for (final c in id.codeUnits) {
    h = (h * 31 + c) % 1000000000;
  }
  return 'fx${h.toString().padLeft(9, '0')}';
}

/// Một bài của fixture, đúng lược đồ file thư viện Bản 3 (không `equipment`).
Map<String, Object?> fixtureEntry(
  String id,
  MuscleRegion r, {
  int? durationSeconds = 45,
  String? youtubeId,
  List<String>? steps,
}) => {
  'id': id,
  'muscleGroup': r.group.name,
  'muscleRegion': r.id,
  'nameVi': 'Bài $id',
  'nameEn': 'Exercise $id',
  'video': {
    'youtubeId': youtubeId ?? fixtureVideoId(id),
    'channel': 'Kênh thử',
    'durationSeconds': durationSeconds,
  },
  'guide': {
    'steps': steps ?? ['Bước một', 'Bước hai', 'Bước ba'],
    'safety': ['Giữ lưng thẳng', 'Dừng khi đau'],
  },
  'approvedAt': '2026-10-21',
};

/// `library28`: 28 bài theo thứ tự thư viện, `libraryVersion` 2.
Map<String, Object?> library28Json({int libraryVersion = 2}) => {
  'libraryVersion': libraryVersion,
  'exercises': [for (final (id, r) in library28Ids) fixtureEntry(id, r)],
};

LibraryFile library28() => LibraryFile.parse(jsonEncode(library28Json()));

/// Biến thể bị từ chối (TAC3-04). `library28MissingKept`: bài giữ
/// `chest-mid-machine-pec-deck` bị thay bằng một bài mới cùng vùng (vẫn 28).
Map<String, Object?> library28MissingKeptJson() {
  final json = library28Json();
  (json['exercises']! as List)[0] = fixtureEntry(
    'chest-mid-machine-new-press',
    MuscleRegion.chestMid,
  );
  return json;
}

/// `library27`: thiếu bài chân cuối.
Map<String, Object?> library27Json() {
  final json = library28Json();
  (json['exercises']! as List).removeLast();
  return json;
}

/// `library28WithRemoved`: một bài thay bằng `id` của bài bỏ.
Map<String, Object?> library28WithRemovedJson() {
  final json = library28Json();
  (json['exercises']! as List)[3] = fixtureEntry(
    'chest-lower-free-weight-decline-barbell-bench-press',
    MuscleRegion.chestLower,
  );
  return json;
}

/// `library28WithEquipment`: còn trường `equipment` của Bản 2.
Map<String, Object?> library28WithEquipmentJson() {
  final json = library28Json();
  ((json['exercises']! as List).first as Map)['equipment'] = 'machine';
  return json;
}
