import 'package:api_contract/api_contract.dart';
import 'package:test/test.dart';

void main() {
  group('ErrorCode (05 §6.8.3)', () {
    test('đủ mã và đúng HTTP status theo bảng 05 §6.8.3', () {
      const expected = {
        'validation_failed': 422,
        'phone_taken': 409,
        'invalid_credentials': 401,
        'too_many_attempts': 429,
        'unauthorized': 401,
        'profile_incomplete': 409,
        'menu_quota_exhausted': 429,
        'budget_exhausted': 429,
        'generation_in_progress': 409,
        'ai_invalid_output': 502,
        'ai_provider_error': 502,
        // Bản 2 (05 Bản 2 §6.8.3).
        'dish_image_quota_exhausted': 429,
        'session_locked': 422,
        'extra_session_locked': 422,
        'no_schedule': 422,
        'lift_no_session': 422,
        'lift_window_closed': 422,
        'lift_not_allowed_for_exercise': 422,
        'lift_exercise_not_in_session': 422,
        // Bản 3 (05 Bản 3 §6.6.3).
        'lift_unit_missing': 422,
      };
      for (final entry in expected.entries) {
        final code = ErrorCode.fromWire(entry.key);
        expect(code.wire, entry.key);
        expect(code.httpStatus, entry.value, reason: entry.key);
      }
    });

    test('mã wire không trùng nhau', () {
      final wires = ErrorCode.values.map((c) => c.wire).toList();
      expect(wires.toSet(), hasLength(wires.length));
    });

    test('TA-16: mã chưa biết được coi là internal_error', () {
      expect(ErrorCode.fromWire('some_future_code'), ErrorCode.internalError);
      expect(ErrorCode.fromWire(null), ErrorCode.internalError);
    });
  });

  group('ApiError', () {
    test('JSON khứ hồi, có và không có field', () {
      const a = ApiError(ErrorCode.phoneTaken, field: 'phone');
      expect(a.toJson(), {
        'error': {'code': 'phone_taken', 'field': 'phone'},
      });
      expect(ApiError.fromJson(a.toJson()), a);

      const b = ApiError(ErrorCode.unauthorized);
      expect(b.toJson(), {
        'error': {'code': 'unauthorized'},
      });
      expect(ApiError.fromJson(b.toJson()), b);
      expect(b.httpStatus, 401);
    });

    test('thân lỗi lạ → internal_error', () {
      expect(ApiError.fromJson('oops').code, ErrorCode.internalError);
      expect(ApiError.fromJson({'message': 'x'}).code, ErrorCode.internalError);
    });
  });
}
