import 'codecs.dart';
import 'json_reader.dart';

/// `POST /v1/auth/register` (05 §6.8.2).
final class RegisterRequest {
  const RegisterRequest({
    required this.displayName,
    required this.phone,
    required this.password,
  });

  factory RegisterRequest.fromJson(Object? json) {
    final r = JsonReader(json);
    return RegisterRequest(
      displayName: r.string('displayName'),
      phone: r.string('phone'),
      password: r.string('password'),
    );
  }

  final String displayName;
  final String phone;
  final String password;

  Map<String, Object?> toJson() => {
    'displayName': displayName,
    'phone': phone,
    'password': password,
  };
}

/// `POST /v1/auth/login`.
final class LoginRequest {
  const LoginRequest({required this.phone, required this.password});

  factory LoginRequest.fromJson(Object? json) {
    final r = JsonReader(json);
    return LoginRequest(
      phone: r.string('phone'),
      password: r.string('password'),
    );
  }

  final String phone;
  final String password;

  Map<String, Object?> toJson() => {'phone': phone, 'password': password};
}

/// `POST /v1/auth/refresh`.
final class RefreshRequest {
  const RefreshRequest({required this.refreshToken});

  factory RefreshRequest.fromJson(Object? json) =>
      RefreshRequest(refreshToken: JsonReader(json).string('refreshToken'));

  final String refreshToken;

  Map<String, Object?> toJson() => {'refreshToken': refreshToken};
}

/// Cặp token trả về khi đăng ký, đăng nhập, làm mới (TD-10).
final class TokenPair {
  const TokenPair({
    required this.accessToken,
    required this.refreshToken,
    required this.accessTokenExpiresAt,
  });

  factory TokenPair.fromJson(Object? json) {
    final r = JsonReader(json);
    return TokenPair(
      accessToken: r.string('accessToken'),
      refreshToken: r.string('refreshToken'),
      accessTokenExpiresAt: r.decoded(
        'accessTokenExpiresAt',
        InstantCodec.decode,
      ),
    );
  }

  final String accessToken;
  final String refreshToken;

  /// Thời điểm access token hết hạn (UTC).
  final DateTime accessTokenExpiresAt;

  Map<String, Object?> toJson() => {
    'accessToken': accessToken,
    'refreshToken': refreshToken,
    'accessTokenExpiresAt': InstantCodec.encode(accessTokenExpiresAt.toUtc()),
  };
}

/// Trạng thái thiết lập lần đầu của tài khoản (OB-6).
enum OnboardingState {
  notStarted('not_started'),
  inProgress('in_progress'),
  completed('completed');

  const OnboardingState(this.wire);

  final String wire;

  static OnboardingState fromWire(String wire) => values.firstWhere(
    (s) => s.wire == wire,
    orElse: () => throw const ContractFormatException('onboardingState'),
  );
}

/// `GET /v1/me` (05 §6.6.5).
final class MeResponse {
  const MeResponse({
    required this.userId,
    required this.phone,
    required this.displayName,
    required this.onboardingState,
    this.onboardingStep,
  });

  factory MeResponse.fromJson(Object? json) {
    final r = JsonReader(json);
    return MeResponse(
      userId: r.string('userId'),
      phone: r.string('phone'),
      displayName: r.string('displayName'),
      onboardingState: OnboardingState.fromWire(r.string('onboardingState')),
      onboardingStep: r.optInteger('onboardingStep'),
    );
  }

  final String userId;
  final String phone;
  final String displayName;
  final OnboardingState onboardingState;

  /// Bước đang dở (1–5) khi [onboardingState] = `in_progress` (VS-03).
  final int? onboardingStep;

  Map<String, Object?> toJson() => {
    'userId': userId,
    'phone': phone,
    'displayName': displayName,
    'onboardingState': onboardingState.wire,
    'onboardingStep': ?onboardingStep,
  };
}
