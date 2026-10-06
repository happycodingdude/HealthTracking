/// Một yêu cầu tới nhà cung cấp AI (05 §6.9).
final class AiRequest {
  const AiRequest({
    required this.system,
    required this.user,
    required this.schema,
    required this.maxTokens,
    required this.targetKcal,
    this.avoidDishes = const [],
  });

  final String system;
  final String user;

  /// JSON schema của đầu ra (structured output, 05 §6.9.4).
  final Map<String, Object?> schema;
  final int maxTokens;

  /// Chỉ để [FakeAiProvider] dựng thực đơn giả; nhà cung cấp thật đọc từ
  /// [user].
  final int targetKcal;
  final List<String> avoidDishes;
}

/// Kết quả thành công: văn bản JSON và số token thực tế để tính chi phí.
final class AiResult {
  const AiResult({
    required this.text,
    required this.inputTokens,
    required this.outputTokens,
  });

  final String text;
  final int inputTokens;
  final int outputTokens;
}

/// Lỗi từ nhà cung cấp. [inputTokens]/[outputTokens] có khi nhà cung cấp đã
/// tính tiền (F11-E1); [billingUnknown] = không biết đã tính tiền hay chưa
/// (hết giờ chờ, mất kết nối) → tính bằng số đã đặt trước (05 §6.9.3).
final class AiProviderException implements Exception {
  const AiProviderException(
    this.reason, {
    this.inputTokens,
    this.outputTokens,
    this.billingUnknown = false,
  });

  final String reason;
  final int? inputTokens;
  final int? outputTokens;
  final bool billingUnknown;

  @override
  String toString() => 'AiProviderException($reason)';
}

/// Nhà cung cấp AI (06 VS12-T04): thật ([AnthropicProvider]) hoặc giả
/// ([FakeAiProvider], mặc định ở local và CI, ED-11).
abstract interface class AiProvider {
  /// Ghi vào `ai_requests.provider`.
  String get name;

  /// Model snapshot cố định (05 §6.9.1).
  String get model;

  Future<AiResult> complete(AiRequest request);
}
