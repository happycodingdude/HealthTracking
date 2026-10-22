import 'lift_log.dart';

/// Lỗi nhập mức tạ (F21-V42 → V45). Câu chữ nằm ở app.
enum LiftInputError {
  /// F21-V42: thiếu con số.
  missing,

  /// F21-V43, V44: ngoài khoảng của đơn vị (0,5–300 kg; 1–50 nấc).
  outOfRange,

  /// F21-V43, V44: lẻ bước (kg: không phải bội số của 0,5; nấc: có số lẻ).
  notStep,

  /// F21-V45: không phải số.
  notNumber,

  /// F21-V41: lần ghi đầu chưa chọn đơn vị (FA3-03).
  unitMissing,
}

/// Đơn vị mức tạ của một bài (BR3-21, TD3-03): kg hoặc nấc máy (con số trên
/// khối tạ xếp chồng). Đơn vị là dữ liệu của Bạn theo từng bài (bảng
/// `exercise_units`), không thuộc thư viện. Cả hai lưu × 10 cùng cột như nhau
/// (TA3-05): 72,5 kg → 725, 8 nấc → 80. Giá trị trong API/PostgreSQL là
/// [wire].
enum LiftUnit {
  /// 0,5–300 kg, bước 0,5 (F21-R42); cao hơn buổi trước quá 10 kg thì cảnh
  /// báo (F21-R45).
  kg('kg', min: 5, max: 3000, step: 5, maxRise: 100),

  /// Nấc máy 1–50, số nguyên (F21-R42, A3-03); cao hơn buổi trước quá 4 nấc
  /// thì cảnh báo (A3-04).
  steps('steps', min: 10, max: 500, step: 10, maxRise: 40);

  const LiftUnit(
    this.wire, {
    required this.min,
    required this.max,
    required this.step,
    required this.maxRise,
  });

  final String wire;

  /// Chữ đơn vị sau con số (UA3-07): "kg", "nấc".
  String get label => switch (this) {
    LiftUnit.kg => 'kg',
    LiftUnit.steps => 'nấc',
  };

  /// Khoảng, bước và mức tăng tối đa không cảnh báo, đều × 10.
  final int min;
  final int max;
  final int step;
  final int maxRise;

  static LiftUnit? tryParse(String wire) {
    for (final u in values) {
      if (u.wire == wire) return u;
    }
    return null;
  }
}

/// Mức tạ lưu bằng số nguyên × 10 như cân nặng (05 Bản 2 §6.6.2): 72,5 kg →
/// 725, 8 nấc → 80. Khoảng và bước theo [LiftUnit] của bài.
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

  /// Khoảng và bước cho giá trị × 10 theo [unit].
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
  /// nấc), không vượt khoảng. Giá trị lẻ bước được làm tròn về bước gần
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

/// Kiểm tra hai ô của bảng ghi mức tạ (F21-V42 → V45): mỗi ô một lỗi, hoặc giá
/// trị × 10 khi hợp lệ. Thiếu một trong hai con số thì ô trống báo
/// [LiftInputError.missing] ("Vui lòng nhập cả mức tạ bắt đầu và kết thúc").
final class LiftInput {
  LiftInput._(
    this.startX10,
    this.endX10,
    this.startError,
    this.endError, {
    this.unitMissing = false,
  });

  /// [unit] = null: bài chưa có đơn vị và Bạn chưa chọn (F21-V41) — không
  /// kiểm hai con số vì chưa biết khoảng.
  factory LiftInput.of(String start, String end, LiftUnit? unit) {
    if (unit == null) {
      return LiftInput._(null, null, null, null, unitMissing: true);
    }
    final (s, se) = LiftKg.check(start, unit);
    final (e, ee) = LiftKg.check(end, unit);
    return LiftInput._(s, e, se, ee);
  }

  final int? startX10;
  final int? endX10;
  final LiftInputError? startError;
  final LiftInputError? endError;

  /// F21-V41: báo trước mọi lỗi của hai ô.
  final bool unitMissing;

  /// Lỗi hiện ra (thứ tự F21-V41 → V45): đơn vị, rồi ô Bắt đầu, rồi ô Kết
  /// thúc.
  LiftInputError? get error =>
      unitMissing ? LiftInputError.unitMissing : startError ?? endError;

  bool get isValid => error == null;
}

/// Hai ô của bảng ghi mức tạ chưa hợp lệ (F21-V42 → V45): chưa lưu gì.
final class LiftInputException implements Exception {
  const LiftInputException(this.input);

  final LiftInput input;

  @override
  String toString() =>
      'LiftInputException(${input.startError?.name}, ${input.endError?.name})';
}

/// Khoảng hợp lệ của mức tạ theo đơn vị (F21-R42), × 10: kg 5–3000 bước 5;
/// nấc 10–500 bước 10 (05 Bản 3 §6.4.3).
final class LiftRange {
  const LiftRange._(this.min, this.max, this.step);

  factory LiftRange.of(LiftUnit unit) =>
      LiftRange._(unit.min, unit.max, unit.step);

  final int min;
  final int max;
  final int step;

  /// Trong hai đầu khoảng (không xét bước).
  bool contains(int x10) => x10 >= min && x10 <= max;
}

/// Nút −bước / +bước (F21-R43, FA3-05, FA3-06): 2,5 kg; 1 nấc, × 10.
abstract final class LiftStep {
  static int of(LiftUnit unit) => switch (unit) {
    LiftUnit.kg => 25,
    LiftUnit.steps => 10,
  };

  /// Cộng ([delta] > 0) hoặc trừ đúng một bước vào số đang có, không làm
  /// tròn (12,5 → 15; 13 → 15,5). Ô trống ([x10] null) hoặc kết quả ra
  /// ngoài khoảng của [unit] → giữ nguyên (FA3-05, F21-E44, E45).
  static int? apply(int? x10, int delta, LiftUnit unit) {
    if (x10 == null || delta == 0) return x10;
    final next = x10 + delta.sign * of(unit);
    return LiftRange.of(unit).contains(next) ? next : x10;
  }
}

/// Số điền sẵn khi mở bảng ghi tạ (F21-R44, FA3-01): đã có bản ghi hôm nay
/// → bản ghi đó (sửa, F21-E46); không thì mức buổi trước ([fromPrevious]);
/// không có buổi trước → hai ô trống.
typedef LiftPrefillValue = ({int? startX10, int? endX10, bool fromPrevious});

abstract final class LiftPrefill {
  static LiftPrefillValue of({LiftLog? today, LiftLog? previous}) {
    if (today != null) {
      return (
        startX10: today.startKgX10,
        endX10: today.endKgX10,
        fromPrevious: false,
      );
    }
    return (
      startX10: previous?.startKgX10,
      endX10: previous?.endKgX10,
      fromPrevious: previous != null,
    );
  }
}

/// "{a} → {b} {đơn vị}" dùng chung cho app (S-63, S-64, S-67, S-68, S-69) và
/// nội dung thẻ màn hình khóa (ED3-03): "40 → 47,5 kg", "8 → 10 nấc".
abstract final class LiftFormat {
  static String range(int startX10, int endX10, LiftUnit unit) =>
      '${LiftKg.format(startX10)} → ${LiftKg.format(endX10)} ${unit.label}';

  /// "47,5 kg", "10 nấc".
  static String value(int x10, LiftUnit unit) =>
      '${LiftKg.format(x10)} ${unit.label}';
}
