import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Mốc lưu trên máy, không đồng bộ (ED-07).
abstract interface class LocalMarks {
  /// Năm đã dùng để tính tuổi lần gần nhất (`lastAgeEvaluatedYear`).
  Future<int?> lastAgeYear();

  Future<void> setLastAgeYear(int year);
}

/// Lưu trong Keychain cạnh phiên đăng nhập: không cần thêm cột vào schema đã
/// chốt (ED-07).
final class SecureLocalMarks implements LocalMarks {
  SecureLocalMarks([FlutterSecureStorage? storage])
    : _s =
          storage ??
          const FlutterSecureStorage(
            iOptions: IOSOptions(
              accessibility: KeychainAccessibility.first_unlock_this_device,
            ),
          );

  final FlutterSecureStorage _s;

  static const _ageYear = 'marks.lastAgeEvaluatedYear';

  @override
  Future<int?> lastAgeYear() async =>
      int.tryParse(await _s.read(key: _ageYear) ?? '');

  @override
  Future<void> setLastAgeYear(int year) =>
      _s.write(key: _ageYear, value: '$year');
}

/// Bản trong bộ nhớ (test).
final class MemoryLocalMarks implements LocalMarks {
  MemoryLocalMarks([this._year]);

  int? _year;

  @override
  Future<int?> lastAgeYear() async => _year;

  @override
  Future<void> setLastAgeYear(int year) async => _year = year;
}
