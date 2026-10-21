import 'package:domain/domain.dart';

import '../app/strings_vi.dart';

/// Định dạng kiểu Việt Nam (UR-10): `72,5 kg` · `2.210 kcal` · `07/10` ·
/// `18:00` · `50.000đ`.
abstract final class Fmt {
  /// Số nguyên có dấu chấm ngăn cách hàng nghìn: 2210 → `2.210`.
  static String integer(int value) {
    final negative = value < 0;
    final digits = value.abs().toString();
    final buf = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) buf.write('.');
      buf.write(digits[i]);
    }
    return negative ? '-$buf' : buf.toString();
  }

  /// Cân nặng lưu dạng ×10 (05 §6.7.1): 725 → `72,5 kg`, 800 → `80 kg`.
  static String kg(int weightKgX10) => '${kgNumber(weightKgX10)} kg';

  /// Chênh lệch cân nặng có mũi tên, màu trung tính (F07-R7, UA-15):
  /// -4 → `↓ 0,4 kg`, 8 → `↑ 0,8 kg`, 0 → `0 kg`.
  static String weightChange(int diffKgX10) => diffKgX10 == 0
      ? kg(0)
      : '${diffKgX10 < 0 ? '↓' : '↑'} ${kg(diffKgX10.abs())}';

  /// Phần số của cân nặng, dấu phẩy thập phân: 725 → `72,5`.
  static String kgNumber(int weightKgX10) {
    final whole = integer(weightKgX10 ~/ 10);
    final tenth = weightKgX10.abs() % 10;
    return tenth == 0 ? whole : '$whole,$tenth';
  }

  /// 2210 → `2.210 kcal`.
  static String kcal(int value) => '${integer(value)} kcal';

  /// 50000 → `50.000đ`.
  static String vnd(int value) => '${integer(value)}${S.currencySuffix}';

  /// `07/10`.
  static String dayMonth(LocalDate date) =>
      '${_two(date.day)}/${_two(date.month)}';

  /// `18:00`.
  static String time(LocalTime time) => time.toKey();

  /// `18:42` từ một thời điểm, theo giờ của thiết bị.
  static String clock(DateTime instant) {
    final local = instant.toLocal();
    return '${_two(local.hour)}:${_two(local.minute)}';
  }

  /// `Thứ 4` / `Chủ nhật`.
  static String weekday(LocalDate date) => S.weekdays[date.weekday - 1];

  /// `Thứ 4, 07/10` (04 §6.7).
  static String weekdayDate(LocalDate date) =>
      '${weekday(date)}, ${dayMonth(date)}';

  /// Tên nhóm cơ (PR-02).
  static String muscle(MuscleGroup m) => switch (m) {
    MuscleGroup.chest => S.muscleChest,
    MuscleGroup.triceps => S.muscleTriceps,
    MuscleGroup.shoulders => S.muscleShoulders,
    MuscleGroup.abs => S.muscleAbs,
    MuscleGroup.back => S.muscleBack,
    MuscleGroup.biceps => S.muscleBiceps,
    MuscleGroup.legs => S.muscleLegs,
  };

  /// Tên vùng cơ (03 Bản 2 §6.10).
  static String region(MuscleRegion r) => switch (r) {
    MuscleRegion.chestUpper => S.regionChestUpper,
    MuscleRegion.chestMid => S.regionChestMid,
    MuscleRegion.chestLower => S.regionChestLower,
    MuscleRegion.lats => S.regionLats,
    MuscleRegion.backMid => S.regionBackMid,
    MuscleRegion.backLower => S.regionBackLower,
    MuscleRegion.deltFront => S.regionDeltFront,
    MuscleRegion.deltSide => S.regionDeltSide,
    MuscleRegion.deltRear => S.regionDeltRear,
    MuscleRegion.biceps => S.regionBiceps,
    MuscleRegion.brachialisForearm => S.regionBrachialisForearm,
    MuscleRegion.tricepsLong => S.regionTricepsLong,
    MuscleRegion.tricepsLateralMedial => S.regionTricepsLateralMedial,
    MuscleRegion.absLower => S.regionAbsLower,
    MuscleRegion.absMid => S.regionAbsMid,
    MuscleRegion.obliques => S.regionObliques,
    MuscleRegion.quads => S.regionQuads,
    MuscleRegion.hamstrings => S.regionHamstrings,
    MuscleRegion.calves => S.regionCalves,
  };

  /// Độ dài video: 48 → `0:48`, 62 → `1:02`.
  static String videoDuration(int seconds) =>
      '${seconds ~/ 60}:${_two(seconds % 60)}';

  /// Nhiều nhóm cơ thành chữ (04 §6.13.4): `Ngực và tay sau`,
  /// `Ngực, vai và tay sau`. [capitalize] = false khi đứng giữa câu
  /// (`Hôm nay tập ngực và tay sau`, F04-R3).
  static String muscles(List<MuscleGroup> groups, {bool capitalize = true}) {
    final names = [
      for (final (i, m) in MuscleGroup.ordered(groups).indexed)
        i == 0 && capitalize ? muscle(m) : muscle(m).toLowerCase(),
    ];
    if (names.length <= 1) return names.join();
    return '${names.sublist(0, names.length - 1).join(', ')} ${S.and} ${names.last}';
  }

  /// Tiêu đề buổi tập (04 Bản 2 S-63): mỗi nhóm cơ viết hoa chữ đầu,
  /// `Ngực và Tay sau`, `Vai và Bụng`.
  static String musclesTitle(List<MuscleGroup> groups) {
    final names = [for (final m in MuscleGroup.ordered(groups)) muscle(m)];
    if (names.length <= 1) return names.join();
    return '${names.sublist(0, names.length - 1).join(', ')} ${S.and} ${names.last}';
  }

  /// Các vùng cơ của buổi (04 Bản 2 §6.6.1): `Ngực trên · Ngực giữa · Ngực
  /// dưới`.
  static String regions(List<MuscleGroup> groups) => [
    for (final g in MuscleGroup.ordered(groups))
      for (final r in MuscleRegion.of(g)) region(r),
  ].join(' · ');

  /// Đơn vị mức tạ sau con số (UA3-07): `kg`, `nấc`.
  static String liftUnit(LiftUnit unit) => switch (unit) {
    LiftUnit.kg => S.unitKg,
    LiftUnit.steps => S.unitSteps,
  };

  /// Tên đầy đủ của đơn vị (chi tiết bài, bộ chọn lần ghi đầu, UA3-07):
  /// `kg`, `nấc máy`.
  static String liftUnitFull(LiftUnit unit) => switch (unit) {
    LiftUnit.kg => S.unitKg,
    LiftUnit.steps => S.unitStepsFull,
  };

  /// Mức tạ của một bản ghi: `12 → 14 kg`, `72,5 → 75 kg`, `8 → 10 nấc`.
  static String lift(LiftLog l, LiftUnit unit) =>
      S.liftValue(kgNumber(l.startKgX10), kgNumber(l.endKgX10), liftUnit(unit));

  /// `T4 07/10` (S-20).
  static String shortWeekdayDate(LocalDate date) =>
      '${S.weekdaysShort[date.weekday - 1]} ${dayMonth(date)}';

  /// `05/10 – 11/10` (tiêu đề tuần ở S-20).
  static String weekRange(LocalDate start, LocalDate end) =>
      '${dayMonth(start)} – ${dayMonth(end)}';

  static String _two(int v) => v.toString().padLeft(2, '0');
}
