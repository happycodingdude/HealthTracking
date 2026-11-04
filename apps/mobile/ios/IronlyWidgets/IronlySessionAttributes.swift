import ActivityKit
import Foundation

/// Thẻ buổi tập S-71 (05 Bản 3 §6.9.2): `attributes-type` của push `start` là
/// tên kiểu này. Dùng chung app (cập nhật, tắt) và extension (vẽ).
struct IronlySessionAttributes: ActivityAttributes {
  /// `content-state` = `LiveActivityContent` của `packages/domain` (ED3-03):
  /// app / server tính sẵn, Swift chỉ vẽ (ED3-07).
  struct ContentState: Codable, Hashable {
    struct Lift: Codable, Hashable {
      var name: String
      var lift: String
    }

    struct Next: Codable, Hashable {
      var name: String
      /// "40 → 45 kg"; null = "Buổi trước: chưa ghi".
      var prev: String?
    }

    var lastLogged: Lift?
    var next: Next?
    var allLogged: Bool
    var absOnly: Bool
    /// Thẻ ngày nghỉ: mời bắt đầu Buổi tập thêm (05 Bản 5 TD5-15); thiếu =
    /// false (push Bản 3 / 4).
    var inviteExtra: Bool

    init(
      lastLogged: Lift?, next: Next?, allLogged: Bool, absOnly: Bool, inviteExtra: Bool = false
    ) {
      self.lastLogged = lastLogged
      self.next = next
      self.allLogged = allLogged
      self.absOnly = absOnly
      self.inviteExtra = inviteExtra
    }

    /// Thiếu hoặc sai trường → giá trị trống, không crash (VS41-T06).
    init(from decoder: Decoder) throws {
      let c = try decoder.container(keyedBy: CodingKeys.self)
      lastLogged = try? c.decodeIfPresent(Lift.self, forKey: .lastLogged)
      next = try? c.decodeIfPresent(Next.self, forKey: .next)
      allLogged = (try? c.decodeIfPresent(Bool.self, forKey: .allLogged)) ?? (next == nil)
      absOnly = (try? c.decodeIfPresent(Bool.self, forKey: .absOnly)) ?? false
      inviteExtra = (try? c.decodeIfPresent(Bool.self, forKey: .inviteExtra)) ?? false
    }
  }

  /// Loại thẻ (05 Bản 5 TD5-15): buổi tập theo lịch hay thẻ ngày nghỉ rút gọn.
  static let sessionKind = "session"
  static let extraKind = "extra"

  /// `yyyy-MM-dd` của buổi.
  var date: String
  /// "Ngực + Tay sau"; thẻ ngày nghỉ: "Nghỉ".
  var groups: String
  /// `session` | `extra`; push Bản 3 / 4 không có → `session` (TA5-04).
  var kind: String

  init(date: String, groups: String, kind: String = IronlySessionAttributes.sessionKind) {
    self.date = date
    self.groups = groups
    self.kind = kind
  }

  init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    date = try c.decode(String.self, forKey: .date)
    groups = try c.decode(String.self, forKey: .groups)
    kind = (try? c.decodeIfPresent(String.self, forKey: .kind)) ?? Self.sessionKind
  }

  /// Thẻ ngày nghỉ (S-71 rút gọn, UD5-04).
  var isExtra: Bool { kind == Self.extraKind }
}
