import SwiftUI

/// S-70 cỡ vừa (04 Bản 4 §6.8): nền than, **trái** thứ in hoa chữ phụ 10 ·
/// nhóm cơ 20 / 600 trắng (đã tập: dấu tích cam trước tên; không tập: gạch
/// ngang; nghỉ: "Nghỉ" chữ phụ + "+1 buổi thêm" cam) · giờ chữ phụ; **phải**
/// "TUẦN NÀY" · "2" cam 24 / 600 + "/4" chữ phụ · chấm 8 pt (cam đã tập, viền
/// cam hôm nay, thẻ nổi còn lại). Không chữ "Ironly", "Chưa tập" (FR4-04,
/// FR4-05); nội dung, nguồn dữ liệu, URL như Bản 3 (F4-R9). Dấu hiệu có
/// `accessibilityLabel` là câu chữ Bản 3 (TD4-07). Màu đặt thẳng theo token,
/// không theo sáng / tối của máy (TA4-08).
struct WidgetContentView: View {
  let display: WidgetDisplay

  var body: some View {
    content
      // Widget cỡ vừa có chỗ cố định: chữ lớn tới mức xxxLarge, lớn hơn thì
      // giữ ở mức này để không cắt chữ.
      .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
      .foregroundStyle(Tokens.color.textPrimary)
  }

