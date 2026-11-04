import ActivityKit
import UIKit
import Flutter
import WidgetKit

/// Cầu Flutter ↔ Swift (05 Bản 3 TD3-02, 06 Bản 3 ED3-06): channel
/// `dev.antonnguyen.ironly/native`, phía Dart là `native_bridge.dart` và
/// `gym_region_bridge.dart` (Bản 5).
/// App chỉ cập nhật và tắt thẻ màn hình khóa; bật thẻ chỉ server (ED3-09).
enum NativeBridge {
  /// [background] = engine nền của `GymBackgroundRunner` (không màn hình): không
  /// nghe token thẻ; `gym.arrivalHandled` tắt chính engine đó.
  static func register(with registrar: FlutterPluginRegistrar, background: Bool = false) {
    let channel = FlutterMethodChannel(
      name: "dev.antonnguyen.ironly/native", binaryMessenger: registrar.messenger())
    channel.setMethodCallHandler { call, result in
      if call.method.hasPrefix("liveActivity.") {
        return LiveActivities.handle(call, result: result)
      }
      if call.method.hasPrefix("gym.") {
        return GymRegionChannel.handle(call, result: result, background: background)
      }
      do {
        switch call.method {
        case "writeWidgetState":
          guard let json = call.arguments as? String else {
            return result(FlutterError(code: "bad_args", message: nil, details: nil))
          }
          try SharedState.writeWidgetState(json)
          result(nil)
        case "reloadWidgets":
          WidgetCenter.shared.reloadAllTimelines()
          result(nil)
        case "appGroupClear":
          try SharedState.clear()
          result(nil)
        default:
          result(FlutterMethodNotImplemented)
        }
      } catch {
        result(FlutterError(code: "app_group", message: "\(error)", details: nil))
      }
    }
    if !background {
      FlutterEventChannel(
        name: "dev.antonnguyen.ironly/native/events", binaryMessenger: registrar.messenger()
      ).setStreamHandler(LiveActivities.events)
    }
    GymRegionChannel.attach(channel)
  }
}

/// iOS mở app ở nền khi Bạn bước vào vùng phòng gym (05 Bản 5 §6.4.6, TA5-07).
/// App dùng UIScene: lần mở ở nền không kết nối màn hình nên engine Flutter của
/// app không chạy. Runner này giữ thời gian chạy nền (≤ [timeout]) và, khi
/// chưa có engine nào nghe hoặc không có màn hình, chạy engine nền điểm vào
/// `gymArrivalMain` (Dart) để báo server và mở buổi sớm; Dart báo xong bằng
/// `gym.arrivalHandled` (06 Bản 5 VS59-T03). Không gửi tọa độ (AP-18).
final class GymBackgroundRunner {
  static let shared = GymBackgroundRunner()
  /// Tối đa iOS cho khi mở app ở nền vì sự kiện vùng (~30 giây, TA5-07).
  static let timeout: TimeInterval = 25

  private var engine: FlutterEngine?
  private var engineToken = 0
  private var task: UIBackgroundTaskIdentifier = .invalid
  private var generation = 0

  /// Vừa xếp hàng một lần vào vùng.
  func queued(listening: Bool) {
    hold()
    if !listening || UIApplication.shared.connectedScenes.isEmpty {
      startEngine()
    }
  }

  private func hold() {
    guard task == .invalid else { return }
    generation += 1
    let current = generation
    task = UIApplication.shared.beginBackgroundTask(withName: "ironly.gymArrival") {
      [weak self] in self?.finish()
    }
    DispatchQueue.main.asyncAfter(deadline: .now() + Self.timeout) { [weak self] in
      guard let self, self.generation == current else { return }
      self.finish()
    }
  }

  private func startEngine() {
    guard engine == nil else { return }
    let engine = FlutterEngine(name: "ironly.gymArrival", project: nil, allowHeadlessExecution: true)
    // Điểm vào nằm ở `main.dart` (kể cả bản integration test, thư viện gốc khác).
    guard engine.run(withEntrypoint: "gymArrivalMain", libraryURI: "package:mobile/main.dart")
    else { return finish() }
    GeneratedPluginRegistrant.register(with: engine)
    if let registrar = engine.registrar(forPlugin: "IronlyNativeBridge") {
      NativeBridge.register(with: registrar, background: true)
    }
    engineToken = GymRegionChannel.attachCount
    self.engine = engine
  }

  /// Engine app (có màn hình) xử lý xong: chỉ trả thời gian chạy nền.
  func release() {
    guard engine == nil, task != .invalid else { return }
    UIApplication.shared.endBackgroundTask(task)
    task = .invalid
  }

  /// Engine nền xử lý xong hoặc hết giờ: tắt engine nền, trả thời gian chạy nền.
  func finish() {
    if let engine {
      self.engine = nil
      engine.destroyContext()
      GymRegionChannel.detachBackground(token: engineToken)
    }
    if task != .invalid {
      UIApplication.shared.endBackgroundTask(task)
      task = .invalid
    }
  }
}

/// Vị trí phòng gym (05 Bản 5 TD5-01, §6.4.6; 06 Bản 5 VS58-T03): lấy vị trí
/// lúc "Lưu vị trí này", theo dõi / ngừng theo dõi vùng, trạng thái quyền; lần
/// vào vùng gửi sang Dart bằng `gymArrival` (Dart lấy hàng chờ qua
/// `gym.takeArrivals`). Không gửi tọa độ nào ngoài điểm Bạn lưu (AP-18).
enum GymRegionChannel {
  static var monitor: GymRegionMonitor { GymRegionMonitor.shared }

