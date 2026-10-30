import SwiftUI
import XCTest

/// 06 Bản 3 VS39-T08 (Swift): đọc `widget_state.json`, file hỏng / thiếu không
/// crash (ED3-07), timeline 00:00 (TAC3-09), URL theo NAV-15. VS41-T06: thẻ
/// S-71 — `content-state` thiếu trường không crash. 06 Bản 4 VS50-T03: ảnh
/// chụp S-70 × 7, S-71 × 4 + Dynamic Island × 2, cỡ chữ lớn, theo token (màu
/// không đổi theo sáng / tối của máy, TA4-08); vị trí chấm hôm nay (S-70).
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
    guard case .day(let d, let today) = WidgetTimeline.display(f, at: at(13), calendar: calendar) else {
      return XCTFail("phải là ngày có lịch")
    }
    XCTAssertEqual(d.groups, ["Lưng"])
    XCTAssertEqual(d.week.dots, [true, false, false, false])
    XCTAssertEqual(today, 3, "file chỉ có hôm nay (thứ 3) nên hôm nay là chấm cuối")
  }

  /// 04 Bản 4 S-70: viền cam hôm nay — vị trí suy từ các buổi còn lại trong
  /// tuần có trong file; buổi trước đó bỏ qua không làm lệch.
  func testVS50TodayDotFromRemainingSessionsOfWeek() throws {
    // Tuần: thứ 2 (bỏ qua), thứ 3 (hôm nay), thứ 5, thứ 7; chủ nhật và tuần
    // sau không tính.
    let f = try XCTUnwrap(file([
      day("2026-10-13", "Thứ 3", week: week(0, 4)),
      day("2026-10-14", "Thứ 4", kind: "rest", groups: [], time: nil, week: week(0, 4)),
      day("2026-10-15", "Thứ 5", week: week(0, 4)),
      day("2026-10-16", "Thứ 6", kind: "rest", groups: [], time: nil, week: week(0, 4)),
      day("2026-10-17", "Thứ 7", week: week(0, 4)),
      day("2026-10-18", "Chủ nhật", kind: "rest", groups: [], time: nil, week: week(0, 4)),
      day("2026-10-19", "Thứ 2", week: week(0, 4)),
      day("2026-10-20", "Thứ 3", week: week(0, 4)),
    ]))
    guard case .day(_, let today) = WidgetTimeline.display(f, at: at(13), calendar: calendar) else {
      return XCTFail()
    }
    XCTAssertEqual(today, 1)
    let rest = try XCTUnwrap(file([day("2026-10-14", "Thứ 4", kind: "rest", groups: [], time: nil, week: week(1, 4))]))
    guard case .day(_, let none) = WidgetTimeline.display(rest, at: at(14), calendar: calendar) else {
      return XCTFail()
    }
    XCTAssertNil(none, "ngày nghỉ không có chấm hôm nay")
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
    guard case .day(let monday, _) = entries[2].display else { return XCTFail() }
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

  // MARK: - Thẻ màn hình khóa S-71

  private typealias State = IronlySessionAttributes.ContentState

  private func state(_ json: String) throws -> State {
    try JSONDecoder().decode(State.self, from: Data(json.utf8))
  }

  func testVS41T06ContentStateDecodesWithMissingFields() throws {
    let full = try state(
      #"{"lastLogged":{"name":"Máy ép ngực","lift":"40 → 47,5 kg"},"next":{"name":"Nằm ghế ngang đẩy thanh tạ","prev":"50 → 55 kg"},"allLogged":false,"absOnly":false}"#)
    XCTAssertEqual(ActivityText.lastLogged(full), "Máy ép ngực · 40 → 47,5 kg")
    XCTAssertEqual(ActivityText.next(full), "Nằm ghế ngang đẩy thanh tạ · 50 → 55 kg")
    XCTAssertEqual(ActivityText.compact(full), "→ 50 → 55 kg")

    let empty = try state("{}")
    XCTAssertEqual(ActivityText.lastLogged(empty), "Chưa ghi bài nào")
    XCTAssertEqual(ActivityText.next(empty), "Đã ghi hết bài")
    XCTAssertFalse(empty.absOnly)

    let broken = try state(#"{"lastLogged":{"name":1},"next":{"name":"Máy ép ngực"},"absOnly":"x","extra":true}"#)
    XCTAssertNil(broken.lastLogged)
    XCTAssertEqual(ActivityText.next(broken), "Máy ép ngực · Buổi trước: chưa ghi")
    XCTAssertEqual(ActivityText.compact(broken), "→")
    XCTAssertFalse(broken.allLogged)
    XCTAssertFalse(broken.absOnly)
  }

  func testNAV16ActivityOpensTodaySession() {
    XCTAssertEqual(IronlySessionActivity.url.absoluteString, "ironly://session/today")
  }

  private var activityStates: [(String, String, State)] {
    let lift = State.Lift(name: "Máy ép ngực", lift: "40 → 47,5 kg")
    return [
      ("logging", "Ngực", State(
        lastLogged: lift, next: .init(name: "Nằm ghế ngang đẩy thanh tạ", prev: "50 → 55 kg"),
        allLogged: false, absOnly: false)),
      ("nothing_logged", "Ngực + Tay sau", State(
        lastLogged: nil, next: .init(name: "Máy ép ngực", prev: nil), allLogged: false, absOnly: false)),
      ("all_logged", "Ngực", State(lastLogged: lift, next: nil, allLogged: true, absOnly: false)),
      ("abs_only", "Bụng", State(lastLogged: nil, next: nil, allLogged: false, absOnly: true)),
    ]
  }

  @MainActor
  func testActivitySnapshots() throws {
    let firstRun = !FileManager.default.fileExists(
      atPath: snapshotDir.appendingPathComponent("s71_logging.png").path)
    let recording = firstRun || ProcessInfo.processInfo.environment["SNAPSHOT_RECORD"] == "1"
    var failures: [String] = []
    for (name, groups, state) in activityStates {
      for (variant, size) in [("", DynamicTypeSize.large), ("_maxtext", DynamicTypeSize.accessibility3)] {
        let card = LockScreenActivityView(groups: groups, state: state)
          .frame(width: 361)
          .background(Tokens.color.surface)
          .clipShape(RoundedRectangle(cornerRadius: 22))
        let image = try snapshot(card, scheme: .dark, size: size)
        if let problem = try compare(image, name: "s71_\(name)\(variant)", record: recording) {
          failures.append(problem)
        }
        // TA4-08: màu theo token, máy đặt sáng vẽ y hệt.
        let light = try snapshot(card, scheme: .light, size: size)
        XCTAssertEqual(light.pngData(), image.pngData(), "\(name)\(variant): sáng / tối phải như nhau")
      }
    }
    // Dynamic Island: nền đen, máy sáng hay tối vẽ như nhau.
    let (_, groups, logging) = activityStates[0]
    let islands: [(String, AnyView)] = [
      ("compact", AnyView(HStack {
        IslandCompactLeading(groups: groups)
        Spacer(minLength: 24)
        IslandCompactTrailing(state: logging)
      }.padding(.horizontal, 18).frame(width: 250, height: 37).background(Color.black)
        .clipShape(Capsule()))),
      ("expanded", AnyView(IslandExpandedView(groups: groups, state: logging)
        .padding(24).frame(width: 371).background(Color.black)
        .clipShape(RoundedRectangle(cornerRadius: 44)))),
    ]
    for (name, island) in islands {
      let light = try snapshot(island, scheme: .light, size: .large)
      let dark = try snapshot(island, scheme: .dark, size: .large)
      XCTAssertEqual(light.pngData(), dark.pngData(), "\(name): sáng / tối phải như nhau")
      if let problem = try compare(dark, name: "s71_island_\(name)", record: recording) {
        failures.append(problem)
      }
    }
    XCTAssertTrue(failures.isEmpty, failures.joined(separator: "\n"))
    if firstRun { throw XCTSkip("chưa có ảnh S-71 cho \(osFolder): đã ghi, chưa so") }
  }

  /// Vẽ nội dung thẻ do app tính ở từng bước demo (`DEMO_ACTIVITY_DIR`, file
  /// `{"groups": …, "state": content-state}`): simulator không bật được thẻ
  /// bằng push (05 Bản 3 TA3-15). Không đặt biến thì bỏ qua.
  @MainActor
  func testRenderDemoActivities() throws {
    guard let dir = ProcessInfo.processInfo.environment["DEMO_ACTIVITY_DIR"] else {
      throw XCTSkip("chỉ dùng khi demo")
    }
    struct Demo: Decodable {
      let groups: String
      let state: State
    }
    let url = URL(fileURLWithPath: dir)
    for json in try FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: nil)
    where json.pathExtension == "json" {
      let demo = try JSONDecoder().decode(Demo.self, from: Data(contentsOf: json))
      let card = LockScreenActivityView(groups: demo.groups, state: demo.state)
        .frame(width: 361)
        .background(Tokens.color.surface)
        .clipShape(RoundedRectangle(cornerRadius: 22))
      let cardPng = try XCTUnwrap(try snapshot(card, scheme: .dark, size: .large).pngData())
      try cardPng.write(to: json.deletingPathExtension().appendingPathExtension("png"))
      let island = IslandExpandedView(groups: demo.groups, state: demo.state)
        .padding(24).frame(width: 371).background(Color.black)
        .clipShape(RoundedRectangle(cornerRadius: 44))
      let png = try XCTUnwrap(try snapshot(island, scheme: .dark, size: .large).pngData())
      try png.write(to: json.deletingPathExtension().appendingPathExtension("island.png"))
    }
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
    let firstRun = !FileManager.default.fileExists(
      atPath: snapshotDir.appendingPathComponent("s70_not_done.png").path)
    let recording = firstRun || ProcessInfo.processInfo.environment["SNAPSHOT_RECORD"] == "1"
    var failures: [String] = []
    for (name, display) in try states() {
      for (variant, size) in [("", DynamicTypeSize.large), ("_maxtext", DynamicTypeSize.accessibility3)] {
        let image = try render(display, scheme: .dark, size: size)
        if let problem = try compare(image, name: "s70_\(name)\(variant)", record: recording) {
          failures.append(problem)
        }
        // TA4-08: màu theo token, máy đặt sáng vẽ y hệt.
        let light = try render(display, scheme: .light, size: size)
        XCTAssertEqual(light.pngData(), image.pngData(), "\(name)\(variant): sáng / tối phải như nhau")
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
      let png = try XCTUnwrap(try render(display, scheme: .dark, size: .large).pngData())
      try png.write(to: json.deletingPathExtension().appendingPathExtension("png"))
    }
  }

  /// Cỡ vừa trên iPhone 6,1 inch: 338 × 158 điểm.
  @MainActor
  private func render(_ display: WidgetDisplay, scheme: ColorScheme, size: DynamicTypeSize) throws -> UIImage {
    try snapshot(
      WidgetContentView(display: display)
        .padding(16)
        .frame(width: 338, height: 158)
        .background(Tokens.color.bg)
        .clipShape(RoundedRectangle(cornerRadius: 22)),
      scheme: scheme, size: size)
  }

  @MainActor
  private func snapshot(_ content: some View, scheme: ColorScheme, size: DynamicTypeSize) throws -> UIImage {
    let view = content
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
