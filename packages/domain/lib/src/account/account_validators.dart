/// Ô nhập của tài khoản (S-01a).
enum AccountField { displayName, phone, password, passwordConfirm }

/// Quy tắc tài khoản (UA-19, UA-20, UA-21). App và server cùng dùng (AP-4).
abstract final class AccountValidators {
  static const displayNameMin = 1;
  static const displayNameMax = 30;
  static const passwordMin = 8;

  static final _phone = RegExp(r'^0\d{9}$');
  static final _spaces = RegExp(r'\s');

  /// Bỏ khoảng trắng mà ô nhập chèn vào để dễ đọc (`0912 345 678`).
  static String normalizePhone(String input) => input.replaceAll(_spaces, '');

  /// UA-20: số Việt Nam 10 chữ số, bắt đầu bằng 0. Nhận cả dạng có khoảng trắng.
  static bool isValidPhone(String input) =>
      _phone.hasMatch(normalizePhone(input));

  /// Tên hiển thị được lưu sau khi bỏ khoảng trắng đầu/cuối.
  static String normalizeDisplayName(String input) => input.trim();

  /// UA-21: 1–30 ký tự (đếm theo ký tự Unicode, sau khi bỏ khoảng trắng đầu/cuối).
  static bool isValidDisplayName(String input) {
    final length = normalizeDisplayName(input).runes.length;
    return length >= displayNameMin && length <= displayNameMax;
  }

  /// UA-19: ít nhất 8 ký tự.
  static bool isValidPassword(String password) =>
      password.runes.length >= passwordMin;

  /// Đăng ký: trả các ô sai theo thứ tự trên màn hình. Rỗng = hợp lệ.
  static List<AccountField> validateRegistration({
    required String displayName,
    required String phone,
    required String password,
    required String passwordConfirm,
  }) => [
    if (!isValidDisplayName(displayName)) AccountField.displayName,
    if (!isValidPhone(phone)) AccountField.phone,
    if (!isValidPassword(password)) AccountField.password,
    if (password != passwordConfirm) AccountField.passwordConfirm,
  ];
}
