import 'package:domain/domain.dart';

import 'codecs.dart';
import 'json_reader.dart';

/// Cổng APNs của token thẻ (05 Bản 3 TA3-14): bản dev → sandbox.
enum ApnsEnvironment {
  production,
  sandbox;

  static ApnsEnvironment? tryParse(String value) {
    for (final e in values) {
      if (e.name == value) return e;
    }
    return null;
  }
}

/// `PUT /v1/me/live-activity-token` (05 Bản 3 §6.12, TD3-11): push-to-start
/// token của thẻ màn hình khóa và (khi thẻ đang hiện) token cập nhật của thẻ
/// ngày [activityDate]. Server chỉ giữ bản mới nhất mỗi tài khoản (TA3-12).
final class LiveActivityTokenRequest {
  const LiveActivityTokenRequest({
    required this.pushToStartToken,
    this.activityPushToken,
    this.activityDate,
    required this.environment,
    required this.appVersion,
  });

  factory LiveActivityTokenRequest.fromJson(Object? json) {
    final r = JsonReader(json);
    String hexOf(String key, String value) {
      if (!_token.hasMatch(value)) throw ContractFormatException(key);
      return value;
    }

    final activityPushToken = r.optString('activityPushToken');
    final environment = ApnsEnvironment.tryParse(r.string('environment'));
    if (environment == null) {
      throw const ContractFormatException('environment');
    }
    final appVersion = r.string('appVersion');
    if (appVersion.isEmpty || appVersion.length > 32) {
      throw const ContractFormatException('appVersion');
    }
    return LiveActivityTokenRequest(
      pushToStartToken: hexOf('pushToStartToken', r.string('pushToStartToken')),
      activityPushToken: activityPushToken == null
          ? null
          : hexOf('activityPushToken', activityPushToken),
      activityDate: r.optString('activityDate') == null
          ? null
          : r.decoded('activityDate', DateCodec.decode),
      environment: environment,
      appVersion: appVersion,
    );
  }

  /// Token APNs: chuỗi hex.
  static final _token = RegExp(r'^[0-9a-fA-F]{16,512}$');

  final String pushToStartToken;
  final String? activityPushToken;
  final LocalDate? activityDate;
  final ApnsEnvironment environment;
  final String appVersion;

  Map<String, Object?> toJson() => {
    'pushToStartToken': pushToStartToken,
    'activityPushToken': ?activityPushToken,
    if (activityDate case final d?) 'activityDate': DateCodec.encode(d),
    'environment': environment.name,
    'appVersion': appVersion,
  };
}
