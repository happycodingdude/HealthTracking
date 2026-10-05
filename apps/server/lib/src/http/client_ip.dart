import 'dart:io';

import 'package:shelf/shelf.dart';

/// IP của client cho giới hạn đăng nhập (05 §6.8.4).
///
/// Sau reverse proxy (Caddy, [trustProxy] = true): lấy giá trị cuối của
/// `X-Forwarded-For` — giá trị do Caddy thêm, client không giả được.
String clientIp(Request request, {required bool trustProxy}) {
  if (trustProxy) {
    final forwarded = request.headers['x-forwarded-for'];
    if (forwarded != null && forwarded.trim().isNotEmpty) {
      return forwarded.split(',').last.trim();
    }
  }
  final info = request.context['shelf.io.connection_info'];
  if (info is HttpConnectionInfo) return info.remoteAddress.address;
  return 'unknown';
}
