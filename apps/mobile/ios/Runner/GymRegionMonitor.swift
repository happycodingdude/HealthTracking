import CoreLocation
import Foundation

/// Phần `CLLocationManager` mà [GymRegionMonitor] dùng; test thay bằng bản giả
/// (06 Bản 5 VS58-T06). Không có hàm theo dõi vị trí liên tục (AP-18, IR5-07).
protocol GymLocationManaging: AnyObject {
  var delegate: CLLocationManagerDelegate? { get set }
  var desiredAccuracy: CLLocationAccuracy { get set }
  var authorizationStatus: CLAuthorizationStatus { get }
  var monitoredRegions: Set<CLRegion> { get }
  var maximumRegionMonitoringDistance: CLLocationDistance { get }
  func requestWhenInUseAuthorization()
  func requestAlwaysAuthorization()
  func requestLocation()
  func startMonitoring(for region: CLRegion)
  func stopMonitoring(for region: CLRegion)
}

extension CLLocationManager: GymLocationManaging {}

/// Một lần vào vùng phòng gym: ngày và giờ trên máy, không tọa độ (AP-18,
/// TR5-04).
struct GymArrival: Codable, Equatable {
  let date: String
  let localTime: String

  var asMap: [String: String] { ["date": date, "localTime": localTime] }
}

/// Theo dõi một vùng tròn quanh phòng gym đã lưu (05 Bản 5 TD5-01, §6.4.6):
/// `CLCircularRegion` 150 m, chỉ báo khi vào vùng. iOS tự giữ vùng qua các lần
/// tắt app, khởi động lại máy, và mở app ở nền khi Bạn bước vào vùng (TA5-07):
/// [shared] được tạo ngay trong `didFinishLaunching` để nhận sự kiện đó.
///
/// Sự kiện vào vùng được ghi vào hàng chờ trong UserDefaults (mỗi ngày giữ lần
/// vào sớm nhất) rồi báo [onArrival]; Dart lấy hàng chờ bằng [takeArrivals]
/// khi cầu Flutter sẵn sàng, nên không mất sự kiện khi app vừa được iOS mở ở
/// nền.
///
/// Lấy vị trí lúc "Lưu vị trí này" (F32-R2) dùng `requestLocation()` (một lần);
/// quyền xin hai bước "Khi dùng app" → "Luôn luôn" (TA5-08, FC5-11).
final class GymRegionMonitor: NSObject, CLLocationManagerDelegate {
  static let regionId = "ironly.gym"
  /// Bán kính vùng (TA5-01; OQ5-22: đổi hằng này nếu cần).
  static let radius: CLLocationDistance = 150
  /// Độ chính xác tối thiểu của vị trí lưu (05 Bản 5 §6.4.6).
  static let accuracyLimit: CLLocationAccuracy = 50
  /// Chờ vị trí tối đa (05 Bản 5 §6.4.6).
  static let fixTimeout: TimeInterval = 15
  static let queueKey = "ironly.gymArrivals"

  static let shared = GymRegionMonitor()

  /// Kết quả lấy vị trí: (vĩ độ, kinh độ) hoặc nil khi không lấy được.
  typealias FixHandler = (CLLocationCoordinate2D?) -> Void

  private let manager: GymLocationManaging
  private let defaults: UserDefaults
  private let now: () -> Date
  private let schedule: (TimeInterval, @escaping () -> Void) -> Void

  /// Gọi trên luồng chính mỗi khi có lần vào vùng mới được xếp hàng.
  var onArrival: ((GymArrival) -> Void)?

  /// Gọi sau mỗi lần xếp hàng, kèm "đã có cầu Flutter nghe" (`onArrival`):
  /// app giữ thời gian chạy nền và, khi chưa có ai nghe (app được iOS mở ở nền
  /// lúc đã tắt hẳn), chạy engine nền xử lý hàng chờ (06 Bản 5 VS59-T03).
  var onQueued: ((_ listening: Bool) -> Void)?

