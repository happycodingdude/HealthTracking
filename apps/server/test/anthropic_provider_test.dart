import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:domain/domain.dart';
import 'package:server/server.dart';
import 'package:test/test.dart';

/// Nhà cung cấp thật được kiểm bằng HTTP server giả trên máy: không gọi model
/// thật (06 §6.9.3, ED-11).
void main() {
  late HttpServer server;
  late List<(Map<String, String>, Map<String, Object?>)> received;
  late List<FutureOr<void> Function(HttpResponse)> replies;
  late List<Duration> slept;

  setUp(() async {
    received = [];
    replies = [];
    slept = [];
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((req) async {
      final body = jsonDecode(await utf8.decodeStream(req)) as Map;
      received.add((
        {
          'x-api-key': req.headers.value('x-api-key') ?? '',
          'anthropic-version': req.headers.value('anthropic-version') ?? '',
        },
        body.cast<String, Object?>(),
      ));
      final reply = replies.removeAt(0);
      await reply(req.response);
      await req.response.close();
    });
  });
  tearDown(() => server.close(force: true));

  AnthropicProvider provider({Duration timeout = const Duration(seconds: 5)}) =>
      AnthropicProvider(
        apiKey: '***REMOVED***',
        model: AiConfig.defaultModel,
        timeout: timeout,
        endpoint: Uri.parse('http://127.0.0.1:${server.port}/v1/messages'),
        sleep: (d) async => slept.add(d),
      );

  final request = PromptBuilder.menu(
    sex: Sex.female,
    age: 55,
    targetKcal: 1200,
    maxTokens: 2500,
  );

  void Function(HttpResponse) json(
    int status,
    Object body, {
    Map<String, String> headers = const {},
  }) => (res) {
    res.statusCode = status;
    headers.forEach(res.headers.set);
    res.headers.contentType = ContentType.json;
    res.write(jsonEncode(body));
  };

  Map<String, Object?> message(String text, {String stop = 'end_turn'}) => {
    'id': 'msg_1',
    'type': 'message',
    'role': 'assistant',
    'model': AiConfig.defaultModel,
    'content': [
      {'type': 'text', 'text': text},
    ],
    'stop_reason': stop,
    'usage': {'input_tokens': 812, 'output_tokens': 1034},
  };

  test('gửi đúng model cố định, max_tokens, đầu ra theo JSON schema; đọc văn '
      'bản và số token', () async {
    replies.add(json(200, message('{"meals": []}')));
    final r = await provider().complete(request);
    expect(
      (r.text, r.inputTokens, r.outputTokens),
      ('{"meals": []}', 812, 1034),
    );
    final (headers, body) = received.single;
    expect(headers, {
      'x-api-key': '***REMOVED***',
      'anthropic-version': '2023-06-01',
    });
    expect(body['model'], 'claude-haiku-4-5-20251001');
    expect(body['max_tokens'], 2500);
    expect(body['system'], PromptBuilder.system);
    expect(body['messages'], [
      {'role': 'user', 'content': request.user},
    ]);
    expect(body['output_config'], {
      'format': {'type': 'json_schema', 'schema': PromptBuilder.schema},
    });
  });

  test('quá tải (529) → thử lại đúng 1 lần, chờ theo retry-after', () async {
    replies
      ..add(json(529, {'type': 'error'}, headers: {'retry-after': '3'}))
      ..add(json(200, message('{}')));
    final r = await provider().complete(request);
    expect(r.text, '{}');
    expect(received, hasLength(2));
    expect(slept, [const Duration(seconds: 3)]);
  });

  test('429 hai lần → lỗi, không tính tiền (yêu cầu bị từ chối)', () async {
    replies
      ..add(json(429, {'type': 'error'}))
      ..add(json(429, {'type': 'error'}));
    await expectLater(
      provider().complete(request),
      throwsA(
        isA<AiProviderException>()
            .having((e) => e.reason, 'reason', 'http_429')
            .having((e) => e.billingUnknown, 'billingUnknown', isFalse)
            .having((e) => e.inputTokens, 'inputTokens', 0),
      ),
    );
    expect(received, hasLength(2));
  });

  test('400 → không thử lại', () async {
    replies.add(json(400, {'type': 'error'}));
    await expectLater(
      provider().complete(request),
      throwsA(isA<AiProviderException>()),
    );
    expect(received, hasLength(1));
  });

  test('quá thời gian chờ → không biết đã tính tiền chưa (tính trọn số đặt '
      'trước, 05 §6.9.3)', () async {
    replies.add((res) => Future<void>.delayed(const Duration(seconds: 1)));
    await expectLater(
      provider(timeout: const Duration(milliseconds: 200)).complete(request),
      throwsA(
        isA<AiProviderException>().having(
          (e) => e.billingUnknown,
          'billingUnknown',
          isTrue,
        ),
      ),
    );
  });

  test('dừng vì hết max_tokens → lỗi nhưng vẫn tính tiền theo token thực tế '
      '(F11-E1)', () async {
    replies.add(json(200, message('{"meals": [', stop: 'max_tokens')));
    await expectLater(
      provider().complete(request),
      throwsA(
        isA<AiProviderException>()
            .having((e) => e.inputTokens, 'inputTokens', 812)
            .having((e) => e.outputTokens, 'outputTokens', 1034)
            .having((e) => e.billingUnknown, 'billingUnknown', isFalse),
      ),
    );
  });

  test('TR-12: prompt chỉ có giới tính, tuổi, mức calo', () {
    expect(
      request.user,
      'Giới tính: Nữ.\nTuổi: 55.\nMức calo cả ngày: 1200 kcal.',
    );
  });
}
