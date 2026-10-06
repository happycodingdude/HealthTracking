import 'dart:convert';

import 'package:domain/domain.dart';

import '../config.dart';
import 'ai_provider.dart';

/// Cấu hình AI Gateway (05 §6.9.1). Đơn giá và tỷ giá nằm trong cấu hình,
/// cập nhật khi nhà cung cấp đổi giá.
final class AiConfig {
  const AiConfig({
    this.provider = 'fake',
    this.apiKey,
    this.model = defaultModel,
    this.inputUsdPerMTok = 1,
    this.outputUsdPerMTok = 5,
    this.vndPerUsd = 27000,
    this.maxTokens = 2500,
    this.timeout = const Duration(seconds: 60),
    this.capVnd = AiBudgetRules.capVnd,
    this.fakeDelay = Duration.zero,
  });

  factory AiConfig.fromEnvironment(Map<String, String> env) {
    double number(String key, double fallback) {
      final raw = env[key];
      if (raw == null || raw.isEmpty) return fallback;
      final v = double.tryParse(raw);
      if (v == null || v <= 0) throw ConfigException('$key không hợp lệ');
      return v;
    }

    final provider = env['AI_PROVIDER']?.isNotEmpty == true
        ? env['AI_PROVIDER']!
        : 'fake';
    if (provider != 'fake' && provider != 'anthropic') {
      throw ConfigException('AI_PROVIDER chỉ nhận fake hoặc anthropic');
    }
    final key = env['ANTHROPIC_API_KEY'];
    if (provider == 'anthropic' && (key == null || key.isEmpty)) {
      throw ConfigException('Thiếu biến môi trường ANTHROPIC_API_KEY');
    }
    return AiConfig(
      provider: provider,
      apiKey: key,
      model: env['AI_MODEL']?.isNotEmpty == true
          ? env['AI_MODEL']!
          : defaultModel,
      inputUsdPerMTok: number('AI_PRICE_INPUT_USD_PER_MTOK', 1),
      outputUsdPerMTok: number('AI_PRICE_OUTPUT_USD_PER_MTOK', 5),
      vndPerUsd: number('AI_VND_PER_USD', 27000),
      fakeDelay: Duration(
        milliseconds: int.tryParse(env['AI_FAKE_DELAY_MS'] ?? '') ?? 0,
      ),
    );
  }

  /// Model snapshot cố định của Bản 1 (05 §6.9.1).
  static const defaultModel = 'claude-haiku-4-5-20251001';

  /// `fake` (mặc định ở local và CI, ED-11) hoặc `anthropic`.
  final String provider;
  final String? apiKey;
  final String model;
  final double inputUsdPerMTok;
  final double outputUsdPerMTok;

  /// Cố ý cao hơn tỷ giá thực tế (TA-02).
  final double vndPerUsd;
  final int maxTokens;
  final Duration timeout;

  /// Mức trần mỗi tháng (F11-R1), không chỉnh được trong app (F11-R7).
  final int capVnd;

  /// Chỉ cho nhà cung cấp giả ở bản dev: chờ trước khi trả để thấy trạng
  /// thái "Đang lên thực đơn…" khi thử trên máy.
  final Duration fakeDelay;
}

/// Ước tính và tính chi phí, đơn vị 1/100 đồng (khớp `numeric(12,2)`).
final class CostEstimator {
  const CostEstimator(this.config);

  final AiConfig config;

  /// Phần nhà cung cấp tự thêm vào prompt khi ép đầu ra theo schema (không
  /// nằm trong số byte ta gửi), tính dư cho chắc.
  static const schemaOverheadTokens = 2000;

  /// Ước tính tối đa (05 §6.9.3): token vào ≤ số byte UTF-8 của prompt (mỗi
  /// token ít nhất 1 byte) + phần thêm của schema; token ra ≤ `max_tokens`.
  int estimateCenti(AiRequest r) {
    final inputBytes =
        utf8.encode(r.system).length +
        utf8.encode(r.user).length +
        utf8.encode(jsonEncode(r.schema)).length;
    return _centi(inputBytes + schemaOverheadTokens, r.maxTokens);
  }

  /// Chi phí thực tế theo số token nhà cung cấp báo.
  int actualCenti(int inputTokens, int outputTokens) =>
      _centi(inputTokens, outputTokens);

  int _centi(int inputTokens, int outputTokens) {
    final usd =
        (inputTokens * config.inputUsdPerMTok +
            outputTokens * config.outputUsdPerMTok) /
        1e6;
    // Làm tròn lên: không bao giờ ghi thấp hơn chi phí thật.
    return (usd * config.vndPerUsd * 100).ceil();
  }
}
