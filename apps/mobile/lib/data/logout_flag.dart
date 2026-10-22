import 'package:shared_preferences/shared_preferences.dart';

/// Cờ `logout_pending` (05 Bản 3 §6.6.6, TD3-17): bật trước khi xóa dữ liệu
/// trên máy, tắt khi xóa xong. Mở app mà cờ còn bật → xóa nốt rồi mới vào màn
/// Đăng nhập (F27-E2). Nằm trong UserDefaults, không trong Keychain vì Keychain
/// cũng bị xóa khi đăng xuất.
abstract interface class LogoutFlag {
  Future<bool> isPending();
  Future<void> set();
  Future<void> clear();
}

final class PrefsLogoutFlag implements LogoutFlag {
  PrefsLogoutFlag([SharedPreferencesAsync? prefs])
    : _prefs = prefs ?? SharedPreferencesAsync();

  final SharedPreferencesAsync _prefs;

  static const _key = 'logout_pending';

  @override
  Future<bool> isPending() async => await _prefs.getBool(_key) ?? false;

  @override
  Future<void> set() => _prefs.setBool(_key, true);

  @override
  Future<void> clear() => _prefs.remove(_key);
}

/// Bản trong bộ nhớ (test).
final class MemoryLogoutFlag implements LogoutFlag {
  MemoryLogoutFlag([this.pending = false]);

  bool pending;

  @override
  Future<bool> isPending() async => pending;

  @override
  Future<void> set() async => pending = true;

  @override
  Future<void> clear() async => pending = false;
}
