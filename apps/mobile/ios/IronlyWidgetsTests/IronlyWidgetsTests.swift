import SwiftUI
import XCTest

/// 06 Bản 3 VS39-T08 (Swift): đọc `widget_state.json`, file hỏng / thiếu không
/// crash (ED3-07), timeline 00:00 (TAC3-09), URL theo NAV-15, ảnh chụp 7 trạng
/// thái × sáng / tối × cỡ chữ lớn (UX-AC57, UX-AC63; ED3-14).
final class IronlyWidgetsTests: XCTestCase {
  private var calendar: Calendar = {
    var c = Calendar(identifier: .gregorian)
    c.timeZone = TimeZone(identifier: "Asia/Ho_Chi_Minh")!
    return c
  }()

  private func at(_ day: Int, _ hour: Int = 10) -> Date {
    calendar.date(from: DateComponents(year: 2026, month: 10, day: day, hour: hour))!
  }

  private func week(_ done: Int, _ total: Int, extra: Int = 0) -> String {
    let dots = (0..<total).map { $0 < done ? "true" : "false" }.joined(separator: ",")
    return #"{"total":\#(total),"done":\#(done),"extra":\#(extra),"dots":[\#(dots)]}"#
  }

  private func day(
    _ date: String, _ weekday: String, kind: String = "workout", groups: [String] = ["Lưng"],
    time: String? = "18:00", mark: String? = nil, extra: Bool = false, week: String
  ) -> String {
    let g = groups.map { "\"\($0)\"" }.joined(separator: ",")
    let t = time.map { "\"\($0)\"" } ?? "null"
    let m = mark.map { "\"\($0)\"" } ?? "null"
    return #"{"date":"\#(date)","weekday":"\#(weekday)","kind":"\#(kind)","groups":[\#(g)],"time":\#(t),"mark":\#(m),"extra":\#(extra),"week":\#(week)}"#
  }

  private func file(_ days: [String], signedIn: Bool = true, hasSchedule: Bool = true) -> WidgetStateFile? {
    let json = #"{"schema":1,"signedIn":\#(signedIn),"hasSchedule":\#(hasSchedule),"generatedAt":"2026-10-13T10:00:00+07:00","days":[\#(days.joined(separator: ","))]}"#
    return WidgetStateFile.decode(Data(json.utf8))
  }

  // MARK: - Nội dung, file hỏng

  func testF24AC1TuesdayBackNotDone() throws {
    let f = try XCTUnwrap(file([day("2026-10-13", "Thứ 3", week: week(1, 4))]))
    guard case .day(let d) = WidgetTimeline.display(f, at: at(13), calendar: calendar) else {
      return XCTFail("phải là ngày có lịch")
    }
    XCTAssertEqual(d.groups, ["Lưng"])
    XCTAssertEqual(d.week.dots, [true, false, false, false])
  }