  private var pending: [FixHandler] = []
  private var fixGeneration = 0
  private var waitingAuthorization = false
  /// Vùng cần theo dõi (để đặt lại khi quyền vừa được cấp).
  private var wanted: (latitude: Double, longitude: Double, radius: CLLocationDistance)?
  /// Đang chờ "Khi dùng app" để xin tiếp "Luôn luôn" (máy mới, F32-AC6).
  private var upgradeToAlways = false

  init(
    manager: GymLocationManaging = CLLocationManager(),
    defaults: UserDefaults = .standard,
    now: @escaping () -> Date = Date.init,
    schedule: @escaping (TimeInterval, @escaping () -> Void) -> Void = { delay, work in
      DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
    }
  ) {
    self.manager = manager
    self.defaults = defaults
    self.now = now
    self.schedule = schedule
    super.init()
    manager.delegate = self
    manager.desiredAccuracy = kCLLocationAccuracyBest
  }

  // MARK: - Quyền

  /// "always" | "whenInUse" | "denied" | "notDetermined" (F32-R5, S-77).
  var authorization: String {
    switch manager.authorizationStatus {
    case .authorizedAlways: return "always"
    case .authorizedWhenInUse: return "whenInUse"
    case .notDetermined: return "notDetermined"
    default: return "denied"
    }
  }

  // MARK: - Lấy vị trí hiện tại (Lưu vị trí này)

  /// Xin quyền nếu cần rồi lấy một vị trí ≤ 50 m trong 15 giây; nil khi bị từ
  /// chối, tắt dịch vụ vị trí hoặc hết giờ (F32-R3).
  func requestFix(_ done: @escaping FixHandler) {
    pending.append(done)
    if pending.count > 1 { return }
    fixGeneration += 1
    let generation = fixGeneration
    schedule(Self.fixTimeout) { [weak self] in
      guard let self, self.fixGeneration == generation else { return }
      self.finish(nil)
    }
    proceed()
  }

  private func proceed() {
    guard !pending.isEmpty else { return }
    switch manager.authorizationStatus {
    case .notDetermined:
      waitingAuthorization = true
      manager.requestWhenInUseAuthorization()
    case .authorizedWhenInUse:
      // Bước hai: iOS hỏi "Luôn cho phép"; vị trí lấy ngay với quyền hiện có.
      manager.requestAlwaysAuthorization()
      manager.requestLocation()
    case .authorizedAlways:
      manager.requestLocation()
    default:
      finish(nil)
    }
  }

  private func finish(_ coordinate: CLLocationCoordinate2D?) {
    let handlers = pending
    pending = []
    waitingAuthorization = false
    fixGeneration += 1
    handlers.forEach { $0(coordinate) }
  }

