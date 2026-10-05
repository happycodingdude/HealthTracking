import 'error_code.dart';

/// Thân lỗi chuẩn: `{"error": {"code": "...", "field": "..."}}` (05 §6.8.1).
final class ApiError {
  const ApiError(this.code, {this.field});

  /// Đọc thân lỗi. Thân không đúng chuẩn → [ErrorCode.internalError].
  factory ApiError.fromJson(Object? json) {
    if (json is Map && json['error'] is Map) {
      final error = json['error'] as Map;
      final field = error['field'];
      return ApiError(
        ErrorCode.fromWire(
          error['code'] is String ? error['code'] as String : null,
        ),
        field: field is String ? field : null,
      );
    }
    return const ApiError(ErrorCode.internalError);
  }

  final ErrorCode code;

  /// Ô gây lỗi (camelCase theo tên trường trong request), nếu có.
  final String? field;

  int get httpStatus => code.httpStatus;

  Map<String, Object?> toJson() => {
    'error': {'code': code.wire, 'field': ?field},
  };

  @override
  bool operator ==(Object other) =>
      other is ApiError && other.code == code && other.field == field;

  @override
  int get hashCode => Object.hash(code, field);

  @override
  String toString() =>
      'ApiError(${code.wire}${field == null ? '' : ', $field'})';
}
