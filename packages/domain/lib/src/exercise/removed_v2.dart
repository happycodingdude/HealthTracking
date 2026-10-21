/// Danh sách bài giữ / bỏ khi lên Bản 3 (03 Bản 3 §6.12, Bạn duyệt
/// 20/10/2026), theo `id` trong `data/v2__exercises.json`. Danh sách bài bỏ
/// có bản sao trong `apps/server/lib/src/library/purge.dart`; test đối chiếu
/// hai bản với nhau và với file Bản 2 (ED3-04).
abstract final class LibraryV3 {
  /// 14 bài Bản 2 bị bỏ: xóa hẳn cùng mức tạ, biểu đồ, ghi chú một lần khi
  /// phát hành Bản 3 (FR3-04, TR3-09).
  static const removedV2Ids = {
    'chest-upper-free-weight-incline-dumbbell-press',
    'chest-lower-machine-high-to-low-cable-crossover',
    'chest-lower-free-weight-decline-barbell-bench-press',
    'lats-free-weight-one-arm-dumbbell-row',
    'back-mid-free-weight-barbell-bent-over-row',
    'back-lower-machine-back-extension-machine',
    'back-lower-free-weight-romanian-deadlift',
    'delt-side-free-weight-dumbbell-lateral-raise',
    'delt-rear-free-weight-bent-over-dumbbell-rear-delt-raise',
    'biceps-free-weight-dumbbell-biceps-curl',
    'brachialis-forearm-machine-cable-rope-hammer-curl',
    'brachialis-forearm-free-weight-dumbbell-hammer-curl',
    'triceps-long-machine-overhead-cable-triceps-extension',
    'triceps-lateral-medial-free-weight-close-grip-bench-press',
  };

  /// 15 bài Bản 2 được giữ: dùng lại `id` để giữ lịch sử mức tạ (TR3-08,
  /// LIB-R22). `library import` từ chối file thiếu bất kỳ `id` nào ở đây
  /// (ED3-05).
  static const keptV2Ids = {
    'chest-mid-machine-pec-deck',
    'chest-mid-free-weight-flat-barbell-bench-press',
    'chest-upper-machine-incline-machine-chest-press',
    'lats-machine-lat-pulldown',
    'back-mid-machine-seated-cable-row',
    'delt-front-machine-machine-shoulder-press',
    'delt-front-free-weight-seated-dumbbell-shoulder-press',
    'delt-side-machine-cable-lateral-raise',
    'delt-rear-machine-reverse-pec-deck',
    'biceps-machine-machine-preacher-curl',
    'triceps-lateral-medial-machine-cable-triceps-pushdown',
    'triceps-long-free-weight-overhead-dumbbell-triceps-extension',
    'abs-lower-bodyweight-hanging-leg-raise',
    'abs-mid-bodyweight-forearm-plank',
    'obliques-bodyweight-side-plank',
  };
}
