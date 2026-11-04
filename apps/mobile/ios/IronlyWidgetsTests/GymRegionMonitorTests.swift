import CoreLocation
import XCTest

/// 06 Bản 5 VS58-T06 (Swift): `GymRegionMonitor` với `CLLocationManager` giả —
/// theo dõi đúng một vùng 150 m chỉ báo khi vào (TD5-01, AP-18), vào vùng →
/// hàng chờ (ngày, giờ, không tọa độ) → báo cầu, một lần mỗi ngày; quyền hai
/// bước "Khi dùng app" → "Luôn luôn" (TA5-08, FC5-11); lấy vị trí ≤ 50 m trong
/// 15 giây (05 Bản 5 §6.4.6, F32-R3).
final class GymRegionMonitorTests: XCTestCase {
  private var manager: FakeLocationManager!
  private var defaults: UserDefaults!
  private var timers: [() -> Void] = []
  private var clock = Date()

  override func setUp() {
    manager = FakeLocationManager()
    defaults = UserDefaults(suiteName: "GymRegionMonitorTests")!
    defaults.removePersistentDomain(forName: "GymRegionMonitorTests")
    timers = []
    clock = local(2026, 11, 4, 17, 20)
  }

  private func local(_ y: Int, _ m: Int, _ d: Int, _ h: Int, _ min: Int) -> Date {
    Calendar.current.date(
      from: DateComponents(year: y, month: m, day: d, hour: h, minute: min))!
  }

  private func monitor() -> GymRegionMonitor {
    GymRegionMonitor(
      manager: manager, defaults: defaults, now: { [unowned self] in self.clock },
      schedule: { [unowned self] _, work in self.timers.append(work) })
  }

  private func fix(_ accuracy: CLLocationAccuracy) -> CLLocation {
    CLLocation(
      coordinate: CLLocationCoordinate2D(latitude: 10.7701234, longitude: 106.6904567),
      altitude: 0, horizontalAccuracy: accuracy, verticalAccuracy: 5, timestamp: clock)
  }

  func testStartMonitorsOneEntryOnlyRegionAndStopRemovesIt() {
    let m = monitor()
    m.start(latitude: 10.77, longitude: 106.69)
    m.start(latitude: 10.78, longitude: 106.70)
    XCTAssertEqual(manager.monitoredRegions.count, 1)
    let region = manager.monitoredRegions.first as! CLCircularRegion
    XCTAssertEqual(region.identifier, GymRegionMonitor.regionId)
    XCTAssertEqual(region.radius, 150)
    XCTAssertEqual(region.center.latitude, 10.78, accuracy: 1e-9)
    XCTAssertTrue(region.notifyOnEntry)
    XCTAssertFalse(region.notifyOnExit)
    XCTAssertTrue(m.isMonitoring)
    m.stop()
    XCTAssertTrue(manager.monitoredRegions.isEmpty)
    XCTAssertFalse(m.isMonitoring)
  }

  func testEntryQueuesDateAndTimeOncePerDayAndNotifiesBridge() {
    let m = monitor()
    var sent: [GymArrival] = []
    m.onArrival = { sent.append($0) }
    m.start(latitude: 10.77, longitude: 106.69)
    let region = manager.monitoredRegions.first!
    m.entered(region)
    clock = local(2026, 11, 4, 18, 30)
    m.entered(region)
    m.entered(
      CLCircularRegion(center: CLLocationCoordinate2D(), radius: 10, identifier: "other"))
    XCTAssertEqual(sent, [GymArrival(date: "2026-11-04", localTime: "17:20")])
    // Ứng dụng vừa được iOS mở ở nền: hàng chờ còn trong UserDefaults.
    XCTAssertEqual(monitor().queued(), sent)
    XCTAssertEqual(m.takeArrivals(), sent)
    XCTAssertTrue(m.takeArrivals().isEmpty)
    clock = local(2026, 11, 5, 7, 5)
    m.entered(region)
    XCTAssertEqual(sent.last, GymArrival(date: "2026-11-05", localTime: "07:05"))
    // Không có tọa độ trong sự kiện gửi Dart.
    XCTAssertEqual(Set(sent.last!.asMap.keys), ["date", "localTime"])
    m.stop()
    XCTAssertTrue(m.queued().isEmpty)
  }

