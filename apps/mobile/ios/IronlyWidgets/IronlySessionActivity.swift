import ActivityKit
import SwiftUI
import WidgetKit

/// S-71 — thẻ buổi tập trên màn hình khóa và Dynamic Island (04 Bản 4 §6.8).
/// Thẻ: hàng đầu icon app nhỏ + nhóm cơ 13 / 600; hai ô thẻ nổi: **trái** dấu
/// tích cam + bài vừa ghi + mức cam 600, **phải** mũi tên chữ phụ + bài kế
/// tiếp + mức buổi trước mờ. Dynamic Island thu gọn: icon · "→ {mức buổi
/// trước của bài kế tiếp}". Không "Ironly · Buổi tập hôm nay", không "Vừa ghi
/// / Kế tiếp" (FR4-04, FR4-05); dấu hiệu có `accessibilityLabel` là câu chữ
/// Bản 3 (TD4-07). Chỉ hiển thị, không nút; chạm → buổi tập hôm nay (NAV-16).
/// Không cân nặng, calo, ghi chú, lời khuyên (F25-R8). `ContentState`,
/// `Attributes`, hiện / tắt theo `03` Bản 3 (F4-R9). Màu theo token, không
/// theo sáng / tối của máy (TA4-08).
struct IronlySessionActivity: Widget {
  static let url = URL(string: "ironly://session/today")!

  var body: some WidgetConfiguration {
    ActivityConfiguration(for: IronlySessionAttributes.self) { context in
      LockScreenActivityView(groups: context.attributes.groups, state: context.state)
        .activityBackgroundTint(Tokens.color.surface)
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
        AppMark(size: 18)
      }
      .widgetURL(Self.url)
    }
  }
}

/// Câu chữ S-71 còn dùng (`03` Bản 3 §6.13, trùng `strings_vi.dart`, có test
/// đối chiếu); phần còn lại thay bằng dấu hiệu.
enum ActivityText {
  static func lastLogged(_ s: IronlySessionAttributes.ContentState) -> String {
    s.lastLogged.map { "\($0.name) · \($0.lift)" } ?? "Chưa ghi bài nào"
  }

  static func previous(_ next: IronlySessionAttributes.ContentState.Next) -> String {
    next.prev ?? "Buổi trước: chưa ghi"
  }

  static func next(_ s: IronlySessionAttributes.ContentState) -> String {
    s.next.map { "\($0.name) · \(previous($0))" } ?? "Đã ghi hết bài"
  }

  /// Dynamic Island thu gọn: "→ 40 → 45 kg"; bài kế tiếp chưa có mức buổi
  /// trước → chỉ mũi tên; đã ghi hết → "Đã ghi hết bài"; bài bụng → nil.
  static func compact(_ s: IronlySessionAttributes.ContentState) -> String? {
    if s.absOnly { return nil }
    guard let next = s.next else { return "Đã ghi hết bài" }
    return next.prev.map { "→ \($0)" } ?? "→"
  }
}

/// Icon app nhỏ: ô vuông nền than đậm, thanh tạ cam (04 Bản 4 §6.8).
struct AppMark: View {
  var size: CGFloat = 22

  var body: some View {
    RoundedRectangle(cornerRadius: size * 0.27, style: .continuous)
      .fill(Tokens.color.iconBg)
      .frame(width: size, height: size)
      .overlay(
        Image(systemName: "dumbbell.fill")
          .scaledFont(size * 0.55, .bold)
          .foregroundStyle(Tokens.color.accent))
      .accessibilityHidden(true)
  }
}

/// Thẻ màn hình khóa: hàng nhóm cơ, hai ô thẻ nổi (vừa ghi · kế tiếp).
struct LockScreenActivityView: View {
  let groups: String
  let state: IronlySessionAttributes.ContentState

