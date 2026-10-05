import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import 'package:url_launcher/url_launcher.dart';

/// Nhắc trên iPhone (TD-16): chỉ thông báo cục bộ, chạy cả khi không có mạng
/// (F04-R5). Test thay bằng bản giả.
abstract interface class NotificationGateway {
  /// Khởi tạo một lần khi app chạy. [onTap] nhận `payload` khi Bạn chạm vào
  /// một nhắc lúc app đang mở hoặc chạy nền (NAV-2).
  Future<void> init({required void Function(String payload) onTap});

  /// iPhone đang cho phép app gửi thông báo.
  Future<bool> isPermitted();

  /// Xin quyền: iPhone chỉ hỏi lần đầu; đã từ chối trước đó thì trả false ngay.
  Future<bool> requestPermission();

  Future<void> cancelAll();

  /// Hẹn một nhắc lúc [at] (giờ trên iPhone).
  Future<void> schedule({
    required int id,
    required DateTime at,
    required String body,
    required String payload,
  });

  /// Múi giờ IANA của iPhone (lưu vào hồ sơ).
  Future<String> timezone();

  /// Mở trang Cài đặt của app trong Cài đặt iPhone (F04-E2).
  Future<void> openSettings();
}

final class LocalNotificationGateway implements NotificationGateway {
  final _plugin = FlutterLocalNotificationsPlugin();

  IOSFlutterLocalNotificationsPlugin? get _ios => _plugin
      .resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin
      >();

  @override
  Future<void> init({required void Function(String payload) onTap}) async {
    tzdata.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation(await timezone()));
    await _plugin.initialize(
      settings: const InitializationSettings(
        // Không tự xin quyền lúc khởi động: chỉ xin ở S-06 / công tắc S-50.
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
      onDidReceiveNotificationResponse: (r) => onTap(r.payload ?? ''),
    );
  }

  @override
  Future<bool> isPermitted() async =>
      (await _ios?.checkPermissions())?.isEnabled ?? false;

  @override
  Future<bool> requestPermission() async =>
      await _ios?.requestPermissions(alert: true, sound: true) ?? false;

  @override
  Future<void> cancelAll() => _plugin.cancelAll();

  @override
  Future<void> schedule({
    required int id,
    required DateTime at,
    required String body,
    required String payload,
  }) => _plugin.zonedSchedule(
    id: id,
    scheduledDate: tz.TZDateTime.from(at, tz.local),
    notificationDetails: const NotificationDetails(
      iOS: DarwinNotificationDetails(presentAlert: true, presentSound: true),
    ),
    androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    body: body,
    payload: payload,
  );

  @override
  Future<String> timezone() async =>
      (await FlutterTimezone.getLocalTimezone()).identifier;

  @override
  Future<void> openSettings() async {
    await launchUrl(Uri.parse('app-settings:'));
  }
}
