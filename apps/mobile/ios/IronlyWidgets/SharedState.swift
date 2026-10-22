import Foundation

/// File dùng chung giữa app và extension trong App Group (05 Bản 3 TD3-02,
/// §6.8.1). Tên App Group theo flavor, đọc từ Info.plist (`IronlyAppGroup`).
enum SharedState {
  static let widgetFile = "widget_state.json"

  static var appGroup: String? {
    Bundle.main.object(forInfoDictionaryKey: "IronlyAppGroup") as? String
  }

  /// Thư mục App Group; test truyền thư mục tạm.
  static func directory(_ override: URL? = nil) -> URL? {
    if let override { return override }
    guard let group = appGroup else { return nil }
    return FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: group)
  }

  /// App ghi `widget_state.json` (ghi nguyên tử: widget không đọc nửa file).
  static func writeWidgetState(_ json: String, in dir: URL? = nil) throws {
    guard let dir = directory(dir) else { throw SharedStateError.noAppGroup }
    try Data(json.utf8).write(to: dir.appendingPathComponent(widgetFile), options: .atomic)
  }

  /// Extension đọc; thiếu file → nil.
  static func readWidgetState(in dir: URL? = nil) -> Data? {
    guard let dir = directory(dir) else { return nil }
    return try? Data(contentsOf: dir.appendingPathComponent(widgetFile))
  }

  /// Đăng xuất (TD3-17): xóa mọi file của app trong App Group. Gọi lại được.
  static func clear(in dir: URL? = nil) throws {
    guard let dir = directory(dir) else { throw SharedStateError.noAppGroup }
    let fm = FileManager.default
    for item in (try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)) ?? []
    where item.lastPathComponent != "Library" {
      try fm.removeItem(at: item)
    }
  }
}

enum SharedStateError: Error {
  case noAppGroup
}