  func testRestoredRegionWithoutPermissionAsksTwoStepsThenMonitors() {
    // Máy mới: vị trí đồng bộ về, chưa có quyền (F32-AC6, FC5-11).
    let m = monitor()
    m.start(latitude: 10.77, longitude: 106.69)
    XCTAssertEqual(manager.calls, ["whenInUse"])
    manager.status = .authorizedWhenInUse
    m.authorizationChanged()
    XCTAssertEqual(manager.calls, ["whenInUse", "always"])
    manager.monitoredRegions = []  // iOS từ chối vùng khi chưa có "Luôn luôn".
    manager.status = .authorizedAlways
    m.authorizationChanged()
    XCTAssertTrue(m.isMonitoring)
    // Từ chối: không hỏi lại (F32-R5); đã dừng thì không đặt lại vùng.
    m.stop()
    manager.calls = []
    m.authorizationChanged()
    XCTAssertTrue(manager.calls.isEmpty)
    XCTAssertFalse(m.isMonitoring)
  }

  /// Kết quả `requestFix`: đã gọi chưa, tọa độ (nil = không lấy được).
  private final class Fix {
    var called = false
    var coordinate: CLLocationCoordinate2D?
    func handler(_ c: CLLocationCoordinate2D?) {
      called = true
      coordinate = c
    }
  }

  func testTwoStepPermissionThenFixWithin50m() {
    let m = monitor()
    let fix1 = Fix()
    m.requestFix(fix1.handler)
    XCTAssertEqual(manager.calls, ["whenInUse"])
    manager.status = .authorizedWhenInUse
    m.authorizationChanged()
    XCTAssertEqual(manager.calls, ["whenInUse", "always", "location"])
    m.received([fix(120)])
    XCTAssertFalse(fix1.called, "chưa đủ chính xác: lấy lại")
    XCTAssertEqual(manager.calls.last, "location")
    m.received([fix(12)])
    XCTAssertTrue(fix1.called)
    XCTAssertEqual(fix1.coordinate?.latitude ?? 0, 10.7701234, accuracy: 1e-9)
    XCTAssertEqual(fix1.coordinate?.longitude ?? 0, 106.6904567, accuracy: 1e-9)
    // Hết giờ sau khi đã có vị trí: không gọi lại.
    fix1.called = false
    timers.forEach { $0() }
    XCTAssertFalse(fix1.called)
  }

  func testDeniedOrTimeoutGivesNoFix() {
    manager.status = .denied
    let m = monitor()
    let denied = Fix()
    m.requestFix(denied.handler)
    XCTAssertTrue(denied.called)
    XCTAssertNil(denied.coordinate)
    XCTAssertEqual(m.authorization, "denied")

    manager.status = .authorizedAlways
    let timedOut = Fix()
    m.requestFix(timedOut.handler)
    XCTAssertEqual(m.authorization, "always")
    m.failed(CLError(.locationUnknown))
    XCTAssertFalse(timedOut.called)
    timers.last!()
    XCTAssertTrue(timedOut.called)
    XCTAssertNil(timedOut.coordinate)
  }
}

/// `CLLocationManager` giả: ghi lại các lần xin quyền / lấy vị trí, giữ vùng.
final class FakeLocationManager: GymLocationManaging {
  weak var delegate: CLLocationManagerDelegate?
  var desiredAccuracy: CLLocationAccuracy = kCLLocationAccuracyHundredMeters
  var status: CLAuthorizationStatus = .notDetermined
  var authorizationStatus: CLAuthorizationStatus { status }
  var monitoredRegions: Set<CLRegion> = []
  var maximumRegionMonitoringDistance: CLLocationDistance = 1000
  var calls: [String] = []

  func requestWhenInUseAuthorization() { calls.append("whenInUse") }
  func requestAlwaysAuthorization() { calls.append("always") }
  func requestLocation() { calls.append("location") }
  func startMonitoring(for region: CLRegion) { monitoredRegions.insert(region) }
  func stopMonitoring(for region: CLRegion) { monitoredRegions.remove(region) }
}
