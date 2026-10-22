import Flutter
import WidgetKit

/// Cầu Flutter ↔ Swift (05 Bản 3 TD3-02, 06 Bản 3 ED3-06): channel
/// `dev.antonnguyen.ironly/native`, phía Dart là `native_bridge.dart`.
/// `liveActivity.*` thêm ở VS-41.
enum NativeBridge {
  static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: "dev.antonnguyen.ironly/native", binaryMessenger: registrar.messenger())
    channel.setMethodCallHandler { call, result in
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
  }
}
