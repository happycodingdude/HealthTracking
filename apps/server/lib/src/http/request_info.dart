import 'package:shelf/shelf.dart';

/// Thông tin của một request, chia sẻ giữa các middleware.
final class RequestInfo {
  RequestInfo(this.requestId);

  final String requestId;

  /// Được middleware xác thực đặt từ `sub` của access token.
  String? userId;
}

const _infoKey = 'health.request_info';

extension RequestInfoAccess on Request {
  RequestInfo get info => context[_infoKey]! as RequestInfo;

  Request withInfo(RequestInfo info) => change(context: {_infoKey: info});
}
