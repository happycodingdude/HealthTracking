import ActivityKit
import Flutter
import WidgetKit

/// Cầu Flutter ↔ Swift (05 Bản 3 TD3-02, 06 Bản 3 ED3-06): channel
/// `dev.antonnguyen.ironly/native`, phía Dart là `native_bridge.dart`.
/// App chỉ cập nhật và tắt thẻ màn hình khóa; bật thẻ chỉ server (ED3-09).
enum NativeBridge {
  static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: "dev.antonnguyen.ironly/native", binaryMessenger: registrar.messenger())
    channel.setMethodCallHandler { call, result in
      if call.method.hasPrefix("liveActivity.") {
        return LiveActivities.handle(call, result: result)
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
    FlutterEventChannel(
      name: "dev.antonnguyen.ironly/native/events", binaryMessenger: registrar.messenger()
    ).setStreamHandler(LiveActivities.events)
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
