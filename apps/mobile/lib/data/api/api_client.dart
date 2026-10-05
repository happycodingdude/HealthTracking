import 'package:api_contract/api_contract.dart';
import 'package:dio/dio.dart';

/// Lỗi khi gọi server.
sealed class ApiFailure implements Exception {
  const ApiFailure();
}

/// Server trả lỗi chuẩn `{"error": {...}}`.
final class ServerFailure extends ApiFailure {
  const ServerFailure(this.error, this.status);
  final ApiError error;
  final int status;

  @override
  String toString() => 'ServerFailure($status, $error)';
}

/// Không kết nối được server (không có mạng, timeout, DNS…).
final class NetworkFailure extends ApiFailure {
  const NetworkFailure();

  @override
  String toString() => 'NetworkFailure';
}

/// Lớp gọi HTTP duy nhất của app (05 §6.2: dio). Chỉ data layer dùng; UI không
/// gọi API trực tiếp (IS-4).
class ApiClient {
  ApiClient(this.dio);

  factory ApiClient.create(String baseUrl) => ApiClient(
    Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: const Duration(seconds: 10),
        sendTimeout: const Duration(seconds: 20),
        receiveTimeout: const Duration(seconds: 30),
        contentType: Headers.jsonContentType,
        responseType: ResponseType.json,
      ),
    ),
  );

  final Dio dio;

  /// [auth] = false cho các endpoint không cần đăng nhập (`/v1/auth/*`, `/healthz`).
  Future<Object?> getJson(
    String path, {
    Map<String, Object?>? query,
    bool auth = true,
  }) => _send(
    () =>
        dio.get<Object?>(path, queryParameters: query, options: _options(auth)),
  );

  Future<Object?> postJson(String path, Object? body, {bool auth = true}) =>
      _send(() => dio.post<Object?>(path, data: body, options: _options(auth)));

  static const _authKey = 'auth';

  static Options _options(bool auth) => Options(extra: {_authKey: auth});

  /// Request này có cần gắn access token không.
  static bool requiresAuth(RequestOptions options) =>
      options.extra[_authKey] != false;

  /// `GET /healthz`: true nếu server và database đang chạy.
  Future<bool> healthz() async {
    try {
      await getJson('/healthz', auth: false);
      return true;
    } on ApiFailure {
      return false;
    }
  }

  Future<Object?> _send(Future<Response<Object?>> Function() request) async {
    try {
      final res = await request();
      return res.data;
    } on DioException catch (e) {
      throw failureOf(e);
    }
  }

  /// Đổi [DioException] thành [ApiFailure].
  static ApiFailure failureOf(DioException e) {
    final inner = e.error;
    if (inner is ApiFailure) return inner;
    final res = e.response;
    if (res == null) return const NetworkFailure();
    return ServerFailure(ApiError.fromJson(res.data), res.statusCode ?? 0);
  }
}
