import '../exercise_note/exercise_note.dart';
import '../lift_log/lift_log.dart';
import '../lift_log/lift_window.dart';

/// Phần bên phải một dòng bài ở Buổi tập (04 Bản 3 S-63, F20-R42, FA3-09,
/// 06 Bản 3 ED3-11). Giao diện chỉ đổi trạng thái thành chữ, nút.
enum LiftRowState {
  /// Trong cửa sổ ghi tạ, chưa ghi hôm nay, có buổi trước: "BUỔI TRƯỚC" +
  /// con số xám; chạm → bảng ghi tạ điền sẵn.
  prev,

  /// Trong cửa sổ, đã ghi buổi này: con số đậm; chạm → sửa.
  today,

  /// Hôm nay chưa đến giờ hoặc buổi tương lai, bài có mức tạ gần nhất:
  /// "GẦN NHẤT" + con số xám.
  latest,

  /// Buổi đã qua (đã khóa), có bản ghi của buổi đó: con số chữ thường.
  past,

  /// Không có con số để hiện: trong cửa sổ → nút "Ghi"; chưa đến giờ, buổi
  /// tương lai → "Chưa ghi"; buổi đã qua → trống.
  none,

  /// Bài bụng trong cửa sổ: nút "Ghi chú" (UA3-08).
  absNote,

  /// Bài bụng ngoài cửa sổ: trống.
  absNone,

  /// Bài gỡ sau ra mắt có bản ghi trong buổi: con số + "Không còn trong thư
  /// viện" (UA2-18).
  removed,
}

/// Biểu tượng ghi chú sau tên bài (F20-R43): rõ = có ghi chú buổi này; mờ =
/// chỉ buổi trước (FA3-02) có.
enum NoteMark { none, previous, today }

abstract final class LiftRowRules {
  /// Trạng thái dòng của bài trong buổi có cửa sổ [window]: [sessionLog] =
  /// bản ghi của buổi này, [previous] = buổi trước của bài trước ngày của
  /// buổi (FA3-01; với buổi tương lai đó là mức gần nhất). Bài gỡ sau ra mắt
  /// chỉ có dòng khi buổi có bản ghi của nó.
  static LiftRowState of({
    required LiftWindow window,
    required bool logsWeight,
    required bool active,
    LiftLog? sessionLog,
    LiftLog? previous,
  }) {
    if (!logsWeight) {
      return window.isOpen ? LiftRowState.absNote : LiftRowState.absNone;
    }
    if (!active && sessionLog != null) return LiftRowState.removed;
    return switch (window) {
      LiftWindowOpen() when sessionLog != null => LiftRowState.today,
      LiftWindowOpen() when previous != null => LiftRowState.prev,
      LiftWindowOpen() => LiftRowState.none,
      LiftWindowNotOpen() when previous != null => LiftRowState.latest,
      LiftWindowNotOpen() => LiftRowState.none,
      LiftWindowClosed() when sessionLog != null => LiftRowState.past,
      LiftWindowClosed() => LiftRowState.none,
    };
  }

  /// Biểu tượng ghi chú: [sessionNote] của buổi này, [previousNote] theo
  /// FA3-02.
  static NoteMark noteMark({
    ExerciseNote? sessionNote,
    ExerciseNote? previousNote,
  }) => sessionNote != null
      ? NoteMark.today
      : previousNote != null
      ? NoteMark.previous
      : NoteMark.none;
}