  var body: some View {
    VStack(alignment: .leading, spacing: Tokens.space.s3) {
      HStack(spacing: Tokens.space.s2) {
        AppMark()
        Text(groups)
          .scaledFont(Tokens.type.activityTitle, .semibold)
          .lineLimit(1)
        Spacer(minLength: 0)
      }
      if state.absOnly {
        Text("Bài bụng không ghi mức tạ")
          .scaledFont(Tokens.type.body)
          .foregroundStyle(Tokens.color.textSecondary)
      } else {
        HStack(alignment: .top, spacing: Tokens.space.s2) {
          ActivityCell {
            if let last = state.lastLogged {
              Image(systemName: "checkmark")
                .scaledFont(13, .bold)
                .foregroundStyle(Tokens.color.accent)
                .accessibilityLabel("Vừa ghi")
              Text(last.name)
                .scaledFont(Tokens.type.cardTitle, .semibold)
              Text(last.lift)
                .scaledFont(Tokens.type.body, .semibold)
                .foregroundStyle(Tokens.color.accent)
            } else {
              Text("Chưa ghi bài nào")
                .scaledFont(Tokens.type.caption2)
                .foregroundStyle(Tokens.color.textSecondary)
            }
          }
          ActivityCell {
            if let next = state.next {
              Image(systemName: "arrow.right")
                .scaledFont(13, .bold)
                .foregroundStyle(Tokens.color.textSecondary)
                .accessibilityLabel("Kế tiếp")
              Text(next.name)
                .scaledFont(Tokens.type.cardTitle, .semibold)
              Text(ActivityText.previous(next))
                .scaledFont(Tokens.type.body)
                .foregroundStyle(Tokens.color.textPrefill)
            } else {
              Text("Đã ghi hết bài")
                .scaledFont(Tokens.type.caption2)
                .foregroundStyle(Tokens.color.textSecondary)
            }
          }
        }
      }
    }
    .foregroundStyle(Tokens.color.textPrimary)
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(Tokens.size.cardPadding)
    .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
  }
}

/// Ô thẻ nổi trong thẻ: nền `surfaceRaised`, bo 10, nội dung xếp dọc.
private struct ActivityCell<Content: View>: View {
  @ViewBuilder let content: Content

  var body: some View {
    VStack(alignment: .leading, spacing: Tokens.space.s1) { content }
      .lineLimit(2)
      .minimumScaleFactor(0.8)
      .frame(maxWidth: .infinity, minHeight: 64, alignment: .topLeading)
      .padding(Tokens.space.s3)
      .background(
        RoundedRectangle(cornerRadius: Tokens.radius.field, style: .continuous)
          .fill(Tokens.color.surfaceRaised))
  }
}

/// Dynamic Island thu gọn, trái: icon app.
struct IslandCompactLeading: View {
  let groups: String

  var body: some View {
    AppMark(size: 20).accessibilityLabel(groups)
  }
}

/// Dynamic Island thu gọn, phải: "→ {mức buổi trước của bài kế tiếp}".
struct IslandCompactTrailing: View {
  let state: IronlySessionAttributes.ContentState

  var body: some View {
    if let text = ActivityText.compact(state) {
      Text(text)
        .scaledFont(Tokens.type.caption2, .medium)
        .foregroundStyle(Tokens.color.textPrimary)
        .lineLimit(1)
    }
  }
}

/// Dynamic Island mở rộng: nhóm cơ; "→ {bài kế tiếp} · {mức buổi trước}";
/// "✓ {bài vừa ghi} · {mức}".
struct IslandExpandedView: View {
  let groups: String
  let state: IronlySessionAttributes.ContentState

  var body: some View {
    VStack(alignment: .leading, spacing: Tokens.space.s2) {
      HStack(spacing: Tokens.space.s2) {
        AppMark(size: 18)
        Text(groups).scaledFont(Tokens.type.activityTitle, .semibold)
      }
      if state.absOnly {
        Text("Bài bụng không ghi mức tạ")
          .scaledFont(Tokens.type.body)
          .foregroundStyle(Tokens.color.textSecondary)
      } else {
        HStack(spacing: Tokens.space.s2) {
          Image(systemName: "arrow.right")
            .scaledFont(12, .bold)
            .foregroundStyle(Tokens.color.textSecondary)
            .accessibilityLabel("Kế tiếp")
          Text(ActivityText.next(state))
            .scaledFont(Tokens.type.body, .semibold)
        }
        HStack(spacing: Tokens.space.s2) {
          Image(systemName: "checkmark")
            .scaledFont(12, .bold)
            .foregroundStyle(Tokens.color.accent)
            .accessibilityLabel("Vừa ghi")
          Text(ActivityText.lastLogged(state))
            .scaledFont(Tokens.type.caption2)
            .foregroundStyle(Tokens.color.textSecondary)
        }
      }
    }
    .lineLimit(1)
    .foregroundStyle(Tokens.color.textPrimary)
    .frame(maxWidth: .infinity, alignment: .leading)
  }
}
