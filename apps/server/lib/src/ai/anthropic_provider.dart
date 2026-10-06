import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'ai_provider.dart';

/// Claude Messages API qua REST (Dart không có SDK chính thức), 06 VS12-T04:
/// model snapshot cố định, đầu ra JSON theo schema (`output_config.format`),
/// chờ tối đa 60 giây, thử lại 1 lần khi nhà cung cấp quá tải (429/5xx).
final class AnthropicProvider implements AiProvider {
  AnthropicProvider({
    required String apiKey,
    required this.model,
    this.timeout = const Duration(seconds: 60),
    Uri? endpoint,
    HttpClient? client,
    Future<void> Function(Duration)? sleep,
  }) : _apiKey = apiKey,
       _endpoint =
           endpoint ?? Uri.parse('https://api.anthropic.com/v1/messages'),
       _client = client ?? HttpClient(),
       _sleep = sleep ?? Future<void>.delayed;

  final String _apiKey;
  final Uri _endpoint;
  final HttpClient _client;
  final Future<void> Function(Duration) _sleep;

  @override
  final String model;
  final Duration timeout;

  /// Chờ trước lần thử lại khi không có `retry-after`, và mức chờ tối đa.
  static const _retryDelay = Duration(seconds: 2);
  static const _maxRetryDelay = Duration(seconds: 10);

  @override
  String get name => 'anthropic';

  @override
  Future<AiResult> complete(AiRequest request) async {
    final body = utf8.encode(
      jsonEncode({
        'model': model,
        'max_tokens': request.maxTokens,
        'system': request.system,
        'messages': [
          {'role': 'user', 'content': request.user},
        ],
        'output_config': {
          'format': {'type': 'json_schema', 'schema': request.schema},
        },
      }),
    );
    for (var attempt = 0; ; attempt++) {
      final (status, json, retryAfter) = await _post(body);
      if (status == 200) return _result(json);
      final retryable = status == 429 || status >= 500;
      if (retryable && attempt == 0) {
        await _sleep(retryAfter ?? _retryDelay);
        continue;
      }
      // Yêu cầu bị từ chối không bị tính tiền.
      throw AiProviderException(
        'http_$status',
        inputTokens: 0,
        outputTokens: 0,
      );
    }
  }

  Future<(int, Object?, Duration?)> _post(List<int> body) async {
    try {
      return await () async {
        final req = await _client.postUrl(_endpoint);
        req.headers
          ..set(HttpHeaders.contentTypeHeader, 'application/json')
          ..set('x-api-key', _apiKey)
          ..set('anthropic-version', '2023-06-01');
        req.contentLength = body.length;
        req.add(body);
        final res = await req.close();
        final text = await res.transform(utf8.decoder).join();
        final seconds = int.tryParse(res.headers.value('retry-after') ?? '');
        final retryAfter = seconds == null
            ? null
            : Duration(seconds: seconds) > _maxRetryDelay
            ? _maxRetryDelay
            : Duration(seconds: seconds);
        Object? json;
        try {
          json = text.isEmpty ? null : jsonDecode(text);
        } on FormatException {
          json = null;
        }
        return (res.statusCode, json, retryAfter);
      }().timeout(timeout);
    } on TimeoutException {
      // Không biết nhà cung cấp đã tính tiền hay chưa (05 §6.9.3).
      throw const AiProviderException('timeout', billingUnknown: true);
    } on IOException {
      throw const AiProviderException('network', billingUnknown: true);
    }
  }

  static AiResult _result(Object? json) {
    if (json is! Map) {
      throw const AiProviderException('bad_response', billingUnknown: true);
    }
    final usage = json['usage'];
    final input = usage is Map ? usage['input_tokens'] : null;
    final output = usage is Map ? usage['output_tokens'] : null;
    if (input is! int || output is! int) {
      throw const AiProviderException('bad_response', billingUnknown: true);
    }
    // Chưa trả xong (hết max_tokens) hoặc từ chối: đầu ra có thể không theo
    // schema; vẫn tính tiền theo token thực tế (F11-E1).
    final stop = json['stop_reason'];
    final content = json['content'];
    final text = content is List
        ? content
              .whereType<Map<Object?, Object?>>()
              .where((b) => b['type'] == 'text')
              .map((b) => b['text'])
              .whereType<String>()
              .join()
        : '';
    if (stop != 'end_turn' || text.isEmpty) {
      throw AiProviderException(
        'stop_$stop',
        inputTokens: input,
        outputTokens: output,
      );
    }
    return AiResult(text: text, inputTokens: input, outputTokens: output);
  }

  void close() => _client.close(force: true);
}
