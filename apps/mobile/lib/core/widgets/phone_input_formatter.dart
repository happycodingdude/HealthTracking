import 'package:flutter/services.dart';

/// Ô nhập số điện thoại: chỉ nhận chữ số, tối đa 10, các số liền nhau
/// `0912345678` (Bạn yêu cầu 01/11/2026: khi nhập không chèn dấu cách). Chỗ
/// chỉ hiển thị (S-50, S-56) vẫn dùng [format].
class PhoneInputFormatter extends TextInputFormatter {
  static final _digits = FilteringTextInputFormatter.digitsOnly;
  static final _cap = LengthLimitingTextInputFormatter(10);

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) => _cap.formatEditUpdate(
    oldValue,
    _digits.formatEditUpdate(oldValue, newValue),
  );

  /// Hiển thị: `0912345678` → `0912 345 678`.
  static String format(String digits) {
    final buf = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i == 4 || i == 7) buf.write(' ');
      buf.write(digits[i]);
    }
    return buf.toString();
  }
}
