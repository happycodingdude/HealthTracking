import 'package:mobile/data/notifications/notification_gateway.dart';

/// Một nhắc đã hẹn trong bản giả.
typedef FakeScheduled = ({int id, DateTime at, String body, String payload});

/// NotificationGateway giả: ghi lại các nhắc đã hẹn, quyền lập trình được.
final class FakeNotificationGateway implements NotificationGateway {
  FakeNotificationGateway({this.permitted = true, this.grantOnRequest = true});

  /// iPhone đang cho phép thông báo.
  bool permitted;

  /// Kết quả khi app xin quyền (Bạn đồng ý hay từ chối).
  bool grantOnRequest;
  int requests = 0;
  int settingsOpened = 0;
  final scheduled = <FakeScheduled>[];
  void Function(String payload)? onTap;

  @override
  Future<void> init({required void Function(String payload) onTap}) async =>
      this.onTap = onTap;

  @override
  Future<bool> isPermitted() async => permitted;

  @override
  Future<bool> requestPermission() async {
    requests++;
    if (grantOnRequest) permitted = true;
    return permitted;
  }

  @override
  Future<void> cancelAll() async => scheduled.clear();

  @override
  Future<void> schedule({
    required int id,
    required DateTime at,
    required String body,
    required String payload,
  }) async => scheduled.add((id: id, at: at, body: body, payload: payload));

  @override
  Future<String> timezone() async => 'Asia/Ho_Chi_Minh';

  @override
  Future<void> openSettings() async => settingsOpened++;
}
