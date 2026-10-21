/// Phiên bản app (semver `MAJOR.MINOR.PATCH`) gửi trong header
/// `X-App-Version` từ Bản 2 (05 Bản 2 TD2-15, TR2-13). Không có header = app
/// Bản 1.
final class AppVersion implements Comparable<AppVersion> {
  const AppVersion(this.major, this.minor, this.patch);

  /// Đọc `2.0.0` (bỏ phần build `+N` nếu có). Ném [FormatException] nếu sai.
  factory AppVersion.parse(String value) {
    final match = _pattern.firstMatch(value.trim());
    if (match == null) {
      throw FormatException('Phiên bản app không đúng định dạng semver', value);
    }
    return AppVersion(
      int.parse(match.group(1)!),
      int.parse(match.group(2)!),
      int.parse(match.group(3)!),
    );
  }

  static AppVersion? tryParse(String? value) {
    if (value == null) return null;
    try {
      return AppVersion.parse(value);
    } on FormatException {
      return null;
    }
  }

  /// Tên header (05 Bản 2 §6.8.1).
  static const header = 'X-App-Version';

  /// Bản 2 đầu tiên. Từ phiên bản này app biết "Để sau" lịch tuần (TD2-04).
  static const v2 = AppVersion(2, 0, 0);

  /// Bản 3 đầu tiên (05 Bản 3 §6.12). App thấp hơn nhận entity `exercise`
  /// dạng Bản 2 (TD3-21).
  static const v3 = AppVersion(3, 0, 0);

  static final _pattern = RegExp(r'^(\d{1,4})\.(\d{1,4})\.(\d{1,4})(\+\d+)?$');

  final int major;
  final int minor;
  final int patch;

  bool operator >=(AppVersion other) => compareTo(other) >= 0;
  bool operator <(AppVersion other) => compareTo(other) < 0;

  @override
  int compareTo(AppVersion other) {
    if (major != other.major) return major.compareTo(other.major);
    if (minor != other.minor) return minor.compareTo(other.minor);
    return patch.compareTo(other.patch);
  }

  @override
  bool operator ==(Object other) =>
      other is AppVersion &&
      other.major == major &&
      other.minor == minor &&
      other.patch == patch;

  @override
  int get hashCode => Object.hash(major, minor, patch);

  /// Giá trị header.
  @override
  String toString() => '$major.$minor.$patch';
}
