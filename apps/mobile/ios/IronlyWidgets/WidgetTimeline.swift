import Foundation

/// Chọn nội dung theo ngày trong file (không tính lịch, tuần, đơn vị: app đã
/// tính sẵn 8 ngày, 05 Bản 3 TD3-15).
enum WidgetTimeline {
  /// Nội dung lúc [date]: mục có `date` trùng ngày theo giờ iPhone. Không có
  /// mục (app chưa mở hơn 8 ngày) → như file hỏng.
  static func display(_ file: WidgetStateFile?, at date: Date, calendar: Calendar = .current)
    -> WidgetDisplay
  {
    guard let file else { return .signedOut(weekday: nil) }
    let key = dayKey(date, calendar: calendar)
    let day = file.days.first { $0.date == key }
    if !file.signedIn { return .signedOut(weekday: day?.weekday) }
    guard let day else { return .signedOut(weekday: nil) }
    if !file.hasSchedule { return .noSchedule(weekday: day.weekday) }
    return .day(day)
  }

  /// Mục "bây giờ" và mục 00:00 cho mỗi ngày sau hôm nay trong file
  /// (TimelineProvider, policy `.atEnd`).
  static func entries(_ file: WidgetStateFile?, now: Date, calendar: Calendar = .current)
    -> [(date: Date, display: WidgetDisplay)]
  {
    var result = [(date: now, display: display(file, at: now, calendar: calendar))]
    for day in file?.days ?? [] {
      guard let start = dayStart(day.date, calendar: calendar), start > now else { continue }
      result.append((date: start, display: display(file, at: start, calendar: calendar)))
    }
    return result
  }

  static func dayKey(_ date: Date, calendar: Calendar) -> String {
    let c = calendar.dateComponents([.year, .month, .day], from: date)
    return String(format: "%04d-%02d-%02d", c.year!, c.month!, c.day!)
  }

  static func dayStart(_ key: String, calendar: Calendar) -> Date? {
    let parts = key.split(separator: "-").compactMap { Int($0) }
    guard parts.count == 3 else { return nil }
    return calendar.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2]))
  }
}
