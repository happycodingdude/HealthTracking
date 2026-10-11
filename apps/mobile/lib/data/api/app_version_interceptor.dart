import 'package:api_contract/api_contract.dart';
import 'package:dio/dio.dart';

/// Gắn `X-App-Version` vào mọi request (05 Bản 2 TR2-13, 06 Bản 2 ED2-02):
/// một interceptor duy nhất, giá trị đọc từ `package_info` lúc khởi động.
final class AppVersionInterceptor extends Interceptor {
  AppVersionInterceptor(this._version);

  final AppVersion _version;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    options.headers[AppVersion.header] = _version.toString();
    handler.next(options);
  }
}
