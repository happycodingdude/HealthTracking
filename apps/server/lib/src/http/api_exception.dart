import 'package:api_contract/api_contract.dart';

/// Lỗi nghiệp vụ trả về client dưới dạng `{"error": {...}}` (05 §6.8.1).
final class ApiException implements Exception {
  ApiException(this.code, {this.field});

  final ErrorCode code;
  final String? field;

  ApiError get error => ApiError(code, field: field);

  @override
  String toString() =>
      'ApiException(${code.wire}${field == null ? '' : ', $field'})';
}
