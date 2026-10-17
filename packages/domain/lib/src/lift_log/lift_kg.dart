/// Lỗi nhập mức tạ (F21-V1 → V4). Câu chữ nằm ở app.
enum LiftInputError {
  /// F21-V1: thiếu con số.
  missing,

  /// F21-V2: ngoài khoảng của đơn vị (0,5–300 kg; 1–30 thanh).
  outOfRange,

  /// F21-V3: lẻ bước (kg: không phải bội số của 0,5; thanh: có số lẻ).
  notStep,

  /// F21-V4: không phải số.
  notNumber,
}

/// Đơn vị mức tạ theo dụng cụ của bài (BR2-24, sửa 13/10/2026): bài với tạ
/// ghi kg, bài với máy (gồm máy kéo cáp) ghi số thanh tạ của máy. Cả hai lưu
/// × 10 như nhau (7 thanh → 70), nên bản ghi và đồng bộ không đổi.
enum LiftUnit {
  /// 0,5–300 kg, bước 0,5 (F21-R6, FA2-03); cao hơn buổi trước quá 10 kg
  /// thì cảnh báo (F21-R8).
  kg(min: 5, max: 3000, step: 5, maxRise: 100),

  /// 1–30 thanh, không có số lẻ; cao hơn buổi trước quá 3 thanh thì cảnh báo.
  plates(min: 10, max: 300, step: 10, maxRise: 30);

  const LiftUnit({
    required this.min,
    required this.max,
    required this.step,
    required this.maxRise,
  });

  /// Khoảng, bước và mức tăng tối đa không cảnh báo, đều × 10.
  final int min;
  final int max;
  final int step;
  final int maxRise;
}

/// Mức tạ lưu bằng số nguyên × 10 như cân nặng (05 Bản 2 §6.6.2): 72,5 kg →
/// 725, 7 thanh → 70. Khoảng và bước theo [LiftUnit] của bài.
abstract final class LiftKg {
  static final _number = RegExp(r'^(\d+)(?:[.,](\d+))?$');

  /// Đọc chữ Bạn gõ ("72,5" hoặc "72.5", F21-E9). Trả (giá trị × 10, lỗi):
  /// trống → [LiftInputError.missing]; không phải số →
  /// [LiftInputError.notNumber]; có hơn một chữ số thập phân khác 0 (ví dụ
  /// 72,25) → [LiftInputError.notStep]. Khoảng và bước kiểm ở [validate].
  static (int?, LiftInputError?) parse(String raw) {
    final text = raw.trim();
    if (text.isEmpty) return (null, LiftInputError.missing);
    final m = _number.firstMatch(text);
    if (m == null) return (null, LiftInputError.notNumber);
    final whole = int.tryParse(m.group(1)!);
    // Số quá dài: chắc chắn ngoài khoảng của mọi đơn vị.
    if (whole == null || whole > 100000) {
      return (null, LiftInputError.outOfRange);
    }
    final frac = m.group(2) ?? '';
    if (frac.length > 1 && frac.substring(1).replaceAll('0', '').isNotEmpty) {
      return (null, LiftInputError.notStep);
    }
    final tenth = frac.isEmpty ? 0 : int.parse(frac[0]);
    return (whole * 10 + tenth, null);
  }

  /// F21-V2, F21-V3 cho giá trị × 10 theo [unit].
  static LiftInputError? validate(int x10, LiftUnit unit) {
    if (x10 < unit.min || x10 > unit.max) return LiftInputError.outOfRange;
    if (x10 % unit.step != 0) return LiftInputError.notStep;
    return null;
  }

  /// [parse] rồi [validate]: (giá trị × 10, null) khi hợp lệ.
  static (int?, LiftInputError?) check(String raw, LiftUnit unit) {
    final (value, error) = parse(raw);
    if (error != null) return (null, error);
    final invalid = validate(value!, unit);
    return invalid == null ? (value, null) : (null, invalid);
  }

  /// Nút − / + (04 Bản 2 UA2-10): thêm [delta] bước của [unit] (0,5 kg; 1
  /// thanh), không vượt khoảng. Giá trị lẻ bước được làm tròn về bước gần
  /// nhất theo hướng bấm.
  static int stepped(int x10, int delta, LiftUnit unit) {
    final step = unit.step;
    var next = x10 + delta * step;
    if (x10 % step != 0) {
      next = delta > 0 ? (x10 ~/ step + 1) * step : (x10 ~/ step) * step;
    }
    return next.clamp(unit.min, unit.max);
  }

  /// "72,5" / "12" (dấu phẩy thập phân, không có số 0 thừa).
  static String format(int x10) {
    final whole = x10 ~/ 10;
    final tenth = x10 % 10;
    return tenth == 0 ? '$whole' : '$whole,$tenth';
  }
}

/// Kiểm tra hai ô của bảng ghi mức tạ (F21-V1 → V4): mỗi ô một lỗi, hoặc giá
/// trị × 10 khi hợp lệ. Thiếu một trong hai con số thì ô trống báo
/// [LiftInputError.missing] ("Vui lòng nhập cả mức tạ bắt đầu và kết thúc").
final class LiftInput {
  LiftInput._(this.startX10, this.endX10, this.startError, this.endError);

  factory LiftInput.of(String start, String end, LiftUnit unit) {
    final (s, se) = LiftKg.check(start, unit);
    final (e, ee) = LiftKg.check(end, unit);
    return LiftInput._(s, e, se, ee);
  }

  final int? startX10;
  final int? endX10;
  final LiftInputError? startError;
  final LiftInputError? endError;

  bool get isValid => startError == null && endError == null;
}

/// Hai ô của bảng ghi mức tạ chưa hợp lệ (F21-V1 → V4): chưa lưu gì.
final class LiftInputException implements Exception {
  const LiftInputException(this.input);

  final LiftInput input;

  @override
  String toString() =>
      'LiftInputException(${input.startError?.name}, ${input.endError?.name})';
}
