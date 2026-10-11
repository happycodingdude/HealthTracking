/// Lỗi nhập mức tạ (F21-V1 → V4). Câu chữ nằm ở app.
enum LiftInputError {
  /// F21-V1: thiếu con số.
  missing,

  /// F21-V2: ngoài 0,5–300 kg.
  outOfRange,

  /// F21-V3: không phải bội số của 0,5.
  notStep,

  /// F21-V4: không phải số.
  notNumber,
}

/// Mức tạ lưu bằng số nguyên × 10 như cân nặng (05 Bản 2 §6.6.2): 72,5 kg →
/// 725. Bước 0,5 kg = 5 (F21-R6, FA2-03).
abstract final class LiftKg {
  /// 0,5 kg.
  static const min = 5;

  /// 300 kg.
  static const max = 3000;

  /// 0,5 kg.
  static const step = 5;

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
    // Số quá dài: chắc chắn ngoài 0,5–300 kg.
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

  /// F21-V2, F21-V3 cho giá trị × 10.
  static LiftInputError? validate(int x10) {
    if (x10 < min || x10 > max) return LiftInputError.outOfRange;
    if (x10 % step != 0) return LiftInputError.notStep;
    return null;
  }

  /// [parse] rồi [validate]: (giá trị × 10, null) khi hợp lệ.
  static (int?, LiftInputError?) check(String raw) {
    final (value, error) = parse(raw);
    if (error != null) return (null, error);
    final invalid = validate(value!);
    return invalid == null ? (value, null) : (null, invalid);
  }

  /// Nút − / + (04 Bản 2 UA2-10): thêm [delta] bước, không vượt 0,5–300 kg.
  /// Giá trị lẻ bước được làm tròn về bước gần nhất theo hướng bấm.
  static int stepped(int x10, int delta) {
    var next = x10 + delta * step;
    if (x10 % step != 0) {
      next = delta > 0 ? (x10 ~/ step + 1) * step : (x10 ~/ step) * step;
    }
    return next.clamp(min, max);
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

  factory LiftInput.of(String start, String end) {
    final (s, se) = LiftKg.check(start);
    final (e, ee) = LiftKg.check(end);
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