  @ViewBuilder
  private var content: some View {
    switch display {
    case .signedOut:
      Text("Mở app để đăng nhập")
        .scaledFont(Tokens.type.subtitle, .semibold)
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    case .noSchedule(let weekday):
      HStack(alignment: .top) {
        VStack(alignment: .leading, spacing: Tokens.space.s1) {
          WidgetCaption(weekday)
          Text("Chưa có lịch tập")
            .scaledFont(Tokens.type.widgetTitle, .semibold)
            .lineLimit(2)
            .minimumScaleFactor(0.6)
        }
        Spacer(minLength: 0)
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    case .day(let day, let todayDot):
      HStack(alignment: .top, spacing: Tokens.space.s4) {
        DayColumn(day: day)
        Spacer(minLength: 0)
        WeekColumn(week: day.week, todayDot: day.mark == nil ? todayDot : nil)
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
  }
}

/// Chữ phụ 10 in hoa ("THỨ 2", "TUẦN NÀY").
private struct WidgetCaption: View {
  let text: String
  init(_ text: String) { self.text = text }

  var body: some View {
    Text(text)
      .textCase(.uppercase)
      .scaledFont(Tokens.type.widgetCaption, .medium)
      .tracking(0.4)
      .foregroundStyle(Tokens.color.textSecondary)
      .lineLimit(1)
  }
}

/// Cột trái: thứ, nhóm cơ (kèm dấu hiệu trạng thái), giờ.
private struct DayColumn: View {
  let day: WidgetDayFile

  var body: some View {
    VStack(alignment: .leading, spacing: Tokens.space.s1) {
      WidgetCaption(day.weekday)
      if day.kind == "workout" {
        HStack(alignment: .center, spacing: Tokens.space.s2) {
          switch day.mark {
          case "done":
            Image(systemName: "checkmark")
              .scaledFont(15, .bold)
              .foregroundStyle(Tokens.color.accent)
              .accessibilityLabel("Đã tập")
          case "skipped":
            Image(systemName: "minus")
              .scaledFont(15, .bold)
              .foregroundStyle(Tokens.color.textSecondary)
              .accessibilityLabel("Không tập")
          default:
            EmptyView()
          }
          Text(day.groups.joined(separator: " + "))
            .scaledFont(Tokens.type.widgetTitle, .semibold)
            .lineLimit(2)
            .minimumScaleFactor(0.6)
            .fixedSize(horizontal: false, vertical: true)
        }
        if let time = day.time {
          Text(time)
            .scaledFont(Tokens.type.caption)
            .foregroundStyle(Tokens.color.textSecondary)
            // Hôm nay chờ đánh dấu: VoiceOver đọc như Bản 3.
            .accessibilityLabel(day.mark == nil ? "Chưa tập · \(time)" : time)
        }
      } else {
        Text("Nghỉ")
          .scaledFont(Tokens.type.widgetTitle, .semibold)
          .foregroundStyle(Tokens.color.textSecondary)
        if day.extra {
          // Dấu "+" cam = buổi tập thêm (03 Bản 4 §6.4); file widget không có
          // nhóm cơ của buổi thêm nên giữ câu "+1 buổi thêm".
          Text("+1 buổi thêm")
            .scaledFont(Tokens.type.caption2, .semibold)
            .foregroundStyle(Tokens.color.accent)
        }
      }
    }
  }
}

/// Cột phải: "TUẦN NÀY", "{X}" cam lớn + "/{Y}" chữ phụ (+ "+{n}" buổi thêm),
/// một chấm cho mỗi buổi theo lịch (FA3-10): cam đã tập, viền cam hôm nay chờ
/// đánh dấu, thẻ nổi còn lại. Cùng một màu cho mọi chấm, không xanh / đỏ.
private struct WeekColumn: View {
  let week: WidgetWeekFile
  let todayDot: Int?

  var body: some View {
    VStack(alignment: .trailing, spacing: Tokens.space.s1) {
      if week.total == 0 {
        Text("Tuần này không có buổi")
          .scaledFont(Tokens.type.caption)
          .foregroundStyle(Tokens.color.textSecondary)
          .multilineTextAlignment(.trailing)
      } else {
        WidgetCaption("Tuần này")
        HStack(alignment: .firstTextBaseline, spacing: 1) {
          Text("\(week.done)")
            .scaledFont(Tokens.type.widgetNumber, .semibold)
            .foregroundStyle(Tokens.color.accent)
          Text("/\(week.total)")
            .scaledFont(Tokens.type.caption2)
            .foregroundStyle(Tokens.color.textSecondary)
          if week.extra > 0 {
            Text(" +\(week.extra)")
              .scaledFont(Tokens.type.caption2, .semibold)
              .foregroundStyle(Tokens.color.accent)
          }
        }
        .accessibilityElement(children: .combine)
        ProgressDots(dots: week.dots, todayDot: todayDot)
          .accessibilityLabel("Đã tập \(week.done)/\(week.total) buổi theo lịch")
      }
    }
    .fixedSize()
  }
}

/// Chấm tiến độ 8 pt (04 Bản 4 S-70): cam đã tập, viền cam hôm nay, thẻ nổi
/// còn lại — cùng dấu hiệu với `ProgressDots` của app.
struct ProgressDots: View {
  let dots: [Bool]
  let todayDot: Int?
  var size: CGFloat = Tokens.size.dot

  var body: some View {
    HStack(spacing: size * 0.5) {
      ForEach(Array(dots.enumerated()), id: \.offset) { i, done in
        Circle()
          .fill(done ? Tokens.color.accent : (i == todayDot ? Tokens.color.transparent : Tokens.color.surfaceRaised))
          .overlay(
            Circle().strokeBorder(
              Tokens.color.accent,
              lineWidth: !done && i == todayDot ? 1.5 : 0))
          .frame(width: size, height: size)
      }
    }
  }
}

/// Cỡ chữ token nhân theo cỡ chữ hệ thống (Dynamic Type) tới mức xxxLarge
/// (các view gốc đã chặn ở mức này để không cắt chữ), như `@ScaledMetric`
/// của Bản 3 nhưng áp cho mọi chữ.
struct ScaledFont: ViewModifier {
  let size: CGFloat
  let weight: Font.Weight

  @Environment(\.dynamicTypeSize) private var typeSize

  func body(content: Content) -> some View {
    content.font(.system(size: size * typeSize.ironlyScale, weight: weight))
  }
}

extension View {
  func scaledFont(_ size: CGFloat, _ weight: Font.Weight = .regular) -> some View {
    modifier(ScaledFont(size: size, weight: weight))
  }
}

extension DynamicTypeSize {
  /// Hệ số theo bậc cỡ chữ của iOS (mặc định "Large" = 1).
  var ironlyScale: CGFloat {
    switch self {
    case .xSmall: return 0.85
    case .small: return 0.9
    case .medium: return 0.95
    case .large: return 1
    case .xLarge: return 1.1
    case .xxLarge: return 1.2
    default: return 1.3
    }
  }
}
