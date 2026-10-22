import SwiftUI

/// S-70 cỡ vừa, hai cột (04 Bản 3 §6.7, UA3-14, UD3-03 = A). Câu chữ theo
/// `03` Bản 3 §6.13 (trùng `strings_vi.dart`, có test đối chiếu).
struct WidgetContentView: View {
  let display: WidgetDisplay

  @Environment(\.dynamicTypeSize) private var typeSize
  @ScaledMetric(relativeTo: .title) private var titleSize: CGFloat = 26

  var body: some View {
    content
      // Widget cỡ vừa có chỗ cố định: chữ lớn tới mức xxxLarge, lớn hơn thì
      // giữ ở mức này để không cắt chữ (04 Bản 3 §6.7).
      .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
  }

  private var content: some View {
    HStack(alignment: .top, spacing: 12) {
      VStack(alignment: .leading, spacing: 2) {
        Text(display.weekday.map { "Ironly · \($0)" } ?? "Ironly")
          .font(.caption)
          .foregroundStyle(.secondary)
        Text(title)
          .font(.system(size: titleSize, weight: .bold))
          .lineLimit(2)
          .minimumScaleFactor(0.6)
          .fixedSize(horizontal: false, vertical: true)
        if let status {
          Text(status)
            .font(.subheadline)
            .lineLimit(2)
        }
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      if let week {
        WeekColumn(week: week, dot: typeSize >= .xxLarge ? 12 : 16)
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
  }

  private var title: String {
    switch display {
    case .signedOut: return "Mở app để đăng nhập"
    case .noSchedule: return "Chưa có lịch tập"
    case .day(let day):
      return day.kind == "workout" ? day.groups.joined(separator: " + ") : "Nghỉ"
    }
  }

  private var status: String? {
    guard case .day(let day) = display else { return nil }
    if day.kind != "workout" { return day.extra ? "+1 buổi thêm" : nil }
    switch day.mark {
    case "done": return "Đã tập"
    case "skipped": return "Không tập"
    default: return day.time.map { "Chưa tập · \($0)" } ?? "Chưa tập"
    }
  }

  private var week: WidgetWeekFile? {
    guard case .day(let day) = display else { return nil }
    return day.week
  }
}

/// Cột phải: "Tuần này", một chấm cho mỗi buổi theo lịch (đặc = Đã tập),
/// "{X}/{Y}" kèm "+{n}" (FA3-10). Chấm cùng một màu, không xanh / đỏ (UR3-13).
private struct WeekColumn: View {
  let week: WidgetWeekFile
  let dot: CGFloat

  var body: some View {
    VStack(alignment: .trailing, spacing: 6) {
      if week.total == 0 {
        Text("Tuần này không có buổi")
          .font(.caption)
          .foregroundStyle(.secondary)
          .multilineTextAlignment(.trailing)
      } else {
        Text("Tuần này")
          .font(.caption)
          .foregroundStyle(.secondary)
        HStack(spacing: dot * 0.4) {
          ForEach(Array(week.dots.enumerated()), id: \.offset) { _, done in
            Circle()
              .fill(done ? Color.ironlyPrimary : Color.clear)
              .overlay(Circle().strokeBorder(done ? Color.clear : Color.ironlyEmptyDot, lineWidth: 2))
              .frame(width: dot, height: dot)
          }
        }
        Text(week.extra > 0 ? "\(week.done)/\(week.total) +\(week.extra)" : "\(week.done)/\(week.total)")
          .font(.headline)
      }
    }
    .fixedSize()
  }
}

extension Color {
  /// Màu chủ đạo của app (`AppTheme`): teal sáng / tối.
  static let ironlyPrimary = Color(light: 0x0E766C, dark: 0x55C5B6)
  static let ironlyEmptyDot = Color(light: 0x9AA5A2, dark: 0xA5B1AE)
  static let ironlyWidgetBackground = Color(light: 0xFFFFFF, dark: 0x1A2220)

  init(light: UInt32, dark: UInt32) {
    self.init(UIColor { traits in
      let hex = traits.userInterfaceStyle == .dark ? dark : light
      return UIColor(
        red: CGFloat((hex >> 16) & 0xFF) / 255,
        green: CGFloat((hex >> 8) & 0xFF) / 255,
        blue: CGFloat(hex & 0xFF) / 255,
        alpha: 1)
    })
  }
}
