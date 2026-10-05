// Toàn bộ câu chữ tiếng Việt của app (UR-12, ED-12).
//
// Câu lấy nguyên văn từ 03/04. Mỗi câu hằng có trong [S.catalog] để test so
// khớp với test/spec_strings.yaml. Câu có tham số là hàm.

abstract final class S {
  // Thanh tab (04 §6.3.1, UR-01).
  static const tabSchedule = 'Lịch tập';
  static const tabMenu = 'Thực đơn';
  static const tabToday = 'Hôm nay';
  static const tabWeight = 'Cân nặng';
  static const tabMe = 'Tôi';

  // Chung.
  static const back = 'Quay lại';
  static const understood = 'Đã hiểu';

  // S-01 Chào mừng.
  /// Tên app chưa được chốt (Q-1 trong docs/progress.md); mock S-01 ghi "[Tên app]".
  static const appName = 'Health Tracking';
  static const welcomeTagline =
      'Nhắc Bạn tập đúng lịch, gợi ý ăn gì mỗi ngày, cho Bạn thấy mình tiến bộ.';
  static const welcomeFootnote =
      'Tài khoản giúp giữ dữ liệu khi Bạn đổi điện thoại.';
  static const register = 'Đăng ký';
  static const login = 'Đăng nhập';

  // S-01a Đăng ký.
  static const registerSubtitle =
      'Tài khoản giúp Bạn lấy lại dữ liệu trên điện thoại mới.';
  static const fieldDisplayName = 'Tên hiển thị';
  static const fieldPhone = 'Số điện thoại';
  static const fieldPassword = 'Mật khẩu';
  static const fieldPasswordConfirm = 'Nhập lại mật khẩu';
  static const passwordHint = 'Ít nhất 8 ký tự';
  static const invalidPasswordConfirm = 'Mật khẩu nhập lại chưa khớp';
  static const haveAccount = 'Đã có tài khoản?';
  static const showPassword = 'Hiện mật khẩu';
  static const hidePassword = 'Ẩn mật khẩu';

  // S-01b Đăng nhập, S-01c Quên mật khẩu.
  static const noAccount = 'Chưa có tài khoản?';
  static const forgotPassword = 'Quên mật khẩu?';
  static const forgotPasswordBody =
      'Hiện app chưa hỗ trợ tự lấy lại mật khẩu. Liên hệ người quản trị app để được đặt lại mật khẩu.';
  static const forgotPasswordNote =
      'Dữ liệu của Bạn vẫn được giữ nguyên trong lúc chờ.';

  // S-02 (giữ chỗ đến VS-03).
  static const disclaimerTitle = 'Trước khi bắt đầu';

  // Định dạng (UR-10).
  static const currencySuffix = 'đ';
  static const weekdays = [
    'Thứ 2',
    'Thứ 3',
    'Thứ 4',
    'Thứ 5',
    'Thứ 6',
    'Thứ 7',
    'Chủ nhật',
  ];

  // Lỗi từ server (05 §6.8.3) và câu không có mạng của từng màn hình.
  static const errorPhoneTaken = 'Số điện thoại này đã có tài khoản.';
  static const errorInvalidCredentials =
      'Số điện thoại hoặc mật khẩu chưa đúng.';
  static const offlineRegister = 'Cần kết nối internet để đăng ký.';
  static const offlineLogin = 'Cần kết nối internet để đăng nhập.';
  static const offlineMenu = 'Cần kết nối internet để gợi ý thực đơn.';
  static const menuQuotaExhausted = 'Bạn đã dùng hết 3 lượt hôm nay.';
  static const menuInvalidOutput =
      'Thực đơn vừa tạo chưa đạt yêu cầu. Thử lại.';
  static const menuProviderError = 'Chưa tạo được thực đơn. Thử lại.';
  static const menuGenerating = 'Đang lên thực đơn…';

  /// F08-E2: "Gợi ý AI tạm dừng đến ngày 1/{tháng sau} vì …".
  static String budgetPaused(int nextMonth) =>
      'Gợi ý AI tạm dừng đến ngày 1/$nextMonth vì đã dùng hết ngân sách tháng này.';

  // Kiểm tra ô nhập ở S-01a (UA-19, UA-20, UA-21).
  static const invalidDisplayName = 'Tên cần từ 1 đến 30 ký tự';
  static const invalidPhone = 'Số điện thoại chưa đúng';
  static const invalidPassword = 'Mật khẩu cần ít nhất 8 ký tự';

  /// Mọi câu hằng, dùng cho test so khớp nguyên văn (ED-12).
  static const Map<String, String> catalog = {
    'back': back,
    'understood': understood,
    'appName': appName,
    'welcomeTagline': welcomeTagline,
    'welcomeFootnote': welcomeFootnote,
    'register': register,
    'login': login,
    'registerSubtitle': registerSubtitle,
    'fieldDisplayName': fieldDisplayName,
    'fieldPhone': fieldPhone,
    'fieldPassword': fieldPassword,
    'fieldPasswordConfirm': fieldPasswordConfirm,
    'passwordHint': passwordHint,
    'invalidPasswordConfirm': invalidPasswordConfirm,
    'haveAccount': haveAccount,
    'showPassword': showPassword,
    'hidePassword': hidePassword,
    'noAccount': noAccount,
    'forgotPassword': forgotPassword,
    'forgotPasswordBody': forgotPasswordBody,
    'forgotPasswordNote': forgotPasswordNote,
    'disclaimerTitle': disclaimerTitle,
    'tabSchedule': tabSchedule,
    'tabMenu': tabMenu,
    'tabToday': tabToday,
    'tabWeight': tabWeight,
    'tabMe': tabMe,
    'errorPhoneTaken': errorPhoneTaken,
    'errorInvalidCredentials': errorInvalidCredentials,
    'offlineRegister': offlineRegister,
    'offlineLogin': offlineLogin,
    'offlineMenu': offlineMenu,
    'menuQuotaExhausted': menuQuotaExhausted,
    'menuInvalidOutput': menuInvalidOutput,
    'menuProviderError': menuProviderError,
    'menuGenerating': menuGenerating,
    'invalidDisplayName': invalidDisplayName,
    'invalidPhone': invalidPhone,
    'invalidPassword': invalidPassword,
  };
}
