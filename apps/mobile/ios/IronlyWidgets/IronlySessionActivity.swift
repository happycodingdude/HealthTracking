import ActivityKit
import SwiftUI
import WidgetKit

/// S-71 — thẻ buổi tập trên màn hình khóa và Dynamic Island (04 Bản 3 §6.8,
/// UA3-15). Chỉ hiển thị, không nút; chạm → buổi tập hôm nay (NAV-16). Không
/// cân nặng, calo, ghi chú, lời khuyên (F25-R8).
struct IronlySessionActivity: Widget {
  static let url = URL(string: "ironly://session/today")!

  var body: some WidgetConfiguration {
    ActivityConfiguration(for: IronlySessionAttributes.self) { context in
      LockScreenActivityView(groups: context.attributes.groups, state: context.state)
        .activityBackgroundTint(Color.ironlyWidgetBackground)
        .widgetURL(Self.url)
    } dynamicIsland: { context in
      DynamicIsland {
        DynamicIslandExpandedRegion(.bottom) {
          IslandExpandedView(groups: context.attributes.groups, state: context.state)
        }
      } compactLeading: {
        IslandCompactLeading(groups: context.attributes.groups)
      } compactTrailing: {
        IslandCompactTrailing(state: context.state)
      } minimal: {
        Image(systemName: "figure.strengthtraining.traditional")
      }
      .widgetURL(Self.url)
    }
  }
}

/// Câu chữ S-71 (`03` Bản 3 §6.13, trùng `strings_vi.dart`, có test đối chiếu).
enum ActivityText {
  static func lastLogged(_ s: IronlySessionAttributes.ContentState) -> String {
    s.lastLogged.map { "\($0.name) · \($0.lift)" } ?? "Chưa ghi bài nào"
  }

  static func previous(_ next: IronlySessionAttributes.ContentState.Next) -> String {
    next.prev.map { "Buổi trước: \($0)" } ?? "Buổi trước: chưa ghi"
  }

  static func next(_ s: IronlySessionAttributes.ContentState) -> String {
    s.next.map { "\($0.name) · \(previous($0))" } ?? "Đã ghi hết bài"
  }

  /// Dynamic Island thu gọn: "Kế tiếp: 40 → 45 kg".
  static func compact(_ s: IronlySessionAttributes.ContentState) -> String? {
    if s.absOnly { return nil }
    guard let next = s.next else { return "Đã ghi hết bài" }
    return next.prev.map { "Kế tiếp: \($0)" } ?? "Kế tiếp: chưa ghi"
  }
}

/// Thẻ màn hình khóa: dòng nhóm cơ, "Vừa ghi", "Kế tiếp" (đặt cuối, đậm hơn).
struct LockScreenActivityView: View {
  let groups: String
  let state: IronlySessionAttributes.ContentState

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      VStack(alignment: .leading, spacing: 0) {
        Text("Ironly · Buổi tập hôm nay")
          .font(.caption)
          .foregroundStyle(.secondary)
        Text(groups)
          .font(.title3.bold())
      }
      if state.absOnly {
        Text("Bài bụng không ghi mức tạ")
          .font(.subheadline)
      } else {
        VStack(alignment: .leading, spacing: 0) {
          Text("Vừa ghi")
            .font(.caption)
            .foregroundStyle(.secondary)
          Text(ActivityText.lastLogged(state))
            .font(.subheadline)
        }
        VStack(alignment: .leading, spacing: 0) {
          Text("Kế tiếp")
            .font(.caption)
            .foregroundStyle(.secondary)
          Text(ActivityText.next(state))
            .font(.subheadline.weight(.semibold))
        }
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(16)
    .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
  }
}

/// Dynamic Island luôn nền đen: chữ luôn vẽ kiểu tối, máy đặt sáng hay tối
/// đều như nhau (UX-AC63).
struct IslandCompactLeading: View {
  let groups: String

  var body: some View {
    Text(groups).font(.caption.bold()).lineLimit(1)
      .environment(\.colorScheme, .dark)
  }
}

struct IslandCompactTrailing: View {
  let state: IronlySessionAttributes.ContentState

  var body: some View {
    if let text = ActivityText.compact(state) {
      Text(text).font(.caption).lineLimit(1)
        .environment(\.colorScheme, .dark)
    }
  }
}

/// Dynamic Island mở rộng: "Ironly · {nhóm cơ}", "Kế tiếp: {bài}", "Buổi trước:
/// …", "Vừa ghi: …".
struct IslandExpandedView: View {
  let groups: String
  let state: IronlySessionAttributes.ContentState

  var body: some View {
    VStack(alignment: .leading, spacing: 4) {
      Text("Ironly · \(groups)")
        .font(.caption)
        .foregroundStyle(.secondary)
      if state.absOnly {
        Text("Bài bụng không ghi mức tạ").font(.subheadline)
      } else {
        if let next = state.next {
          Text("Kế tiếp: \(next.name)").font(.subheadline.bold())
          Text(ActivityText.previous(next)).font(.caption)
        } else {
          Text("Đã ghi hết bài").font(.subheadline.bold())
        }
        if let last = state.lastLogged {
          Text("Vừa ghi: \(last.name) \(last.lift)").font(.caption)
        } else {
          Text("Chưa ghi bài nào").font(.caption)
        }
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .environment(\.colorScheme, .dark)
  }
}
