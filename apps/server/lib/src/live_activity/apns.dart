import 'package:api_contract/api_contract.dart';

/// Một push `liveactivity` (05 Bản 3 TD3-10, §6.9.2, §6.9.3).
final class ApnsPush {
  const ApnsPush({
    required this.token,
    required this.environment,
    required this.payload,
  });

  final String token;
  final ApnsEnvironment environment;
  final Map<String, Object?> payload;
}

/// Kết quả gửi theo cách job xử lý (§6.9.4).
enum ApnsOutcome {
  /// 200.
  sent,

  /// 410 Unregistered hoặc 400 BadDeviceToken: xóa token.
  invalidToken,

  /// 429, 5xx, lỗi mạng: thử lại phút sau.
  retry,

  /// 4xx khác: lỗi cấu hình / nội dung; ghi lỗi, thử lại như [retry].
  rejected,
}

final class ApnsResult {
  const ApnsResult(this.outcome, {this.status, this.reason});

  static const ok = ApnsResult(ApnsOutcome.sent, status: 200);

  final ApnsOutcome outcome;
  final int? status;

  /// `reason` của APNs (`Unregistered`, `BadDeviceToken`…) hoặc mô tả lỗi mạng.
  final String? reason;

  /// Ghi vào `live_activity_sessions.last_error`, log.
  String get error => [?status?.toString(), ?reason].join(' ');
}

/// Cổng gửi APNs; test và local dùng `FakeApns` (06 Bản 3 IA3-10).
abstract interface class Apns {
  Future<ApnsResult> send(ApnsPush push);

  Future<void> close();
}
