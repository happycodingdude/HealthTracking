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

    init(lastLogged: Lift?, next: Next?, allLogged: Bool, absOnly: Bool) {
      self.lastLogged = lastLogged
      self.next = next
      self.allLogged = allLogged
      self.absOnly = absOnly
    }

    /// Thiếu hoặc sai trường → giá trị trống, không crash (VS41-T06).
    init(from decoder: Decoder) throws {
      let c = try decoder.container(keyedBy: CodingKeys.self)
      lastLogged = try? c.decodeIfPresent(Lift.self, forKey: .lastLogged)
      next = try? c.decodeIfPresent(Next.self, forKey: .next)
      allLogged = (try? c.decodeIfPresent(Bool.self, forKey: .allLogged)) ?? (next == nil)
      absOnly = (try? c.decodeIfPresent(Bool.self, forKey: .absOnly)) ?? false
    }
  }

  /// `yyyy-MM-dd` của buổi.
  var date: String
  /// "Ngực + Tay sau".
  var groups: String
}
