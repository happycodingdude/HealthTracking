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
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }
}
