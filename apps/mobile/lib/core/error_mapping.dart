import 'package:api_contract/api_contract.dart';

import '../app/strings_vi.dart';

/// Màn hình đang hiện lỗi; quyết định câu "không có mạng" tương ứng
/// (05 §6.8.3).
enum ErrorScreen { register, login, menu }

/// Mã lỗi Bản 2 không bao giờ hiện câu nào (06 Bản 2 §6.4): chỉ có trong kết
/// quả push; app hoàn bản ghi về trạng thái server và báo lỗi (TA-12), vì UI
/// đã chặn trước các trường hợp này.
const silentErrorCodes = {
  ErrorCode.sessionLocked,
  ErrorCode.extraSessionLocked,
  ErrorCode.noSchedule,
  ErrorCode.liftNoSession,
  ErrorCode.liftWindowClosed,
  ErrorCode.liftNotAllowedForExercise,
  ErrorCode.liftExerciseNotInSession,
};

/// Hàm duy nhất đổi lỗi thành câu tiếng Việt (06 §6.4.3, AP-6).
///
/// [error] = null nghĩa là không kết nối được server. Mã kỹ thuật
/// (`not_found`, `internal_error`, mã lạ) và mã không xảy ra trong luồng bình
/// thường được xử lý như lỗi kết nối, để không thêm câu chữ ngoài spec.
/// [nextMonth] dùng cho câu F08-E2.
String errorMessage(ApiError? error, ErrorScreen screen, {int? nextMonth}) {
  final offline = switch (screen) {
    ErrorScreen.register => S.offlineRegister,
    ErrorScreen.login => S.offlineLogin,
    ErrorScreen.menu => S.offlineMenu,
  };
  if (error == null) return offline;
  return switch (error.code) {
    ErrorCode.validationFailed => fieldMessage(error.field) ?? offline,
    ErrorCode.phoneTaken => S.errorPhoneTaken,
    ErrorCode.invalidCredentials ||
    ErrorCode.tooManyAttempts => S.errorInvalidCredentials,
    ErrorCode.menuQuotaExhausted => S.menuQuotaExhausted,
    ErrorCode.budgetExhausted => S.budgetPaused(nextMonth ?? 1),
    ErrorCode.generationInProgress => S.menuGenerating,
    ErrorCode.aiInvalidOutput => S.menuInvalidOutput,
    ErrorCode.aiProviderError => S.menuProviderError,
    ErrorCode.dishImageQuotaExhausted => S.dishImageQuotaExhausted,
    ErrorCode.sessionLocked ||
    ErrorCode.extraSessionLocked ||
    ErrorCode.noSchedule ||
    ErrorCode.liftNoSession ||
    ErrorCode.liftWindowClosed ||
    ErrorCode.liftNotAllowedForExercise ||
    ErrorCode.liftExerciseNotInSession => offline,
    ErrorCode.unauthorized ||
    ErrorCode.profileIncomplete ||
    ErrorCode.notFound ||
    ErrorCode.internalError => offline,
  };
}

/// Câu lỗi dưới ô theo `field` của `validation_failed` (S-01a).
String? fieldMessage(String? field) => switch (field) {
  'displayName' => S.invalidDisplayName,
  'phone' => S.invalidPhone,
  'password' => S.invalidPassword,
  _ => null,
};
