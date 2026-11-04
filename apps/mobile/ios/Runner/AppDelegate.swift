import Flutter
import UIKit

// Vòng đời UIScene (bắt buộc từ iOS 27): cửa sổ và FlutterViewController do
// FlutterSceneDelegate tạo (Info.plist, UIApplicationSceneManifest); plugin
// đăng ký khi engine ngầm định khởi tạo xong.
@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Nhắc đi tập (flutter_local_notifications): nhận cả khi app đang mở và khi
    // Bạn chạm vào thông báo (NAV-2). Phải đặt trước khi hàm này trả về.
    UNUserNotificationCenter.current().delegate = self as? UNUserNotificationCenterDelegate
    // Vùng phòng gym (05 Bản 5 TD5-01): iOS mở app ở nền khi Bạn vào vùng
    // (`launchOptions[.location]`); delegate phải có ngay để nhận sự kiện,
    // trước khi Flutter chạy. Sự kiện chờ trong hàng tới khi Dart lấy.
    // App đã tắt hẳn → không có engine nghe: engine nền xử lý (VS59-T03).
    GymRegionMonitor.shared.onQueued = { listening in
      GymBackgroundRunner.shared.queued(listening: listening)
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    // Widget, App Group (VS-39); thẻ màn hình khóa (VS-41).
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "IronlyNativeBridge") {
      NativeBridge.register(with: registrar)
    }
  }
}
