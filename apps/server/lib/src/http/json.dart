import 'dart:convert';

import 'package:api_contract/api_contract.dart';
import 'package:shelf/shelf.dart';

import 'api_exception.dart';

const jsonHeaders = {'content-type': 'application/json; charset=utf-8'};

Response jsonResponse(Object? body, {int status = 200}) =>
    Response(status, body: jsonEncode(body), headers: jsonHeaders);

Response errorResponse(ApiError error) =>
    jsonResponse(error.toJson(), status: error.httpStatus);

/// Đọc thân JSON, tối đa [maxBytes]. Sai → `validation_failed` (field `body`).
Future<Object?> readJson(Request request, {int maxBytes = 1 << 20}) async {
  final length = request.contentLength;
  if (length != null && length > maxBytes) {
    throw ApiException(ErrorCode.validationFailed, field: 'body');
  }
  final bytes = <int>[];
  await for (final chunk in request.read()) {
    bytes.addAll(chunk);
    if (bytes.length > maxBytes) {
      throw ApiException(ErrorCode.validationFailed, field: 'body');
    }
  }
  try {
    return jsonDecode(utf8.decode(bytes));
  } on FormatException {
    throw ApiException(ErrorCode.validationFailed, field: 'body');
  }
}

/// Đọc DTO từ thân JSON; lỗi hợp đồng → `validation_failed` kèm tên trường.
Future<T> readDto<T>(Request request, T Function(Object? json) decode) async {
  final json = await readJson(request);
  try {
    return decode(json);
  } on ContractFormatException catch (e) {
    throw ApiException(ErrorCode.validationFailed, field: e.field);
  }
}
