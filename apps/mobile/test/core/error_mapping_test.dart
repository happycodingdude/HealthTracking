import 'package:api_contract/api_contract.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/app/strings_vi.dart';
import 'package:mobile/core/error_mapping.dart';

void main() {
  test('06 §6.4.3: mọi ErrorCode có câu hiển thị ở mọi màn hình', () {
    for (final screen in ErrorScreen.values) {
      for (final code in ErrorCode.values) {
        final message = errorMessage(ApiError(code), screen, nextMonth: 11);
        expect(message, isNotEmpty, reason: '$screen ${code.wire}');
        expect(
          message,
          isNot(contains(code.wire)),
          reason: 'không hiện mã kỹ thuật (04 §6.14)',
        );
      }
    }
  });

  test('06 Bản 2 §6.4: hai danh sách — mã có câu riêng, mã không bao giờ '
      'hiện câu (hoàn về trạng thái server, TA-12)', () {
    // Mã có câu riêng ở mọi màn hình gọi AI (không rơi về câu mất mạng).
    const displayed = {
      ErrorCode.menuQuotaExhausted,
      ErrorCode.budgetExhausted,
      ErrorCode.generationInProgress,
      ErrorCode.aiInvalidOutput,
      ErrorCode.aiProviderError,
      ErrorCode.dishImageQuotaExhausted,
    };
    expect(
      errorMessage(
        const ApiError(ErrorCode.dishImageQuotaExhausted),
        ErrorScreen.menu,
      ),
      'Bạn đã xem đủ 3 hình mới hôm nay.',
    );
    for (final code in displayed) {
      expect(
        errorMessage(ApiError(code), ErrorScreen.menu, nextMonth: 11),
        isNot(S.offlineMenu),
        reason: code.wire,
      );
    }
    expect(silentErrorCodes.map((c) => c.wire).toSet(), {
      'session_locked',
      'extra_session_locked',
      'no_schedule',
      'lift_no_session',
      'lift_window_closed',
      'lift_not_allowed_for_exercise',
      'lift_exercise_not_in_session',
    });
    expect(silentErrorCodes.intersection(displayed), isEmpty);
    for (final code in silentErrorCodes) {
      expect(code.httpStatus, 422, reason: code.wire);
    }
  });

  test('05 §6.8.3: câu theo mã', () {
    expect(
      errorMessage(const ApiError(ErrorCode.phoneTaken), ErrorScreen.register),
      S.errorPhoneTaken,
    );
    expect(
      errorMessage(
        const ApiError(ErrorCode.invalidCredentials),
        ErrorScreen.login,
      ),
      S.errorInvalidCredentials,
    );
    expect(
      errorMessage(
        const ApiError(ErrorCode.tooManyAttempts),
        ErrorScreen.login,
      ),
      S.errorInvalidCredentials,
      reason: 'không tiết lộ cơ chế chặn',
    );
    expect(
      errorMessage(
        const ApiError(ErrorCode.budgetExhausted),
        ErrorScreen.menu,
        nextMonth: 11,
      ),
      S.budgetPaused(11),
    );
    expect(
      errorMessage(const ApiError(ErrorCode.aiInvalidOutput), ErrorScreen.menu),
      S.menuInvalidOutput,
    );
    expect(
      errorMessage(
        const ApiError(ErrorCode.menuQuotaExhausted),
        ErrorScreen.menu,
      ),
      S.menuQuotaExhausted,
    );
  });

  test(
    'không kết nối được → câu không có mạng của từng màn hình (UA-16, F08-E1)',
    () {
      expect(errorMessage(null, ErrorScreen.register), S.offlineRegister);
      expect(errorMessage(null, ErrorScreen.login), S.offlineLogin);
      expect(errorMessage(null, ErrorScreen.menu), S.offlineMenu);
      expect(
        errorMessage(
          const ApiError(ErrorCode.internalError),
          ErrorScreen.login,
        ),
        S.offlineLogin,
      );
    },
  );

  test('validation_failed → câu dưới ô theo field (S-01a)', () {
    expect(
      errorMessage(
        const ApiError(ErrorCode.validationFailed, field: 'displayName'),
        ErrorScreen.register,
      ),
      S.invalidDisplayName,
    );
    expect(
      errorMessage(
        const ApiError(ErrorCode.validationFailed, field: 'phone'),
        ErrorScreen.register,
      ),
      S.invalidPhone,
    );
    expect(
      errorMessage(
        const ApiError(ErrorCode.validationFailed, field: 'password'),
        ErrorScreen.register,
      ),
      S.invalidPassword,
    );
  });
}
