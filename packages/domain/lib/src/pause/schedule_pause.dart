import '../time/local_date.dart';

/// Một khoảng tạm dừng lịch tập (entity `schedule_pause`, key `id`, 05 Bản 5
/// TD5-05): từ [startDate] đến [endDate] (cả hai đầu). Kết thúc sớm =
/// [endedOn] là hôm qua; kết thúc vào ngày bắt đầu (chưa qua ngày nào) = xóa
/// khoảng (tombstone, F31-R8). Trạng thái "Tạm dừng" của buổi tính lúc đọc,
/// không ghi vào `days` (FC5-09).
final class SchedulePause {
  const SchedulePause({
    required this.id,
    required this.startDate,
    required this.endDate,
    this.endedOn,
  });

  /// UUID app sinh.
  final String id;
  final LocalDate startDate;
  final LocalDate endDate;

  /// Ngày cuối thực sự tạm dừng khi kết thúc sớm (hôm qua lúc bấm "Kết thúc").
  final LocalDate? endedOn;

  /// Ngày cuối còn tạm dừng: [endedOn] nếu sớm hơn [endDate].
  LocalDate get lastDay {
    final e = endedOn;
    return e != null && e.isBefore(endDate) ? e : endDate;
  }

  /// Khoảng không còn ngày nào (kết thúc sớm vào ngày bắt đầu).
  bool get isEmpty => lastDay.isBefore(startDate);

  /// [date] nằm trong khoảng tạm dừng.
  bool covers(LocalDate date) =>
      !date.isBefore(startDate) && !date.isAfter(lastDay);

  /// Còn hiệu lực lúc [today]: đang tạm dừng hoặc đặt trước (F31-R1).
  bool activeOn(LocalDate today) => !isEmpty && !lastDay.isBefore(today);

  /// Trường sai về cấu trúc (05 Bản 5 §6.6.2); null = hợp lệ.
  String? get invalidField {
    if (endDate.isBefore(startDate)) return 'endDate';
    final e = endedOn;
    if (e != null &&
        (e.isBefore(startDate.addDays(-1)) || e.isAfter(endDate))) {
      return 'endedOn';
    }
    return null;
  }

  @override
  bool operator ==(Object other) =>
      other is SchedulePause &&
      other.id == id &&
      other.startDate == startDate &&
      other.endDate == endDate &&
      other.endedOn == endedOn;

  @override
  int get hashCode => Object.hash(id, startDate, endDate, endedOn);

  @override
  String toString() =>
      'SchedulePause($id, $startDate → $endDate'
      '${endedOn == null ? '' : ', kết thúc $endedOn'})';
}

/// Lý do không ghi được một khoảng tạm dừng (F31-R1, R2, R9, V1 → V3).
enum PauseError {
  /// F31-V1: ngày bắt đầu đã qua.
  startInPast,

  /// F31-V2: ngày kết thúc trước ngày bắt đầu.
  endBeforeStart,

  /// F31-V3: sửa ngày kết thúc thành ngày đã qua.
  endInPast,

  /// Ngày kết thúc sớm ngoài [startDate − 1, endDate].
  endedOnOutOfRange,

  /// F31-R1: đã có khoảng khác còn hiệu lực (`pause_overlap`).
  overlap,
}

/// Quy tắc khoảng tạm dừng (F-31). App và server cùng dùng (AP-4).
abstract final class PauseRules {
  /// Kiểm tra ghi [after] (bản trên máy / server trước đó: [before]) khi các
  /// khoảng khác còn đó là [others], hôm nay là [today] (giờ iPhone).
  static PauseError? check({
    required SchedulePause? before,
    required SchedulePause after,
    required Iterable<SchedulePause> others,
    required LocalDate today,
  }) {
    if (after.endDate.isBefore(after.startDate)) {
      return PauseError.endBeforeStart;
    }
    if (after.invalidField == 'endedOn') return PauseError.endedOnOutOfRange;
    if ((before == null || before.startDate != after.startDate) &&
        after.startDate.isBefore(today)) {
      return PauseError.startInPast;
    }
    if (before != null &&
        before.endDate != after.endDate &&
        after.endDate.isBefore(today)) {
      return PauseError.endInPast;
    }
    if (after.activeOn(today) &&
        others.any((o) => o.id != after.id && o.activeOn(today))) {
      return PauseError.overlap;
    }
    return null;
  }
}