  /// Báo Dart mỗi lần vào vùng; hàng chờ có sẵn (app vừa được iOS mở ở nền)
  /// cũng báo một lần để Dart lấy.
  static func attach(_ channel: FlutterMethodChannel) {
    let before = monitor.onArrival
    monitor.onArrival = { arrival in
      channel.invokeMethod("gymArrival", arguments: arrival.asMap)
    }
    if let first = monitor.queued().first {
      channel.invokeMethod("gymArrival", arguments: first.asMap)
    }
    attachCount += 1
    listenerBefore = before
  }

  /// Số lần một engine gắn cầu (engine nền ghi lại để tháo đúng cầu của nó).
  private(set) static var attachCount = 0
  /// Cầu đang nghe trước lần gắn gần nhất (thường là nil: app đã tắt).
  private static var listenerBefore: ((GymArrival) -> Void)?

  /// Engine nền tắt: trả lại cầu đang nghe trước nó; engine app gắn sau engine
  /// nền ([token] cũ) thì giữ cầu của engine app.
  static func detachBackground(token: Int) {
    guard attachCount == token else { return }
    monitor.onArrival = listenerBefore
    listenerBefore = nil
  }

  static func handle(
    _ call: FlutterMethodCall, result: @escaping FlutterResult, background: Bool = false
  ) {
    let args = call.arguments as? [String: Any]
    switch call.method {
    case "gym.requestLocation":
      monitor.requestFix { coordinate in
        result(coordinate.map { ["lat": $0.latitude, "lng": $0.longitude] })
      }
    case "gym.start":
      guard let lat = args?["lat"] as? Double, let lng = args?["lng"] as? Double else {
        return result(FlutterError(code: "bad_args", message: nil, details: nil))
      }
      let radius = args?["radius"] as? Double ?? GymRegionMonitor.radius
      monitor.start(latitude: lat, longitude: lng, radius: radius)
      result(nil)
    case "gym.stop":
      monitor.stop()
      result(nil)
    case "gym.authorizationStatus":
      result(monitor.authorization)
    case "gym.takeArrivals":
      result(monitor.takeArrivals().map(\.asMap))
    case "gym.arrivalHandled":
      background ? GymBackgroundRunner.shared.finish() : GymBackgroundRunner.shared.release()
      result(nil)
    default:
      result(FlutterMethodNotImplemented)
    }
  }
}

/// Thẻ S-71 phía app (05 Bản 3 §6.4.4): đọc thẻ đang có, cập nhật nội dung tại
/// chỗ, tắt; báo token cho Dart qua EventChannel (TA3-12, TA3-13).
enum LiveActivities {
  typealias Session = Activity<IronlySessionAttributes>

  static let events = TokenStream()

  static func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    let args = call.arguments as? [String: Any]
    switch call.method {
    case "liveActivity.activities":
      result(Session.activities.map(describe))
    case "liveActivity.pushToStartToken":
      result(Session.pushToStartToken.map(hex))
    case "liveActivity.update":
      guard let id = args?["id"] as? String, let json = args?["content"] as? String,
        let state = try? JSONDecoder().decode(
          IronlySessionAttributes.ContentState.self, from: Data(json.utf8))
      else {
        return result(FlutterError(code: "bad_args", message: nil, details: nil))
      }
      Task {
        if let activity = find(id) {
          await activity.update(
            ActivityContent(state: state, staleDate: activity.content.staleDate))
        }
        await MainActor.run { result(nil) }
      }
    case "liveActivity.end":
      guard let id = args?["id"] as? String else {
        return result(FlutterError(code: "bad_args", message: nil, details: nil))
      }
      Task {
        await find(id)?.end(nil, dismissalPolicy: .immediate)
        await MainActor.run { result(nil) }
      }
    case "liveActivity.endAll":
      Task {
        for activity in Session.activities {
          await activity.end(nil, dismissalPolicy: .immediate)
        }
        await MainActor.run { result(nil) }
      }
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  static func find(_ id: String) -> Session? {
    Session.activities.first { $0.id == id }
  }

  static func describe(_ activity: Session) -> [String: Any?] {
    ["id": activity.id, "date": activity.attributes.date, "token": activity.pushToken.map(hex)]
  }

  static func hex(_ data: Data) -> String {
    data.map { String(format: "%02x", $0) }.joined()
  }
}

/// Token push-to-start mới và token cập nhật của từng thẻ (kể cả thẻ server vừa
/// bật lúc app ở nền) → Dart gửi `PUT /v1/me/live-activity-token`.
final class TokenStream: NSObject, FlutterStreamHandler {
  private var tasks: [Task<Void, Never>] = []

  func onListen(withArguments arguments: Any?, eventSink sink: @escaping FlutterEventSink)
    -> FlutterError?
  {
    let send: @Sendable ([String: Any]) async -> Void = { event in
      await MainActor.run { sink(event) }
    }
    tasks.append(
      Task {
        for await token in LiveActivities.Session.pushToStartTokenUpdates {
          await send(["type": "pushToStartToken", "token": LiveActivities.hex(token)])
        }
      })
    tasks.append(
      Task {
        await withTaskGroup(of: Void.self) { group in
          for activity in LiveActivities.Session.activities {
            group.addTask { await Self.watch(activity, send) }
          }
          for await activity in LiveActivities.Session.activityUpdates {
            group.addTask { await Self.watch(activity, send) }
          }
        }
      })
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    tasks.forEach { $0.cancel() }
    tasks = []
    return nil
  }

  private static func watch(
    _ activity: LiveActivities.Session, _ send: @Sendable ([String: Any]) async -> Void
  ) async {
    for await token in activity.pushTokenUpdates {
      await send([
        "type": "activityToken", "id": activity.id, "date": activity.attributes.date,
        "token": LiveActivities.hex(token),
      ])
    }
  }
}
