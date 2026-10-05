import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../time/local_time.dart';

/// 6 nhóm cơ, thứ tự cố định PR-02: Ngực · Tay sau · Vai · Bụng · Lưng · Tay
/// trước. Giá trị trong API/PostgreSQL là [name] (05 §6.7.1).
enum MuscleGroup {
  chest,
  triceps,
  shoulders,
  abs,
  back,
  biceps;

  /// Sắp theo thứ tự PR-02, bỏ trùng.
  static List<MuscleGroup> ordered(Iterable<MuscleGroup> muscles) {
    final set = muscles.toSet();
    return [
      for (final m in values)
        if (set.contains(m)) m,
    ];
  }

  static MuscleGroup? tryParse(String value) {
    for (final m in values) {
      if (m.name == value) return m;
    }
    return null;
  }
}

/// Một thứ trong lịch tuần (F-03): có tập không, giờ tập, nhóm cơ.
final class TemplateDay {
  const TemplateDay({
    required this.enabled,
    this.time,
    this.muscles = const [],
  });

  static const off = TemplateDay(enabled: false);

  final bool enabled;
  final LocalTime? time;

  /// Theo thứ tự PR-02.
  final List<MuscleGroup> muscles;

  @override
  bool operator ==(Object other) =>
      other is TemplateDay &&
      other.enabled == enabled &&
      other.time == time &&
      _sameList(other.muscles, muscles);

  @override
  int get hashCode => Object.hash(enabled, time, Object.hashAll(muscles));
}

bool _sameList<T>(List<T> a, List<T> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

/// Lỗi của lịch tuần (F03-V1 → V3).
enum TemplateIssue {
  /// F03-V1: lịch tuần cần ít nhất 1 ngày.
  noWorkoutDay,

  /// F03-V2: thứ có tập chưa có giờ.
  missingTime,

  /// F03-V3: thứ có tập chưa có nhóm cơ.
  missingMuscles,
}

/// Một lỗi; [weekday] = null với F03-V1.
typedef TemplateError = ({TemplateIssue issue, int? weekday});

/// Lịch tuần (F-03): thứ 2 → thứ 7; không có chủ nhật (F03-R1). Khóa là
/// [DateTime.weekday] 1 → 6.
final class WeeklyTemplate {
  WeeklyTemplate(Map<int, TemplateDay> days)
    : days = Map.unmodifiable({
        for (var w = DateTime.monday; w <= DateTime.saturday; w++)
          w: days[w] ?? TemplateDay.off,
      }) {
    if (days.keys.any((w) => w < DateTime.monday || w > DateTime.saturday)) {
      throw ArgumentError.value(days.keys, 'days', 'chỉ thứ 2 → thứ 7');
    }
  }

  /// Luôn đủ 6 khóa 1 → 6.
  final Map<int, TemplateDay> days;

  TemplateDay day(int weekday) => days[weekday] ?? TemplateDay.off;

  /// F03-V1 → V3, theo thứ tự thứ 2 → thứ 7. Rỗng = hợp lệ.
  List<TemplateError> validate() {
    final errors = <TemplateError>[];
    var any = false;
    for (final MapEntry(key: weekday, value: d) in days.entries) {
      if (!d.enabled) continue;
      any = true;
      if (d.time == null) {
        errors.add((issue: TemplateIssue.missingTime, weekday: weekday));
      }
      if (d.muscles.isEmpty) {
        errors.add((issue: TemplateIssue.missingMuscles, weekday: weekday));
      }
    }
    if (!any) {
      errors.insert(0, (issue: TemplateIssue.noWorkoutDay, weekday: null));
    }
    return errors;
  }

  /// JSON chuẩn hóa (05 §6.7.3): khóa "1" → "6" theo thứ tự, thứ không tập
  /// chỉ có `enabled: false`, nhóm cơ theo thứ tự PR-02.
  Map<String, Object?> toJson() => {
    for (final MapEntry(key: weekday, value: d) in days.entries)
      '$weekday': d.enabled
          ? {
              'enabled': true,
              'time': d.time?.toKey(),
              'muscles': [
                for (final m in MuscleGroup.ordered(d.muscles)) m.name,
              ],
            }
          : {'enabled': false},
  };

  /// Đọc JSON của [toJson]. Ném [FormatException] nếu sai cấu trúc.
  factory WeeklyTemplate.fromJson(Map<String, Object?> json) {
    final days = <int, TemplateDay>{};
    for (final MapEntry(:key, :value) in json.entries) {
      final weekday = int.tryParse(key);
      if (weekday == null ||
          weekday < DateTime.monday ||
          weekday > DateTime.saturday ||
          value is! Map) {
        throw FormatException('Thứ không hợp lệ', key);
      }
      final enabled = value['enabled'];
      if (enabled is! bool) throw FormatException('enabled', key);
      if (!enabled) {
        days[weekday] = TemplateDay.off;
        continue;
      }
      final time = value['time'];
      final muscles = value['muscles'];
      if ((time != null && time is! String) || muscles is! List) {
        throw FormatException('time/muscles', key);
      }
      final parsed = <MuscleGroup>[];
      for (final m in muscles) {
        final g = m is String ? MuscleGroup.tryParse(m) : null;
        if (g == null) throw FormatException('muscles', key);
        parsed.add(g);
      }
      days[weekday] = TemplateDay(
        enabled: true,
        time: time == null ? null : LocalTime.parse(time as String),
        muscles: MuscleGroup.ordered(parsed),
      );
    }
    return WeeklyTemplate(days);
  }

  /// SHA-256 (hex) của JSON chuẩn hóa. App và server tính giống hệt nhau;
  /// dùng cho banner "Lịch tuần đã thay đổi" (F03-R7).
  String get contentHash =>
      sha256.convert(utf8.encode(jsonEncode(toJson()))).toString();

  @override
  bool operator ==(Object other) =>
      other is WeeklyTemplate && other.contentHash == contentHash;

  @override
  int get hashCode => contentHash.hashCode;
}
