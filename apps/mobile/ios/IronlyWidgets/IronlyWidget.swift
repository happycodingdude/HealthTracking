import SwiftUI
import WidgetKit

/// S-70 — widget màn hình chính cỡ vừa (F-24). Chỉ hiển thị, chạm mở app theo
/// NAV-15; không mạng, không AI (F24-R7, TR3-10). Nền than theo token (04 Bản
/// 4 §6.8, TA4-08).
struct IronlyWidget: Widget {
  var body: some WidgetConfiguration {
    StaticConfiguration(kind: "IronlyWidget", provider: Provider()) { entry in
      WidgetContentView(display: entry.display)
        .widgetURL(entry.display.url)
        .containerBackground(Tokens.color.bg, for: .widget)
    }
    .configurationDisplayName("Ironly")
    .description("Hôm nay tập gì và số buổi tuần này.")
    .supportedFamilies([.systemMedium])
  }
}

struct Entry: TimelineEntry {
  let date: Date
  let display: WidgetDisplay
}

struct Provider: TimelineProvider {
  func placeholder(in context: Context) -> Entry {
    Entry(date: Date(), display: .signedOut(weekday: nil))
  }

  func getSnapshot(in context: Context, completion: @escaping (Entry) -> Void) {
    let file = WidgetStateFile.decode(SharedState.readWidgetState())
    completion(Entry(date: Date(), display: WidgetTimeline.display(file, at: Date())))
  }

  /// Mục "bây giờ" + 00:00 mỗi ngày trong file; hết mục thì iPhone hỏi lại.
  func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> Void) {
    let file = WidgetStateFile.decode(SharedState.readWidgetState())
    let entries = WidgetTimeline.entries(file, now: Date()).map {
      Entry(date: $0.date, display: $0.display)
    }
    completion(Timeline(entries: entries, policy: .atEnd))
  }
}