  func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
    authorizationChanged()
  }

  /// Tách khỏi delegate để test gọi được với bản giả.
  func authorizationChanged() {
    let status = manager.authorizationStatus
    guard status != .notDetermined else { return }
    if upgradeToAlways {
      upgradeToAlways = false
      if status == .authorizedWhenInUse { manager.requestAlwaysAuthorization() }
    }
    // Quyền vừa được cấp: đặt lại vùng (lần đặt trước có thể đã bị iOS từ chối).
    if status == .authorizedAlways, let w = wanted {
      addRegion(w.latitude, w.longitude, w.radius)
    }
    guard waitingAuthorization else { return }
    waitingAuthorization = false
    proceed()
  }

  func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
    received(locations)
  }

  func received(_ locations: [CLLocation]) {
    guard !pending.isEmpty else { return }
    if let fix = locations.last(where: {
      $0.horizontalAccuracy >= 0 && $0.horizontalAccuracy <= Self.accuracyLimit
    }) {
      return finish(fix.coordinate)
    }
    // Chưa đủ chính xác: lấy lại đến khi hết giờ.
    manager.requestLocation()
  }

  func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
    failed(error)
  }

  func failed(_ error: Error) {
    guard !pending.isEmpty else { return }
    if (error as? CLError)?.code == .locationUnknown {
      manager.requestLocation()
    } else {
      finish(nil)
    }
  }

  // MARK: - Theo dõi vùng

  /// Theo dõi vùng tròn [radius] quanh điểm đã lưu; thay vùng cũ (F32-R1).
  /// Chưa có quyền (máy mới khôi phục vị trí, F32-AC6): iPhone hỏi quyền lúc
  /// này, hai bước như khi lưu (FC5-11); bị từ chối thì thôi, không nhắc lại
  /// (F32-R5).
  func start(latitude: Double, longitude: Double, radius: CLLocationDistance = radius) {
    wanted = (latitude, longitude, radius)
    switch manager.authorizationStatus {
    case .notDetermined:
      upgradeToAlways = true
      manager.requestWhenInUseAuthorization()
    case .authorizedWhenInUse:
      manager.requestAlwaysAuthorization()
    default:
      break
    }
    addRegion(latitude, longitude, radius)
  }

  private func addRegion(
    _ latitude: Double, _ longitude: Double, _ radius: CLLocationDistance
  ) {
    stopRegions()
    let region = CLCircularRegion(
      center: CLLocationCoordinate2D(latitude: latitude, longitude: longitude),
      radius: min(radius, manager.maximumRegionMonitoringDistance),
      identifier: Self.regionId)
    region.notifyOnEntry = true
    region.notifyOnExit = false
    manager.startMonitoring(for: region)
  }

  /// Ngừng theo dõi (tắt công tắc, xóa vị trí, đăng xuất) và bỏ hàng chờ.
  func stop() {
    wanted = nil
    upgradeToAlways = false
    stopRegions()
    defaults.removeObject(forKey: Self.queueKey)
  }

  var isMonitoring: Bool {
    manager.monitoredRegions.contains { $0.identifier == Self.regionId }
  }

  private func stopRegions() {
    for region in manager.monitoredRegions where region.identifier == Self.regionId {
      manager.stopMonitoring(for: region)
    }
  }

  func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
    entered(region)
  }

  /// Vào vùng phòng gym: xếp hàng (ngày, giờ trên máy) rồi báo Dart.
  func entered(_ region: CLRegion) {
    guard region.identifier == Self.regionId else { return }
    let at = now()
    let date = Self.format(at, "yyyy-MM-dd")
    let arrival = GymArrival(date: date, localTime: Self.format(at, "HH:mm"))
    var queue = queued()
    // Mỗi ngày giữ lần vào sớm nhất (mốc mở buổi sớm, FD5-01).
    guard !queue.contains(where: { $0.date == date }) else { return }
    queue.append(arrival)
    save(queue)
    onArrival?(arrival)
    onQueued?(onArrival != nil)
  }

  func locationManager(
    _ manager: CLLocationManager, monitoringDidFailFor region: CLRegion?, withError error: Error
  ) {
    // Không có quyền "Luôn luôn" hoặc iOS từ chối: thẻ chỉ theo giờ, app không
    // báo gì (F32-R5).
  }

  // MARK: - Hàng chờ

  /// Lấy và xóa các lần vào vùng chưa giao cho Dart.
  func takeArrivals() -> [GymArrival] {
    let queue = queued()
    defaults.removeObject(forKey: Self.queueKey)
    return queue
  }

  func queued() -> [GymArrival] {
    guard let data = defaults.data(forKey: Self.queueKey) else { return [] }
    return (try? JSONDecoder().decode([GymArrival].self, from: data)) ?? []
  }

  private func save(_ queue: [GymArrival]) {
    if let data = try? JSONEncoder().encode(queue) {
      defaults.set(data, forKey: Self.queueKey)
    }
  }

  private static func format(_ date: Date, _ pattern: String) -> String {
    let f = DateFormatter()
    f.locale = Locale(identifier: "en_US_POSIX")
    f.calendar = Calendar(identifier: .gregorian)
    f.timeZone = .current
    f.dateFormat = pattern
    return f.string(from: date)
  }
}
