import 'package:api_contract/api_contract.dart';
import 'package:shelf/shelf.dart';
import 'package:uuid/uuid.dart';

import '../logging/logger.dart';
import 'api_exception.dart';
import 'json.dart';
import 'request_info.dart';

final _validRequestId = RegExp(r'^[A-Za-z0-9-]{8,64}$');
const _uuid = Uuid();

/// Middleware nền cho mọi request (06 VS00-T04):
/// - `X-Request-Id`: dùng lại giá trị hợp lệ từ client, nếu không thì sinh mới;
///   luôn có trong response (05 §6.8.1).
/// - Bọc lỗi chuẩn: [ApiException] → `{"error": {...}}`; lỗi khác → 500
///   `internal_error`, ghi stack vào log.
/// - Log JSON một dòng mỗi request, chỉ metadata (05 §6.12.1), kèm phiên bản
///   app từ `X-App-Version` (06 Bản 2 ED2-02).
/// - `X-App-Version` đọc một lần ở đây vào [RequestInfo.appVersion]; header
///   sai định dạng được coi như không có (app Bản 1).
Middleware coreMiddleware(Logger logger) {
  return (inner) {
    return (request) async {
      final incoming = request.headers['x-request-id'];
      final requestId = incoming != null && _validRequestId.hasMatch(incoming)
          ? incoming
          : _uuid.v4();
      final info = RequestInfo(
        requestId,
        appVersion: AppVersion.tryParse(request.headers[AppVersion.header]),
      );
      final stopwatch = Stopwatch()..start();

      Response response;
      try {
        response = await inner(request.withInfo(info));
      } on ApiException catch (e) {
        response = errorResponse(e.error);
      } catch (e, stack) {
        logger.error(
          'unhandled_error',
          error: e,
          stack: stack,
          fields: {'requestId': requestId, 'path': request.requestedUri.path},
        );
        response = errorResponse(const ApiError(ErrorCode.internalError));
      }

      response = response.change(headers: {'x-request-id': requestId});
      logger.info('request', {
        'requestId': requestId,
        'method': request.method,
        'path': request.requestedUri.path,
        'status': response.statusCode,
        'durationMs': stopwatch.elapsedMilliseconds,
        'userId': ?info.userId,
        'appVersion': ?info.appVersion?.toString(),
      });
      return response;
    };
  };
}

/// Handler cho đường dẫn không tồn tại.
Response notFoundHandler(Request request) =>
    errorResponse(const ApiError(ErrorCode.notFound));
