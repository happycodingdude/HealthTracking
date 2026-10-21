import '../schedule/weekly_template.dart';

/// Mặt của sơ đồ cơ thể (05 Bản 2 §6.10.4).
enum BodyView { front, back }

/// 19 vùng cơ của 7 nhóm (03 Bản 3 §6.1, 05 Bản 3 §6.10.3): 16 vùng Bản 2
/// theo thứ tự nhóm ngực, lưng, vai, tay trước, tay sau, bụng, rồi 3 vùng chân
/// (TD3-19). [id] trùng `id` của `<g>` trong 4 file SVG và khóa của bảng
/// `muscle_regions` trên server. Tên tiếng Việt nằm ở app. Vùng có thể không
/// có bài (A3-01); vùng chỉ là nhãn của bài, không còn là cấp trong danh sách
/// (PD3-01).
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
  obliques('obliques', MuscleGroup.abs, BodyView.front),
  quads('quads', MuscleGroup.legs, BodyView.front),
  hamstrings('hamstrings', MuscleGroup.legs, BodyView.back),
  calves('calves', MuscleGroup.legs, BodyView.back);

  const MuscleRegion(this.id, this.group, this.view);

  final String id;
  final MuscleGroup group;
  final BodyView view;

  /// 1 → 19, khớp `muscle_regions.sort_order`.
  int get sortOrder => index + 1;

  static MuscleRegion? tryParse(String id) {
    for (final r in values) {
      if (r.id == id) return r;
    }
    return null;
  }

  /// Các vùng của nhóm [group], theo thứ tự khai báo.
  static List<MuscleRegion> of(MuscleGroup group) => [
    for (final r in values)
      if (r.group == group) r,
  ];
}
