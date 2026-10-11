/// Mã lỗi server trả về (05 §6.8.3). App đổi mã thành câu tiếng Việt (AP-6).
enum ErrorCode {
  validationFailed('validation_failed', 422),
  phoneTaken('phone_taken', 409),
  invalidCredentials('invalid_credentials', 401),
  tooManyAttempts('too_many_attempts', 429),
  unauthorized('unauthorized', 401),
  profileIncomplete('profile_incomplete', 409),
  menuQuotaExhausted('menu_quota_exhausted', 429),
  budgetExhausted('budget_exhausted', 429),
  generationInProgress('generation_in_progress', 409),
  aiInvalidOutput('ai_invalid_output', 502),
  aiProviderError('ai_provider_error', 502),

  /// Bản 2 (05 Bản 2 §6.8.3): hết 3 lượt hình món ăn mới hôm nay (F12-E2).
  dishImageQuotaExhausted('dish_image_quota_exhausted', 429),

  /// Bản 2, chỉ trong kết quả push (05 Bản 2 §6.6.2, §6.6.3). App không hiện
  /// câu nào: hoàn bản ghi về trạng thái server và báo lỗi (TA-12), vì UI đã
  /// chặn trước các trường hợp này.
  sessionLocked('session_locked', 422),
  extraSessionLocked('extra_session_locked', 422),
  noSchedule('no_schedule', 422),
  liftNoSession('lift_no_session', 422),
  liftWindowClosed('lift_window_closed', 422),
  liftNotAllowedForExercise('lift_not_allowed_for_exercise', 422),
  liftExerciseNotInSession('lift_exercise_not_in_session', 422),

  /// Mã kỹ thuật: đường dẫn không tồn tại. App xử lý như lỗi kết nối.
  notFound('not_found', 404),

  /// Mã kỹ thuật: lỗi không lường trước ở server. App xử lý như lỗi kết nối.
  internalError('internal_error', 500);

  const ErrorCode(this.wire, this.httpStatus);

  /// Giá trị trong JSON (`snake_case`).
  final String wire;

  /// HTTP status đi kèm mã này.
  final int httpStatus;

  static final Map<String, ErrorCode> _byWire = {
    for (final c in ErrorCode.values) c.wire: c,
  };

  /// Mã chưa biết (server mới hơn app, TA-16) được coi là [internalError].
  static ErrorCode fromWire(String? wire) =>
      _byWire[wire] ?? ErrorCode.internalError;
}
