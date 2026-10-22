import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:api_contract/api_contract.dart';
import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import 'package:domain/domain.dart';
import 'package:http2/http2.dart';

import 'apns.dart';

/// Khóa APNs (`.p8`) đọc từ file trên server (05 Bản 3 TR3-13): không vào git,
/// không vào image, không vào app.
final class ApnsCredentials {
  const ApnsCredentials({
    required this.keyPem,
    required this.keyId,
    required this.teamId,
  });

  final String keyPem;
  final String keyId;
  final String teamId;
}

/// Gửi một request HTTP/2; test thay bằng phản hồi ghi sẵn.
abstract interface class ApnsTransport {
  Future<({int status, String body})> post(
    String host,
    String path,
    Map<String, String> headers,
    List<int> body,
  );

  Future<void> close();
}

/// Gọi APNs trực tiếp (05 Bản 3 TD3-10, không SDK): HTTP/2, xác thực bằng JWT
/// ES256 ký từ khóa `.p8`, ký lại sau mỗi 50 phút (Apple nhận token 20–60 phút).
final class ApnsClient implements Apns {
  ApnsClient({
    required ApnsCredentials credentials,
    required String bundleId,
    required Clock clock,
    ApnsTransport? transport,
  }) : _credentials = credentials,
       _key = ECPrivateKey(credentials.keyPem),
       _topic = '$bundleId.push-type.liveactivity',
       _clock = clock,
       _transport = transport ?? Http2ApnsTransport();

  static const resignAfter = Duration(minutes: 50);

  final ApnsCredentials _credentials;
  final ECPrivateKey _key;
  final String _topic;
  final Clock _clock;
  final ApnsTransport _transport;
  String? _jwt;
  DateTime? _signedAt;

  static String host(ApnsEnvironment e) => switch (e) {
    ApnsEnvironment.production => 'api.push.apple.com',
    ApnsEnvironment.sandbox => 'api.sandbox.push.apple.com',
  };

  /// JWT hiện tại (ký lại khi quá [resignAfter] hoặc [force]).
  String token({bool force = false}) {
    final now = _clock.now();
    final signedAt = _signedAt;
    if (force ||
        _jwt == null ||
        signedAt == null ||
        now.difference(signedAt) >= resignAfter) {
      _jwt = JWT(
        {
          'iss': _credentials.teamId,
          'iat': now.toUtc().millisecondsSinceEpoch ~/ 1000,
        },
        header: {'kid': _credentials.keyId},
      ).sign(_key, algorithm: JWTAlgorithm.ES256, noIssueAt: true);
      _signedAt = now;
    }
    return _jwt!;
  }

  @override
  Future<ApnsResult> send(ApnsPush push) async {
    var result = await _send(push, token());
    // Token xác thực hết hạn sớm (máy chủ lệch giờ): ký lại, thử ngay một lần.
    if (result.reason == 'ExpiredProviderToken') {
      result = await _send(push, token(force: true));
    }
    return result;
  }

  Future<ApnsResult> _send(ApnsPush push, String jwt) async {
    final ({int status, String body}) res;
    try {
      res = await _transport.post(
        host(push.environment),
        '/3/device/${push.token}',
        {
          'authorization': 'bearer $jwt',
          'apns-push-type': 'liveactivity',
          'apns-topic': _topic,
          'apns-priority': '10',
          // Không giao được thì bỏ, không giao muộn (§6.9.2).
          'apns-expiration': '0',
          'content-type': 'application/json',
        },
        utf8.encode(jsonEncode(push.payload)),
      );
    } on Object catch (e) {
      return ApnsResult(ApnsOutcome.retry, reason: e.runtimeType.toString());
    }
    String? reason;
    try {
      final body = jsonDecode(res.body);
      if (body case {'reason': final String r}) reason = r;
    } on FormatException {
      reason = null;
    }
    final outcome = switch (res.status) {
      200 => ApnsOutcome.sent,
      410 => ApnsOutcome.invalidToken,
      400 when reason == 'BadDeviceToken' => ApnsOutcome.invalidToken,
      429 || >= 500 => ApnsOutcome.retry,
      _ => ApnsOutcome.rejected,
    };
    return ApnsResult(outcome, status: res.status, reason: reason);
  }

  @override
  Future<void> close() => _transport.close();
}

/// HTTP/2 qua TLS tới APNs; giữ một kết nối mỗi host, mất kết nối thì mở lại.
final class Http2ApnsTransport implements ApnsTransport {
  final _connections = <String, ClientTransportConnection>{};

  Future<ClientTransportConnection> _connect(String host) async {
    final existing = _connections[host];
    if (existing != null && existing.isOpen) return existing;
    // ignore: close_sinks — kết nối HTTP/2 giữ socket, đóng ở [close].
    final socket = await SecureSocket.connect(
      host,
      443,
      supportedProtocols: const ['h2'],
      timeout: const Duration(seconds: 10),
    );
    return _connections[host] = ClientTransportConnection.viaSocket(socket);
  }

  @override
  Future<({int status, String body})> post(
    String host,
    String path,
    Map<String, String> headers,
    List<int> body,
  ) async {
    final connection = await _connect(host);
    final stream = connection.makeRequest([
      Header.ascii(':method', 'POST'),
      Header.ascii(':scheme', 'https'),
      Header.ascii(':path', path),
      Header.ascii(':authority', host),
      for (final h in headers.entries) Header.ascii(h.key, h.value),
    ]);
    stream.sendData(body, endStream: true);
    var status = 0;
    final out = BytesBuilder();
    await for (final message in stream.incomingMessages.timeout(
      const Duration(seconds: 20),
    )) {
      if (message is HeadersStreamMessage) {
        for (final h in message.headers) {
          if (ascii.decode(h.name) == ':status') {
            status = int.parse(ascii.decode(h.value));
          }
        }
      } else if (message is DataStreamMessage) {
        out.add(message.bytes);
      }
    }
    return (status: status, body: utf8.decode(out.takeBytes()));
  }

  @override
  Future<void> close() async {
    for (final c in _connections.values) {
      await c.finish();
    }
    _connections.clear();
  }
}
