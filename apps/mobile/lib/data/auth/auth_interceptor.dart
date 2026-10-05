import 'package:api_contract/api_contract.dart';
import 'package:dio/dio.dart';

import '../api/api_client.dart';
import 'token_manager.dart';

/// Gắn `Authorization: Bearer` cho mọi request cần đăng nhập; gặp 401 thì làm
/// mới token (một lần cho mọi request đang chờ) rồi gửi lại đúng một lần.
final class AuthInterceptor extends Interceptor {
  AuthInterceptor(this._dio, this._tokens);

  final Dio _dio;
  final TokenManager _tokens;

  static const _retried = 'auth.retried';
  static const _sentToken = 'auth.sentToken';

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    if (!ApiClient.requiresAuth(options)) return handler.next(options);
    try {
      final token = await _tokens.validAccessToken();
      options.headers['authorization'] = 'Bearer $token';
      options.extra[_sentToken] = token;
      handler.next(options);
    } on SessionExpired {
      handler.reject(_unauthorized(options));
    } on DioException catch (e) {
      handler.reject(e);
    } on ApiFailure catch (e) {
      handler.reject(DioException(requestOptions: options, error: e));
    }
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final options = err.requestOptions;
    final unauthorized =
        err.response?.statusCode == 401 &&
        ApiError.fromJson(err.response?.data).code == ErrorCode.unauthorized;
    if (!unauthorized ||
        !ApiClient.requiresAuth(options) ||
        options.extra[_retried] == true) {
      return handler.next(err);
    }
    try {
      final token = await _tokens.refresh(
        failedToken: options.extra[_sentToken] as String?,
      );
      options
        ..headers['authorization'] = 'Bearer $token'
        ..extra[_retried] = true
        ..extra[_sentToken] = token;
      handler.resolve(await _dio.fetch<Object?>(options));
    } on SessionExpired {
      handler.next(err);
    } on DioException catch (e) {
      handler.next(e);
    } on ApiFailure {
      handler.next(err);
    }
  }

  DioException _unauthorized(RequestOptions options) => DioException(
    requestOptions: options,
    response: Response(
      requestOptions: options,
      statusCode: 401,
      data: const ApiError(ErrorCode.unauthorized).toJson(),
    ),
    type: DioExceptionType.badResponse,
  );
}
