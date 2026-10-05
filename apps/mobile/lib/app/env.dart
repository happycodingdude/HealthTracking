/// Cấu hình theo flavor, truyền bằng `--dart-define` (ED-15).
///
/// - `FLAVOR`: `dev` (bản dev chạy từ Mac, dữ liệu thử) hoặc `prod`.
/// - `API_BASE_URL`: địa chỉ server. Dev trên simulator: `http://localhost:8080`;
///   dev trên iPhone: `http://<LocalHostName>.local:8080` (VS00-T12).
/// - `SENTRY_DSN`: để trống thì tắt báo lỗi.
final class AppEnv {
  const AppEnv({
    required this.flavor,
    required this.apiBaseUrl,
    this.sentryDsn = '',
  });

  factory AppEnv.fromEnvironment() => const AppEnv(
    flavor: String.fromEnvironment('FLAVOR', defaultValue: 'dev'),
    apiBaseUrl: String.fromEnvironment(
      'API_BASE_URL',
      defaultValue: 'http://localhost:8080',
    ),
    sentryDsn: String.fromEnvironment('SENTRY_DSN'),
  );

  final String flavor;
  final String apiBaseUrl;
  final String sentryDsn;

  bool get isDev => flavor == 'dev';
}