  func testED307BrokenOrMissingFileShowsSignedOut() {
    XCTAssertNil(WidgetStateFile.decode(nil))
    XCTAssertNil(WidgetStateFile.decode(Data("{".utf8)))
    XCTAssertNil(WidgetStateFile.decode(Data(#"{"schema":2,"signedIn":true,"hasSchedule":true,"days":[]}"#.utf8)))
    XCTAssertEqual(WidgetTimeline.display(nil, at: at(13), calendar: calendar), .signedOut(weekday: nil))
    XCTAssertEqual(WidgetTimeline.entries(nil, now: at(13), calendar: calendar).count, 1)
  }

  func testSignedOutAndNoSchedule() throws {
    let out = try XCTUnwrap(file([day("2026-10-14", "Thứ 4", week: week(0, 0))], signedIn: false, hasSchedule: false))
    XCTAssertEqual(WidgetTimeline.display(out, at: at(14), calendar: calendar), .signedOut(weekday: "Thứ 4"))
    let none = try XCTUnwrap(file([day("2026-10-14", "Thứ 4", week: week(0, 0))], hasSchedule: false))
    XCTAssertEqual(WidgetTimeline.display(none, at: at(14), calendar: calendar), .noSchedule(weekday: "Thứ 4"))
  }

  // MARK: - Timeline (TAC3-09, F24-AC7)

  func testTAC309MidnightEntriesSwitchToNextDay() throws {
    let f = try XCTUnwrap(file([
      day("2026-10-17", "Thứ 7", kind: "rest", groups: [], time: nil, week: week(3, 4)),
      day("2026-10-18", "Chủ nhật", kind: "rest", groups: [], time: nil, week: week(3, 4)),
      day("2026-10-19", "Thứ 2", groups: ["Ngực", "Tay sau"], week: week(0, 4)),
    ]))
    let entries = WidgetTimeline.entries(f, now: at(17, 20), calendar: calendar)
    XCTAssertEqual(entries.map(\.date), [at(17, 20), at(18, 0), at(19, 0)])
    guard case .day(let monday) = entries[2].display else { return XCTFail() }
    XCTAssertEqual(monday.weekday, "Thứ 2")
    XCTAssertEqual(monday.week.done, 0, "thứ 2 tuần mới về 0/Y")
  }

  func testNoEntryForTodayAfterEightDaysShowsOpenApp() throws {
    let f = try XCTUnwrap(file([day("2026-10-13", "Thứ 3", week: week(1, 4))]))
    XCTAssertEqual(WidgetTimeline.display(f, at: at(25), calendar: calendar), .signedOut(weekday: nil))
  }

  // MARK: - Chạm (NAV-15)

  func testNAV15Urls() throws {
    let workout = try XCTUnwrap(file([day("2026-10-13", "Thứ 3", week: week(1, 4))]))
    XCTAssertEqual(WidgetTimeline.display(workout, at: at(13), calendar: calendar).url.absoluteString, "ironly://session/today")
    let rest = try XCTUnwrap(file([day("2026-10-14", "Thứ 4", kind: "rest", groups: [], time: nil, week: week(2, 4))]))
    XCTAssertEqual(WidgetTimeline.display(rest, at: at(14), calendar: calendar).url.absoluteString, "ironly://today")
    let extra = try XCTUnwrap(file([day("2026-10-14", "Thứ 4", kind: "rest", groups: [], time: nil, extra: true, week: week(2, 4, extra: 1))]))
    XCTAssertEqual(WidgetTimeline.display(extra, at: at(14), calendar: calendar).url.absoluteString, "ironly://session/today")
    XCTAssertEqual(WidgetDisplay.noSchedule(weekday: "Thứ 4").url.absoluteString, "ironly://today")
    XCTAssertEqual(WidgetDisplay.signedOut(weekday: nil).url.absoluteString, "ironly://login")
  }

  // MARK: - App Group

  func testSharedStateWriteReadClear() throws {
    let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: dir) }
    try SharedState.writeWidgetState(#"{"schema":1}"#, in: dir)
    XCTAssertEqual(SharedState.readWidgetState(in: dir), Data(#"{"schema":1}"#.utf8))
    try SharedState.clear(in: dir)
    try SharedState.clear(in: dir)
    XCTAssertNil(SharedState.readWidgetState(in: dir))
  }

  // MARK: - Ảnh chụp (UX-AC57, UX-AC63)

  private func states() throws -> [(String, WidgetDisplay)] {
    func d(_ json: String) throws -> WidgetDisplay {
      let f = try XCTUnwrap(file([json]))
      return WidgetTimeline.display(f, at: at(13), calendar: calendar)
    }
    return [
      ("not_done", try d(day("2026-10-13", "Thứ 3", week: week(1, 4)))),
      ("done", try d(day("2026-10-13", "Thứ 3", mark: "done", week: week(2, 4)))),
      ("skipped", try d(day("2026-10-13", "Thứ 5", groups: ["Ngực", "Tay sau"], mark: "skipped", week: week(2, 4)))),
      ("rest_extra", try d(day("2026-10-13", "Thứ 4", kind: "rest", groups: [], time: nil, extra: true, week: week(2, 4, extra: 1)))),
      ("rest_no_sessions", try d(day("2026-10-13", "Chủ nhật", kind: "rest", groups: [], time: nil, week: week(0, 0)))),
      ("no_schedule", .noSchedule(weekday: "Thứ 4")),
      ("signed_out", .signedOut(weekday: "Thứ 4")),
    ]
  }

  @MainActor
  func testSnapshots() throws {
    // Chưa có bộ ảnh cho bản iOS này (ví dụ máy CI chạy iOS khác): ghi bộ ảnh
    // để xem lại, không so.
    let firstRun = !FileManager.default.fileExists(atPath: snapshotDir.path)
    let recording = firstRun || ProcessInfo.processInfo.environment["SNAPSHOT_RECORD"] == "1"
    var failures: [String] = []
    for (name, display) in try states() {
      for (variant, scheme, size) in [
        ("light", ColorScheme.light, DynamicTypeSize.large),
        ("dark", ColorScheme.dark, DynamicTypeSize.large),
        ("light_maxtext", ColorScheme.light, DynamicTypeSize.accessibility3),
      ] {
        let image = try render(display, scheme: scheme, size: size)
        if let problem = try compare(image, name: "s70_\(name)_\(variant)", record: recording) {
          failures.append(problem)
        }
      }
    }
    XCTAssertTrue(failures.isEmpty, failures.joined(separator: "\n"))
    if firstRun { throw XCTSkip("chưa có ảnh cho \(osFolder): đã ghi, chưa so") }
  }

  /// Vẽ các file `widget_state.json` lấy từ App Group của simulator (demo,
  /// `TEST_RUNNER_DEMO_WIDGET_DIR`), tại ngày đầu của file; không đặt biến thì bỏ qua.
  @MainActor
  func testRenderDemoFiles() throws {
    guard let dir = ProcessInfo.processInfo.environment["DEMO_WIDGET_DIR"] else {
      throw XCTSkip("chỉ dùng khi demo")
    }
    let url = URL(fileURLWithPath: dir)
    for json in try FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: nil)
    where json.pathExtension == "json" {
      let file = WidgetStateFile.decode(try? Data(contentsOf: json))
      let first = file?.days.first.flatMap { WidgetTimeline.dayStart($0.date, calendar: .current) }
      let display = WidgetTimeline.display(file, at: first ?? Date())
      for (variant, scheme) in [("light", ColorScheme.light), ("dark", ColorScheme.dark)] {
        let png = try XCTUnwrap(try render(display, scheme: scheme, size: .large).pngData())
        try png.write(to: json.deletingPathExtension().appendingPathExtension("\(variant).png"))
      }
    }
  }

  /// Cỡ vừa trên iPhone 6,1 inch: 338 × 158 điểm.
  @MainActor
  private func render(_ display: WidgetDisplay, scheme: ColorScheme, size: DynamicTypeSize) throws -> UIImage {
    let view = WidgetContentView(display: display)
      .padding(16)
      .frame(width: 338, height: 158)
      .background(Color.ironlyWidgetBackground)
      .clipShape(RoundedRectangle(cornerRadius: 22))
      .environment(\.colorScheme, scheme)
      .environment(\.dynamicTypeSize, size)
    let renderer = ImageRenderer(content: view)
    renderer.scale = 3
    let traits = UITraitCollection(userInterfaceStyle: scheme == .dark ? .dark : .light)
    var image: UIImage?
    traits.performAsCurrent { image = renderer.uiImage }
    return try XCTUnwrap(image)
  }

  /// Ảnh theo phiên bản iOS của simulator: chữ hệ thống mỗi bản iOS vẽ khác
  /// nhau một chút (ảnh trong repo: iOS 27).
  private var osFolder: String { "ios\(ProcessInfo.processInfo.operatingSystemVersion.majorVersion)" }

  private var snapshotDir: URL {
    URL(fileURLWithPath: #filePath).deletingLastPathComponent()
      .appendingPathComponent("__Snapshots__").appendingPathComponent(osFolder)
  }

  /// So từng điểm ảnh; lệch quá 1% số điểm → lỗi. Chưa có ảnh hoặc đang ghi →
  /// ghi ảnh mới.
  private func compare(_ image: UIImage, name: String, record: Bool) throws -> String? {
    let url = snapshotDir.appendingPathComponent("\(name).png")
    let png = try XCTUnwrap(image.pngData())
    if record || !FileManager.default.fileExists(atPath: url.path) {
      try FileManager.default.createDirectory(at: snapshotDir, withIntermediateDirectories: true)
      try png.write(to: url)
      return record ? nil : "\(name): chưa có ảnh, đã ghi"
    }
    let reference = try XCTUnwrap(UIImage(contentsOfFile: url.path))
    let a = try pixels(image), b = try pixels(reference)
    guard a.width == b.width, a.height == b.height else { return "\(name): khác kích thước" }
    var diff = 0
    for i in stride(from: 0, to: a.data.count, by: 4)
    where zip(a.data[i..<i + 4], b.data[i..<i + 4]).contains(where: { abs(Int($0) - Int($1)) > 8 }) {
      diff += 1
    }
    let ratio = Double(diff) / Double(a.width * a.height)
    if ratio > 0.01 {
      try png.write(to: snapshotDir.appendingPathComponent("\(name).failed.png"))
      return "\(name): lệch \(String(format: "%.2f", ratio * 100))%"
    }
    return nil
  }

  private func pixels(_ image: UIImage) throws -> (width: Int, height: Int, data: [UInt8]) {
    let cg = try XCTUnwrap(image.cgImage)
    let w = cg.width, h = cg.height
    var data = [UInt8](repeating: 0, count: w * h * 4)
    let ctx = try XCTUnwrap(CGContext(
      data: &data, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
      space: CGColorSpaceCreateDeviceRGB(),
      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
    ctx.draw(cg, in: CGRect(x: 0, y: 0, width: w, height: h))
    return (w, h, data)
  }
}
