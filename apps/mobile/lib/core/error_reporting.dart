import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import '../app/env.dart';

/// Báo lỗi lên Sentry (TD-13, OPS-6), không gửi dữ liệu cá nhân.
abstract interface class ErrorReporter {
  Future<void> report(Object error, StackTrace? stack, {String? reason});
}

final class SentryErrorReporter implements ErrorReporter {
  const SentryErrorReporter();

  @override
  Future<void> report(Object error, StackTrace? stack, {String? reason}) async {
    await Sentry.captureException(
      error,
      stackTrace: stack,
      withScope: reason == null
          ? null
          : (scope) => scope.setTag('reason', reason),
    );
  }
}

/// Dùng khi chưa cấu hình Sentry và trong test: chỉ in ra khi debug.
final class DebugErrorReporter implements ErrorReporter {
  const DebugErrorReporter();

  @override
  Future<void> report(Object error, StackTrace? stack, {String? reason}) async {
    debugPrint('[error] ${reason ?? ''} $error');
  }
}

/// Khởi động app; nếu có `SENTRY_DSN` thì bật Sentry với bộ lọc [scrubEvent].
Future<void> runWithErrorReporting(
  AppEnv env,
  FutureOr<void> Function() appRunner,
) async {
  if (env.sentryDsn.isEmpty) {
    await appRunner();
    return;
  }
  await SentryFlutter.init((options) {
    options
      ..dsn = env.sentryDsn
      ..environment = env.flavor
      ..sendDefaultPii = false
      ..attachScreenshot = false
      ..attachViewHierarchy = false
      ..tracesSampleRate = 0
      ..beforeSend = _beforeSend
      ..beforeBreadcrumb = _beforeBreadcrumb;
  }, appRunner: appRunner);
}

SentryEvent _beforeSend(SentryEvent event, Hint hint) => scrubEvent(event);

Breadcrumb? _beforeBreadcrumb(Breadcrumb? crumb, Hint hint) {
  return crumb == null ? null : scrubBreadcrumb(crumb);
}

final _numbers = RegExp(r'\d[\d.,]{2,}');

/// Thay mọi dãy số (số điện thoại, số cân, mức calo…) bằng `<n>`.
String scrubText(String text) => text.replaceAll(_numbers, '<n>');

const _allowedBreadcrumbData = {'method', 'status_code', 'reason', 'url'};

/// Bỏ thông tin cá nhân khỏi breadcrumb: chỉ giữ method, status, đường dẫn URL
/// (không query); chữ được lọc số.
Breadcrumb scrubBreadcrumb(Breadcrumb crumb) {
  final data = crumb.data;
  if (data != null) {
    crumb.data = {
      for (final e in data.entries)
        if (_allowedBreadcrumbData.contains(e.key))
          e.key: e.key == 'url' && e.value is String
              ? _stripQuery(e.value as String)
              : e.value,
    };
  }
  final message = crumb.message;
  if (message != null) crumb.message = scrubText(message);
  return crumb;
}

/// Bộ lọc dữ liệu cá nhân cho mọi sự kiện gửi lên Sentry (TD-13).
SentryEvent scrubEvent(SentryEvent event) {
  event
    ..user = null
    ..request = null
    ..serverName = null
    // ignore: deprecated_member_use
    ..extra = null;
  // Tên máy do người dùng đặt (ví dụ "iPhone của Minh").
  event.contexts.device?.name = null;
  final message = event.message;
  if (message != null) {
    event.message = SentryMessage(
      scrubText(message.formatted),
      template: null,
      params: null,
    );
  }
  for (final e in event.exceptions ?? const <SentryException>[]) {
    final value = e.value;
    if (value != null) e.value = scrubText(value);
  }
  event.breadcrumbs = event.breadcrumbs?.map(scrubBreadcrumb).toList();
  return event;
}

String _stripQuery(String url) {
  final uri = Uri.tryParse(url);
  if (uri == null) return '';
  return Uri(
    scheme: uri.scheme,
    host: uri.host,
    port: uri.hasPort ? uri.port : null,
    path: uri.path,
  ).toString();
}
