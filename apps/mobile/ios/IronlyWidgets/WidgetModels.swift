import Foundation

/// `widget_state.json` (05 Bản 3 §6.8.1, Bản 5 §6.8): app tính sẵn, extension
/// chỉ đọc và vẽ (06 Bản 3 ED3-07). Tên thứ, nhóm cơ đã là tiếng Việt trong
/// file. Đọc schema 1 (Bản 3, 4: chấm `true` / `false`, không tạm dừng) và
/// schema 2 (Bản 5 TD5-16: `paused`, chấm là chuỗi).
struct WidgetStateFile: Decodable, Equatable {
  static let schemaVersions = 1...2

  let schema: Int
  let signedIn: Bool
  let hasSchedule: Bool
  let days: [WidgetDayFile]

  /// File thiếu, hỏng hoặc phiên bản lạ → nil (vẽ "Mở app để đăng nhập").
  static func decode(_ data: Data?) -> WidgetStateFile? {
    guard let data,
          let file = try? JSONDecoder().decode(WidgetStateFile.self, from: data),
          schemaVersions.contains(file.schema)
    else { return nil }
    return file
  }
}

struct WidgetDayFile: Decodable, Equatable {
  let date: String
  let weekday: String
  let kind: String
  let groups: [String]
  let time: String?
  let mark: String?
  let extra: Bool
  /// Ngày trong khoảng tạm dừng (schema 2); schema 1 → false.
  let paused: Bool
  let week: WidgetWeekFile

  init(
    date: String, weekday: String, kind: String, groups: [String], time: String?,
    mark: String?, extra: Bool, paused: Bool = false, week: WidgetWeekFile
  ) {
    self.date = date
    self.weekday = weekday
    self.kind = kind
    self.groups = groups
    self.time = time
    self.mark = mark
    self.extra = extra
    self.paused = paused
    self.week = week
  }

  private enum CodingKeys: String, CodingKey {
    case date, weekday, kind, groups, time, mark, extra, paused, week
  }

  init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    date = try c.decode(String.self, forKey: .date)
    weekday = try c.decode(String.self, forKey: .weekday)
    kind = try c.decode(String.self, forKey: .kind)
    groups = try c.decode([String].self, forKey: .groups)
    time = try c.decodeIfPresent(String.self, forKey: .time)
    mark = try c.decodeIfPresent(String.self, forKey: .mark)
    extra = try c.decode(Bool.self, forKey: .extra)
    paused = try c.decodeIfPresent(Bool.self, forKey: .paused) ?? false
    week = try c.decode(WidgetWeekFile.self, forKey: .week)
  }
}

/// Chấm tiến độ một buổi theo lịch (05 Bản 5 TD5-16).
enum WidgetDot: String, Equatable {
  case done, pending, paused, today
}

struct WidgetWeekFile: Decodable, Equatable {
  let total: Int
  let done: Int
  let extra: Int
  let dots: [WidgetDot]
  /// File ghi thẳng chấm "hôm nay" (schema 2); schema 1 phải suy vị trí.
  let marksToday: Bool

  init(total: Int, done: Int, extra: Int, dots: [WidgetDot], marksToday: Bool = true) {
    self.total = total
    self.done = done
    self.extra = extra
    self.dots = dots
    self.marksToday = marksToday
  }

  private enum CodingKeys: String, CodingKey {
    case total, done, extra, dots
  }

  init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    total = try c.decode(Int.self, forKey: .total)
    done = try c.decode(Int.self, forKey: .done)
    extra = try c.decode(Int.self, forKey: .extra)
    if let bools = try? c.decode([Bool].self, forKey: .dots) {
      // Schema 1 (Bản 3, 4): true = đã tập.
      dots = bools.map { $0 ? .done : .pending }
      marksToday = false
    } else {
      // Schema 2: giá trị lạ (bản sau) vẽ như chấm còn lại.
      dots = try c.decode([String].self, forKey: .dots).map { WidgetDot(rawValue: $0) ?? .pending }
      marksToday = true
    }
  }
}

/// Nội dung widget tại một thời điểm, theo bảng F-24 (`03` Bản 3 §6.10).
enum WidgetDisplay: Equatable {
  /// Chưa đăng nhập / đã đăng xuất / phiên hết hạn / file hỏng.
  case signedOut(weekday: String?)
  /// Chưa có lịch tập.
  case noSchedule(weekday: String)
  /// Có lịch: buổi theo lịch hoặc ngày nghỉ. [todayDot]: vị trí chấm của buổi
  /// hôm nay trong `week.dots` (viền cam khi chờ đánh dấu, 04 Bản 4 S-70);
  /// nil khi hôm nay không phải buổi theo lịch hoặc đang tạm dừng.
  case day(WidgetDayFile, todayDot: Int?)

  var weekday: String? {
    switch self {
    case .signedOut(let weekday): return weekday
    case .noSchedule(let weekday): return weekday
    case .day(let day, _): return day.weekday
    }
  }

  /// URL khi chạm (05 Bản 3 TD3-16, 04 Bản 3 NAV-15): một URL cho cả widget.
  var url: URL {
    switch self {
    case .signedOut: return URL(string: "ironly://login")!
    case .noSchedule: return URL(string: "ironly://today")!
    case .day(let day, _):
      return URL(string: day.kind == "workout" || day.extra
        ? "ironly://session/today" : "ironly://today")!
    }
  }
}
