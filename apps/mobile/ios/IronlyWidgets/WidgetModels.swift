import Foundation

/// `widget_state.json` (05 Bản 3 §6.8.1): app tính sẵn, extension chỉ đọc và
/// vẽ (06 Bản 3 ED3-07). Tên thứ, nhóm cơ đã là tiếng Việt trong file.
struct WidgetStateFile: Decodable, Equatable {
  static let schemaVersion = 1

  let schema: Int
  let signedIn: Bool
  let hasSchedule: Bool
  let days: [WidgetDayFile]

  /// File thiếu, hỏng hoặc khác phiên bản → nil (vẽ "Mở app để đăng nhập").
  static func decode(_ data: Data?) -> WidgetStateFile? {
    guard let data,
          let file = try? JSONDecoder().decode(WidgetStateFile.self, from: data),
          file.schema == schemaVersion
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
  let week: WidgetWeekFile
}

struct WidgetWeekFile: Decodable, Equatable {
  let total: Int
  let done: Int
  let extra: Int
  let dots: [Bool]
}

/// Nội dung widget tại một thời điểm, theo bảng F-24 (`03` Bản 3 §6.10).
enum WidgetDisplay: Equatable {
  /// Chưa đăng nhập / đã đăng xuất / phiên hết hạn / file hỏng.
  case signedOut(weekday: String?)
  /// Chưa có lịch tập.
  case noSchedule(weekday: String)
  /// Có lịch: buổi theo lịch hoặc ngày nghỉ. [todayDot]: vị trí chấm của buổi
  /// hôm nay trong `week.dots` (viền cam khi chờ đánh dấu, 04 Bản 4 S-70);
  /// nil khi hôm nay không phải buổi theo lịch.
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
