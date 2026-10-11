import '../schedule/weekly_template.dart';

/// Mặt của sơ đồ cơ thể (05 Bản 2 §6.10.4).
enum BodyView { front, back }

/// 16 vùng cơ của 6 nhóm (03 Bản 2 §6.10, 05 Bản 2 §6.10.4). Thứ tự khai báo
/// là thứ tự cố định F18-R9: nhóm ngực, lưng, vai, tay trước, tay sau, bụng;
/// trong nhóm theo bảng vùng. [id] trùng `id` của `<g>` trong 4 file SVG và
/// khóa của bảng `muscle_regions` trên server. Tên tiếng Việt nằm ở app.
enum MuscleRegion {
  chestUpper('chest_upper', MuscleGroup.chest, BodyView.front),
  chestMid('chest_mid', MuscleGroup.chest, BodyView.front),
  chestLower('chest_lower', MuscleGroup.chest, BodyView.front),
  lats('lats', MuscleGroup.back, BodyView.back),
  backMid('back_mid', MuscleGroup.back, BodyView.back),
  backLower('back_lower', MuscleGroup.back, BodyView.back),
  deltFront('delt_front', MuscleGroup.shoulders, BodyView.front),
  deltSide('delt_side', MuscleGroup.shoulders, BodyView.front),
  deltRear('delt_rear', MuscleGroup.shoulders, BodyView.back),
  biceps('biceps', MuscleGroup.biceps, BodyView.front),
  brachialisForearm('brachialis_forearm', MuscleGroup.biceps, BodyView.front),
  tricepsLong('triceps_long', MuscleGroup.triceps, BodyView.back),
  tricepsLateralMedial(
    'triceps_lateral_medial',
    MuscleGroup.triceps,
    BodyView.back,
  ),
  absLower('abs_lower', MuscleGroup.abs, BodyView.front),
  absMid('abs_mid', MuscleGroup.abs, BodyView.front),
  obliques('obliques', MuscleGroup.abs, BodyView.front);

  const MuscleRegion(this.id, this.group, this.view);

  final String id;
  final MuscleGroup group;
  final BodyView view;

  /// 1 → 16, khớp `muscle_regions.sort_order`.
  int get sortOrder => index + 1;

  static MuscleRegion? tryParse(String id) {
    for (final r in values) {
      if (r.id == id) return r;
    }
    return null;
  }

  /// Các vùng của nhóm [group], theo thứ tự F18-R9.
  static List<MuscleRegion> of(MuscleGroup group) => [
    for (final r in values)
      if (r.group == group) r,
  ];
}
