import 'package:api_contract/api_contract.dart';
import 'package:shelf/shelf.dart';

/// Thông tin của một request, chia sẻ giữa các middleware.
final class RequestInfo {
  RequestInfo(this.requestId, {this.appVersion});

  final String requestId;

  /// Header `X-App-Version` (05 Bản 2 TD2-15). null = app Bản 1 (không gửi
  /// header) hoặc giá trị không đọc được.
  final AppVersion? appVersion;

  /// Được middleware xác thực đặt từ `sub` của access token.
  String? userId;
}

const _infoKey = 'health.request_info';

extension RequestInfoAccess on Request {
  RequestInfo get info => context[_infoKey]! as RequestInfo;

  Request withInfo(RequestInfo info) => change(context: {_infoKey: info});
}
